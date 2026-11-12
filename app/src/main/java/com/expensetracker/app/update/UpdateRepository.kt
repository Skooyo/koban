package com.expensetracker.app.update

import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import com.expensetracker.app.BuildConfig
import com.expensetracker.app.data.SettingsRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit.SECONDS
import javax.inject.Inject
import javax.inject.Singleton

const val RELEASES_URL = "https://api.github.com/repos/Skooyo/koban/releases/latest"

sealed interface UpdateState {
    data object Idle : UpdateState
    data object UpToDate : UpdateState
    data class Available(val update: AvailableUpdate) : UpdateState
    data object Downloading : UpdateState
    data object Installing : UpdateState
    /** With [retry] set, "OK" goes back to [Available] for that update. */
    data class Failed(val message: String, val retry: AvailableUpdate? = null) : UpdateState
}

@Singleton
class UpdateRepository @Inject constructor(
    @ApplicationContext private val context: Context,
    private val client: OkHttpClient,
    private val settings: SettingsRepository
) {
    private val _state = MutableStateFlow<UpdateState>(UpdateState.Idle)
    val state: StateFlow<UpdateState> = _state.asStateFlow()

    /** The shared client stops a call after 20 s; the APK is about 65 MB. */
    private val downloadClient by lazy {
        client.newBuilder().callTimeout(0, SECONDS).readTimeout(60, SECONDS).build()
    }

    /** The update of the last download, so "Close" on Installing can go back to Available. */
    @Volatile private var inProgress: AvailableUpdate? = null

    private val busy get() = _state.value.let { it is UpdateState.Downloading || it is UpdateState.Installing }

    suspend fun check(manual: Boolean) {
        val now = System.currentTimeMillis()
        if (busy) return
        if (!UpdateSchedule.shouldCheck(settings.onlineFeatures.first(), settings.lastUpdateCheck.first(), now, manual)) return
        // Only these two headers: no app version, no account ID.
        val request = Request.Builder()
            .url(RELEASES_URL)
            .header("Accept", "application/vnd.github+json")
            .header("User-Agent", "Koban-Android")
            .build()
        val next = try {
            withContext(Dispatchers.IO) {
                client.newCall(request).execute().use { response ->
                    // Any answer counts, so a 403 or 404 waits a day.
                    settings.setLastUpdateCheck(now)
                    if (response.code != 200) return@use failedCheck(manual)
                    val update = ReleaseParser.parseLatest(response.body?.string().orEmpty(), BuildConfig.VERSION_CODE)
                    when {
                        update != null -> UpdateState.Available(update)
                        manual -> UpdateState.UpToDate
                        else -> UpdateState.Idle
                    }
                }
            }
        } catch (e: IOException) {
            failedCheck(manual)
        }
        if (!busy) _state.value = next
    }

    private fun failedCheck(manual: Boolean): UpdateState =
        if (manual) UpdateState.Failed("Could not check for updates. Try again later.") else UpdateState.Idle

    suspend fun downloadAndInstall() {
        // Only from Available: a second tap while Downloading or Installing does nothing.
        val available = _state.value as? UpdateState.Available ?: return
        val update = available.update
        if (!context.packageManager.canRequestPackageInstalls()) {
            try {
                context.startActivity(
                    Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + BuildConfig.APPLICATION_ID))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            } catch (e: ActivityNotFoundException) {
                Log.w(TAG, "No screen for install permission", e)
            }
            _state.value = UpdateState.Failed("Allow Koban to install apps, then tap Update again.", retry = update)
            return
        }
        // Atomic, so two quick taps start one download only.
        if (!_state.compareAndSet(available, UpdateState.Downloading)) return
        inProgress = update
        if (!settings.onlineFeatures.first()) {
            _state.value = UpdateState.Idle
            return
        }
        val dir = File(context.cacheDir, "updates")
        val file = File(dir, "koban-${update.versionCode}.apk")
        try {
            withContext(Dispatchers.IO) {
                try {
                    dir.deleteRecursively()
                    dir.mkdirs()
                    download(update.apkUrl, file)
                    if (!isExpectedApk(file, update.versionCode)) throw IOException("Not the expected Koban APK")
                    _state.value = UpdateState.Installing
                    install(file)
                } finally {
                    // The session holds its own copy, so the file is not needed after the commit either.
                    file.delete()
                }
            }
        } catch (e: IOException) {
            Log.w(TAG, "Update failed", e)
            _state.value = UpdateState.Failed("Update failed. Try again later.")
        } finally {
            // A cancelled caller must not leave the state stuck on Downloading.
            if (_state.value == UpdateState.Downloading) _state.value = UpdateState.Idle
        }
    }

    private fun download(url: String, file: File) {
        val request = Request.Builder().url(url).header("User-Agent", "Koban-Android").build()
        downloadClient.newCall(request).execute().use { response ->
            if (!response.isSuccessful) throw IOException("HTTP ${response.code}")
            val body = response.body ?: throw IOException("No body")
            // OkHttp throws when the stream stops before Content-Length.
            file.outputStream().use { out -> body.byteStream().copyTo(out) }
        }
    }

    private fun isExpectedApk(file: File, versionCode: Int): Boolean {
        val info = context.packageManager.getPackageArchiveInfo(file.path, 0)
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info?.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info?.versionCode?.toLong()
        }
        return ApkCheck.matches(info?.packageName, code, BuildConfig.APPLICATION_ID, versionCode)
    }

    private fun install(file: File) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        }
        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            try {
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
                    flags
                )
                session.commit(pending.intentSender)
            } catch (e: IOException) {
                session.abandon()
                throw e
            }
        }
    }

    /**
     * Closes the dialog. Available: Idle. Installing: back to Available, because the confirm
     * screen can fail to open or be left with Home, and then no status arrives.
     * Failed with a retry: back to Available. Other Failed: Idle.
     */
    fun later() {
        _state.value = when (val s = _state.value) {
            UpdateState.Installing -> inProgress?.let { UpdateState.Available(it) } ?: UpdateState.Idle
            is UpdateState.Failed -> s.retry?.let { UpdateState.Available(it) } ?: UpdateState.Idle
            else -> UpdateState.Idle
        }
    }

    /** Called by [UpdateInstallReceiver] with the installer's status. */
    fun onInstallStatus(status: Int, message: String?) {
        when (status) {
            // The confirm screen is open; the next status comes after the user answers.
            PackageInstaller.STATUS_PENDING_USER_ACTION -> Unit
            // Android stops and restarts the app; nothing more to do.
            PackageInstaller.STATUS_SUCCESS -> _state.value = UpdateState.Idle
            else -> {
                Log.w(TAG, "Install failed: status $status, $message")
                _state.value = UpdateState.Failed("Update failed. Try again later.")
            }
        }
    }

    private companion object {
        const val TAG = "UpdateRepository"
    }
}
