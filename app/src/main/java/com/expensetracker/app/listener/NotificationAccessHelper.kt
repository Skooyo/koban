package com.expensetracker.app.listener

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.service.notification.NotificationListenerService
import androidx.core.app.NotificationManagerCompat
import com.expensetracker.app.BuildConfig
import java.util.concurrent.atomic.AtomicLong

enum class ReconnectResult {
    ACCESS_NOT_GRANTED,
    ATTEMPTED,
    THROTTLED,
    FAILED
}

object NotificationAccessHelper {
    private val lastReconnectMs = AtomicLong(0L)
    private const val AUTO_RECONNECT_MIN_INTERVAL_MS = 30_000L

    fun isNotificationAccessGranted(context: Context): Boolean {
        val enabledPackages = NotificationManagerCompat.getEnabledListenerPackages(context)
        return enabledPackages.contains(context.packageName)
    }

    fun isListenerConnected(): Boolean = NotificationListenerBridge.isServiceConnected()

    fun isBatteryOptimizationIgnored(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val powerManager = context.getSystemService(PowerManager::class.java) ?: return true
        return powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun ensureListenerActive(context: Context) {
        val appContext = context.applicationContext
        if (!isNotificationAccessGranted(appContext)) {
            ListenerKeepAliveService.stop(appContext)
            ListenerWatchdog.cancel(appContext)
            ListenerReconnectScheduler.cancel()
            return
        }
        ListenerKeepAliveService.start(appContext)
        ListenerWatchdog.schedule(appContext)
        ListenerReconnectScheduler.scheduleBurst(appContext, allowComponentReset = false)
    }

    /**
     * User tapped Reconnect. Runs a 60s burst of rebind attempts; on Xiaomi also tries a safe
     * component reset (DEFAULT→ENABLED, never DISABLE) as a last resort.
     */
    fun reconnectListener(context: Context): ReconnectResult {
        val appContext = context.applicationContext
        if (!isNotificationAccessGranted(appContext)) {
            return ReconnectResult.ACCESS_NOT_GRANTED
        }
        return try {
            lastReconnectMs.set(System.currentTimeMillis())
            ListenerKeepAliveService.start(appContext)
            ListenerWatchdog.schedule(appContext)
            ListenerReconnectScheduler.scheduleBurst(
                appContext,
                allowComponentReset = OemBatteryHelper.isXiaomiFamily()
            )
            ReconnectResult.ATTEMPTED
        } catch (e: Exception) {
            logDebug("Reconnect failed: ${e.message}")
            ReconnectResult.FAILED
        }
    }

    fun softReconnectListener(
        context: Context,
        bypassThrottle: Boolean = false
    ): ReconnectResult {
        val appContext = context.applicationContext
        if (!isNotificationAccessGranted(appContext)) {
            ListenerKeepAliveService.stop(appContext)
            ListenerWatchdog.cancel(appContext)
            return ReconnectResult.ACCESS_NOT_GRANTED
        }
        if (!bypassThrottle && !shouldRun(AUTO_RECONNECT_MIN_INTERVAL_MS)) {
            return ReconnectResult.THROTTLED
        }
        ListenerKeepAliveService.start(appContext)
        ListenerWatchdog.schedule(appContext)
        ListenerReconnectScheduler.scheduleBurst(appContext, allowComponentReset = false)
        return ReconnectResult.ATTEMPTED
    }

    /**
     * Safer than DISABLE→ENABLE: resets to manifest default then re-enables.
     * Used only as the last step of a user-initiated reconnect burst on Xiaomi.
     */
    fun resetComponentBinding(context: Context) {
        val component = getComponentName(context.applicationContext)
        val pm = context.applicationContext.packageManager
        pm.setComponentEnabledSetting(
            component,
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
            PackageManager.DONT_KILL_APP
        )
        pm.setComponentEnabledSetting(
            component,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
        logDebug("Reset listener component binding (default → enabled)")
    }

    fun reconnectStatusMessage(context: Context): String {
        return when {
            !isNotificationAccessGranted(context) ->
                "Notification access is off — re-enable it in system settings."
            isListenerConnected() ->
                "Listener is connected."
            else ->
                "Access granted but listener disconnected — tap Reconnect listener."
        }
    }

    fun requestRebind(context: Context) {
        if (!isNotificationAccessGranted(context)) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        try {
            NotificationListenerService.requestRebind(getComponentName(context))
            logDebug("Requested notification listener rebind")
        } catch (e: Exception) {
            logDebug("Rebind request failed: ${e.message}")
        }
    }

    fun openNotificationAccessSettings(context: Context) {
        context.startActivity(
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        )
    }

    fun openBatteryOptimizationSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                context.startActivity(intent)
                return
            } catch (_: Exception) {
                // Fall through.
            }
        }
        context.startActivity(
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        )
    }

    fun getComponentName(context: Context): ComponentName {
        return ComponentName(context, ExpenseNotificationListener::class.java)
    }

    fun logDebug(message: String) {
        if (BuildConfig.DEBUG) {
            android.util.Log.d(TAG, message)
        }
    }

    private fun shouldRun(minIntervalMs: Long): Boolean {
        val now = System.currentTimeMillis()
        val previous = lastReconnectMs.get()
        if (now - previous < minIntervalMs) return false
        return lastReconnectMs.compareAndSet(previous, now)
    }

    private const val TAG = "ExpenseNotification"
}
