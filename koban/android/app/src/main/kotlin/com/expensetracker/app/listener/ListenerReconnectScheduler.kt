package com.expensetracker.app.listener

import android.content.Context
import android.os.Handler
import android.os.Looper
import java.util.concurrent.atomic.AtomicInteger

/**
 * Fires multiple rebind attempts over ~60s. HyperOS often ignores the first [requestRebind].
 */
object ListenerReconnectScheduler {
    private val handler = Handler(Looper.getMainLooper())
    private val generation = AtomicInteger(0)
    private val burstDelaysMs = longArrayOf(0L, 2_000L, 5_000L, 15_000L, 30_000L, 60_000L)

    fun scheduleBurst(
        context: Context,
        allowComponentReset: Boolean = false
    ) {
        val appContext = context.applicationContext
        val burstId = generation.incrementAndGet()

        burstDelaysMs.forEachIndexed { index, delayMs ->
            handler.postDelayed({
                if (burstId != generation.get()) return@postDelayed
                if (!NotificationAccessHelper.isNotificationAccessGranted(appContext)) return@postDelayed

                NotificationAccessHelper.requestRebind(appContext)
                ListenerKeepAliveService.start(appContext)

                val isLastAttempt = index == burstDelaysMs.lastIndex
                if (isLastAttempt && allowComponentReset && !NotificationAccessHelper.isListenerConnected()) {
                    NotificationAccessHelper.resetComponentBinding(appContext)
                    NotificationAccessHelper.requestRebind(appContext)
                }
            }, delayMs)
        }

        handler.postDelayed({
            if (burstId != generation.get()) return@postDelayed
            val granted = NotificationAccessHelper.isNotificationAccessGranted(appContext)
            val connected = NotificationAccessHelper.isListenerConnected()
            when {
                granted && connected -> ListenerDisconnectNotifier.hide(appContext)
                granted && !connected -> ListenerDisconnectNotifier.show(appContext)
            }
        }, burstDelaysMs.last() + 1_500L)
    }

    fun cancel() {
        generation.incrementAndGet()
    }
}
