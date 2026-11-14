package com.expensetracker.app.update

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import java.io.File

/** Gives an APK to the Android package installer. Port of the 0.1.1 `UpdateRepository` install code. */
object UpdateInstaller {
    /**
     * The handler of the channel that called [install] last. [UpdateInstallReceiver] calls it
     * with the installer status. It can run on the main thread only.
     */
    @Volatile var onStatus: ((Int, String?) -> Unit)? = null

    /** True only when [file] is the APK of this app with exactly [versionCode]. */
    fun isExpectedApk(context: Context, file: File, versionCode: Int): Boolean {
        val info = context.packageManager.getPackageArchiveInfo(file.path, 0)
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info?.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info?.versionCode?.toLong()
        }
        return ApkCheck.matches(info?.packageName, code, context.packageName, versionCode)
    }

    /** Writes [file] into a new session and commits it. Abandons the session on any error, then throws it again. */
    fun install(context: Context, file: File) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        }
        val sessionId = installer.createSession(params)
        try {
            installer.openSession(sessionId).use { session ->
                session.openWrite("koban.apk", 0, file.length()).use { out ->
                    file.inputStream().use { it.copyTo(out) }
                    session.fsync(out)
                }
                // The installer adds the status extras, so the intent must be mutable on API 31 and newer.
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
                val pending = PendingIntent.getBroadcast(
                    context,
                    sessionId,
                    Intent(context, UpdateInstallReceiver::class.java),
                    flags,
                )
                session.commit(pending.intentSender)
            }
        } catch (e: Exception) {
            // Abandon by ID: this also covers a failed openSession.
            installer.abandonSession(sessionId)
            throw e
        }
    }
}
