package io.github.skooyo.koban

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.text.format.DateUtils
import androidx.core.graphics.drawable.toBitmap
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.io.OutputStream

/**
 * The device channel: launcher apps, permissions, gallery, share, the online build values and relative times.
 * [work] runs a block on the plugin executor and replies on the main thread.
 * [activity] gives the attached activity, or null.
 */
internal class DeviceChannel(
    private val app: Context,
    private val work: (MethodChannel.Result, String, () -> Any?) -> Unit,
    private val activity: () -> Activity?,
) {
    private var pendingAlerts: MethodChannel.Result? = null
    private var pendingStorage: MethodChannel.Result? = null

    fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installedApps" -> work(result, "NATIVE_ERROR") { loadApps() }
            "appLabels" -> work(result, "NATIVE_ERROR") { labels(call.argument<List<String>>("packages")!!) }
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            "onlineConfig" -> result.success(
                mapOf(
                    "supabaseUrl" to BuildConfig.SUPABASE_URL,
                    "supabaseKey" to BuildConfig.SUPABASE_KEY,
                    "googleWebClientId" to BuildConfig.GOOGLE_WEB_CLIENT_ID,
                ),
            )
            // The 0.1.1 text, for example "3 hours ago". Small numbers come over the channel as Int.
            "relativeTime" -> result.success(
                DateUtils.getRelativeTimeSpanString(
                    call.argument<Number>("time")!!.toLong(),
                    call.argument<Number>("now")!!.toLong(),
                    DateUtils.MINUTE_IN_MILLIS,
                ).toString(),
            )
            "versionName" -> work(result, "NATIVE_ERROR") { app.packageManager.getPackageInfo(app.packageName, 0).versionName }
            "notificationsAllowed" -> result.success(notificationsAllowed())
            "shouldShowNotificationRationale" -> result.success(
                Build.VERSION.SDK_INT >= 33 &&
                    activity()?.shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS) == true,
            )
            "requestNotificationPermission" -> {
                val host = activity()
                if (notificationsAllowed() || host == null || pendingAlerts != null) {
                    result.success(notificationsAllowed())
                } else {
                    pendingAlerts = result
                    host.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), ALERTS_CODE)
                }
            }
            "openAppNotificationSettings" -> {
                open(
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, app.packageName),
                )
                result.success(null)
            }
            "openAppInfo" -> {
                open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", app.packageName, null)))
                result.success(null)
            }
            "storageAllowed" -> result.success(storageAllowed())
            "requestStoragePermission" -> {
                val host = activity()
                if (storageAllowed() || host == null || pendingStorage != null) {
                    result.success(storageAllowed())
                } else {
                    pendingStorage = result
                    host.requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), STORAGE_CODE)
                }
            }
            "saveImageToGallery" -> work(result, "GALLERY") {
                saveToGallery(call.argument<String>("path")!!, call.argument<String>("displayName")!!).toString()
            }
            // On the main thread: an activity start does no disk work.
            "shareText" -> try {
                val send = Intent(Intent.ACTION_SEND).setType("text/plain")
                    .putExtra(Intent.EXTRA_TEXT, call.argument<String>("text")!!)
                app.startActivity(Intent.createChooser(send, call.argument<String>("chooserTitle")!!).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                result.success(null)
            } catch (e: RuntimeException) {
                result.error("NATIVE_ERROR", e.message, null)
            }
            else -> result.notImplemented()
        }
    }

    /** Takes the answer of a permission dialog. Returns true when the request code is ours. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        val result = when (requestCode) {
            ALERTS_CODE -> pendingAlerts.also { pendingAlerts = null }
            STORAGE_CODE -> pendingStorage.also { pendingStorage = null }
            else -> return false
        }
        result?.success(granted)
        return true
    }

    /** Answers each open permission call once with the current state. The activity or the engine is gone. */
    fun cancelPending() {
        val alerts = pendingAlerts
        val storage = pendingStorage
        pendingAlerts = null
        pendingStorage = null
        alerts?.success(runCatching { notificationsAllowed() }.getOrDefault(false))
        storage?.success(runCatching { storageAllowed() }.getOrDefault(false))
    }

    private fun notificationsAllowed() = Build.VERSION.SDK_INT < 33 ||
        app.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun storageAllowed() = Build.VERSION.SDK_INT >= 29 ||
        app.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED

    private fun open(intent: Intent) {
        try {
            app.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: ActivityNotFoundException) {
            // No such settings page on this phone.
        }
    }

    private fun labels(packages: List<String>): Map<String, String> {
        val pm = app.packageManager
        return packages.associateWith { pkg ->
            runCatching { pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString() }.getOrDefault(pkg)
        }
    }

    /** Port of 0.1.1 `PaymentAppsViewModel.loadApps` without the sort. */
    private fun loadApps(): List<Map<String, Any?>> {
        val pm = app.packageManager
        val iconPx = (40 * app.resources.displayMetrics.density).toInt()
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .map { it.activityInfo.packageName }
            .filter { it != app.packageName }
            .distinct()
            .mapNotNull { pkg ->
                runCatching {
                    val info = pm.getApplicationInfo(pkg, 0)
                    val icon = runCatching {
                        val bitmap = pm.getApplicationIcon(info).toBitmap(iconPx, iconPx)
                        ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
                    }.getOrNull()
                    mapOf("packageName" to pkg, "label" to pm.getApplicationLabel(info).toString(), "icon" to icon)
                }.getOrNull()
            }
    }

    /** Port of 0.1.1 `QrStore.saveToGallery`: writes the picture to Pictures/Koban as a JPEG. */
    private fun saveToGallery(path: String, displayName: String): Uri {
        val bitmap = BitmapFactory.decodeFile(path) ?: throw IllegalArgumentException("That file isn't an image.")
        try {
            val resolver = app.contentResolver
            val collection = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/Koban")
                values.put(MediaStore.MediaColumns.IS_PENDING, 1)
                val uri = resolver.insert(collection, values) ?: throw IOException("Couldn't save to gallery.")
                try {
                    resolver.openOutputStream(uri)?.use { writeJpeg(bitmap, it) }
                        ?: throw IOException("Couldn't save to gallery.")
                    resolver.update(uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
                } catch (e: Exception) {
                    resolver.delete(uri, null, null)
                    throw e
                }
                return uri
            }

            @Suppress("DEPRECATION")
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "Koban")
            dir.mkdirs()
            val file = File(dir, displayName)
            @Suppress("DEPRECATION")
            val dataColumn = MediaStore.MediaColumns.DATA
            // Before Q, deleting a row also deletes its file: drop the old row before the new write.
            resolver.delete(collection, "$dataColumn = ?", arrayOf(file.absolutePath))
            file.outputStream().use { writeJpeg(bitmap, it) }
            values.put(dataColumn, file.absolutePath)
            return resolver.insert(collection, values) ?: throw IOException("Couldn't save to gallery.")
        } finally {
            bitmap.recycle()
        }
    }

    private fun writeJpeg(bitmap: Bitmap, out: OutputStream) {
        // JPEG has no alpha: put a transparent QR on white, or its background turns black.
        val opaque = if (bitmap.hasAlpha()) {
            Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888).also {
                Canvas(it).apply { drawColor(Color.WHITE); drawBitmap(bitmap, 0f, 0f, null) }
            }
        } else {
            bitmap
        }
        try {
            if (!opaque.compress(Bitmap.CompressFormat.JPEG, 95, out)) throw IOException("Couldn't save to gallery.")
        } finally {
            if (opaque !== bitmap) opaque.recycle()
        }
    }

    companion object {
        const val ALERTS_CODE = 4201
        const val STORAGE_CODE = 4202
    }
}
