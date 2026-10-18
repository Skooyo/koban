package com.expensetracker.app.listener

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.expensetracker.app.MainActivity
import com.expensetracker.app.R

/**
 * Keeps the app process alive so the system does not drop the notification listener
 * when the user swipes the app away from recents.
 */
class ListenerKeepAliveService : Service() {

    private val healthHandler = Handler(Looper.getMainLooper())
    private val healthCheckIntervalMs = 90_000L

    private val healthCheckRunnable = object : Runnable {
        override fun run() {
            if (!NotificationAccessHelper.isNotificationAccessGranted(this@ListenerKeepAliveService)) {
                return
            }
            if (!NotificationAccessHelper.isListenerConnected()) {
                NotificationAccessHelper.logDebug("Health check: listener down, scheduling burst")
                ListenerReconnectScheduler.scheduleBurst(
                    applicationContext,
                    allowComponentReset = false
                )
            }
            healthHandler.postDelayed(this, healthCheckIntervalMs)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!NotificationAccessHelper.isNotificationAccessGranted(this)) {
            ListenerWatchdog.cancel(this)
            stopSelf()
            return START_NOT_STICKY
        }

        promoteToForeground()
        NotificationAccessHelper.requestRebind(this)
        ListenerWatchdog.schedule(this)
        healthHandler.removeCallbacks(healthCheckRunnable)
        healthHandler.postDelayed(healthCheckRunnable, healthCheckIntervalMs)
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        if (NotificationAccessHelper.isNotificationAccessGranted(this)) {
            NotificationAccessHelper.logDebug("Task removed — restarting keep-alive")
            start(applicationContext)
        }
    }

    override fun onDestroy() {
        healthHandler.removeCallbacks(healthCheckRunnable)
        if (NotificationAccessHelper.isNotificationAccessGranted(this)) {
            NotificationAccessHelper.logDebug("Keep-alive destroyed — scheduling restart")
            ListenerWatchdog.scheduleSoon(applicationContext)
        }
        super.onDestroy()
    }

    private fun promoteToForeground() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_koban)
            .setContentTitle(getString(R.string.keepalive_notification_title))
            .setContentText(getString(R.string.keepalive_notification_text))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(
                PendingIntent.getActivity(
                    this,
                    0,
                    Intent(this, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            @Suppress("DEPRECATION")
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.keepalive_channel_name),
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = getString(R.string.keepalive_channel_description)
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val CHANNEL_ID = "listener_keepalive"
        private const val NOTIFICATION_ID = 1001

        fun start(context: Context) {
            if (!NotificationAccessHelper.isNotificationAccessGranted(context)) return
            val intent = Intent(context, ListenerKeepAliveService::class.java)
            try {
                context.startForegroundService(intent)
            } catch (e: IllegalStateException) {
                // Android 12+ refuses this when the system starts the app in the background
                // (ForegroundServiceStartNotAllowedException). The next start from the foreground retries it.
                android.util.Log.w("ListenerKeepAlive", "Foreground service start refused", e)
            }
        }

        fun stop(context: Context) {
            ListenerWatchdog.cancel(context)
            context.stopService(Intent(context, ListenerKeepAliveService::class.java))
        }

        fun sync(context: Context) {
            if (NotificationAccessHelper.isNotificationAccessGranted(context)) {
                start(context)
            } else {
                stop(context)
            }
        }
    }
}
