package com.expensetracker.app.listener

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.expensetracker.app.MainActivity
import com.expensetracker.app.R

/**
 * Shown when notification access is granted but the listener will not reconnect on its own.
 */
object ListenerDisconnectNotifier {
    private const val CHANNEL_ID = "listener_disconnect_alert"
    private const val NOTIFICATION_ID = 1002

    fun show(context: Context) {
        val appContext = context.applicationContext
        ensureChannel(appContext)

        val openApp = PendingIntent.getActivity(
            appContext,
            0,
            Intent(appContext, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(MainActivity.EXTRA_RECONNECT_LISTENER, true)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val openSettings = PendingIntent.getActivity(
            appContext,
            1,
            Intent(android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(appContext, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_koban)
            .setContentTitle(appContext.getString(R.string.disconnect_alert_title))
            .setContentText(appContext.getString(R.string.disconnect_alert_text))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ERROR)
            .setAutoCancel(false)
            .setContentIntent(openApp)
            .addAction(
                R.drawable.ic_stat_koban,
                appContext.getString(R.string.disconnect_alert_reconnect),
                openApp
            )
            .addAction(
                R.drawable.ic_stat_koban,
                appContext.getString(R.string.disconnect_alert_settings),
                openSettings
            )
            .build()

        val manager = appContext.getSystemService(NotificationManager::class.java) ?: return
        manager.notify(NOTIFICATION_ID, notification)
    }

    fun hide(context: Context) {
        val manager = context.applicationContext.getSystemService(NotificationManager::class.java) ?: return
        manager.cancel(NOTIFICATION_ID)
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.disconnect_alert_channel),
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = context.getString(R.string.disconnect_alert_channel_description)
        }
        manager.createNotificationChannel(channel)
    }
}
