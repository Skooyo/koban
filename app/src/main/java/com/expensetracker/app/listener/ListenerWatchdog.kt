package com.expensetracker.app.listener

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock

/**
 * Periodically restarts the keep-alive service and requests a listener rebind.
 * Helps on OEMs that kill foreground services after extended idle time.
 */
object ListenerWatchdog {
    private const val REQUEST_CODE = 2001
    private const val INTERVAL_MS = 15 * 60 * 1000L
    private const val XIAOMI_INTERVAL_MS = 30 * 60 * 1000L
    private const val SOON_DELAY_MS = 5_000L

    fun schedule(context: Context) {
        val interval = if (OemBatteryHelper.isXiaomiFamily()) XIAOMI_INTERVAL_MS else INTERVAL_MS
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        val pendingIntent = pendingIntent(context)
        val triggerAt = System.currentTimeMillis() + interval
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pendingIntent
                )
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
            NotificationAccessHelper.logDebug("Listener watchdog scheduled")
        } catch (e: Exception) {
            NotificationAccessHelper.logDebug("Failed to schedule watchdog: ${e.message}")
        }
    }

    fun scheduleSoon(context: Context, delayMs: Long = SOON_DELAY_MS) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        val pendingIntent = pendingIntent(context)
        val triggerAt = SystemClock.elapsedRealtime() + delayMs
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    pendingIntent
                )
            } else {
                alarmManager.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
            }
        } catch (e: Exception) {
            NotificationAccessHelper.logDebug("Failed to schedule soon watchdog: ${e.message}")
        }
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        alarmManager.cancel(pendingIntent(context))
    }

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, ListenerWatchdogReceiver::class.java)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}

class ListenerWatchdogReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (!NotificationAccessHelper.isNotificationAccessGranted(context)) {
            ListenerWatchdog.cancel(context)
            return
        }
        NotificationAccessHelper.softReconnectListener(context.applicationContext, bypassThrottle = true)
        ListenerWatchdog.schedule(context.applicationContext)
    }
}
