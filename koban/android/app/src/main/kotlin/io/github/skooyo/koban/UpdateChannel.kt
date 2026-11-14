package io.github.skooyo.koban

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import com.expensetracker.app.update.UpdateInstaller
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** An error with its own reply code. [KobanNativePlugin] uses [code] instead of the default one. */
internal class CodedError(val code: String, message: String?) : Exception(message)

/**
 * The update channel: the install permission, the install settings page and the package installer.
 * [work] runs a block on the plugin executor and replies on the main thread.
 * [sender] sends the installer status to Dart.
 */
internal class UpdateChannel(
    private val app: Context,
    private val work: (MethodChannel.Result, String, () -> Any?) -> Unit,
    private val sender: MethodChannel,
) {
    private val main = Handler(Looper.getMainLooper())
    private val statusSender: (Int, String?) -> Unit = ::sendStatus

    /** Stops the status of an install from reaching this channel. The engine detached. */
    fun release() {
        if (UpdateInstaller.onStatus === statusSender) UpdateInstaller.onStatus = null
    }

    @Suppress("DEPRECATION")
    private fun versionCode(): Long {
        val info = app.packageManager.getPackageInfo(app.packageName, 0)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode else info.versionCode.toLong()
    }

    fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "versionCode" -> work(result, "NATIVE_ERROR") { versionCode() }
            "canInstall" -> result.success(app.packageManager.canRequestPackageInstalls())
            "openInstallSettings" -> {
                try {
                    app.startActivity(
                        Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + app.packageName))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                } catch (_: ActivityNotFoundException) {
                    // No such settings page on this phone.
                }
                result.success(null)
            }
            "install" -> {
                val file = File(call.argument<String>("path")!!)
                val versionCode = call.argument<Number>("versionCode")!!.toInt()
                // This channel gets the status of this install. The other engine has its own plugin instance.
                UpdateInstaller.onStatus = statusSender
                work(result, "INSTALL") { install(file, versionCode) }
            }
            else -> result.notImplemented()
        }
    }

    private fun install(file: File, versionCode: Int) {
        // Check first: a file of another app never goes into a session.
        if (!UpdateInstaller.isExpectedApk(app, file, versionCode)) throw CodedError("NOT_KOBAN_APK", "Not the Koban APK")
        try {
            UpdateInstaller.install(app, file)
        } catch (e: Exception) {
            // The error type only: the message can hold a path.
            throw CodedError("INSTALL", e.javaClass.simpleName)
        }
    }

    /** Called by the receiver on the main thread. The post keeps [MethodChannel.invokeMethod] on that thread also for other callers. */
    private fun sendStatus(status: Int, message: String?) {
        val name = when (status) {
            PackageInstaller.STATUS_SUCCESS -> "success"
            PackageInstaller.STATUS_PENDING_USER_ACTION -> "pendingUserAction"
            else -> "failure"
        }
        main.post { sender.invokeMethod("installStatus", mapOf("status" to name, "message" to message)) }
    }
}
