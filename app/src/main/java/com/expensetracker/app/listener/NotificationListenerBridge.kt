package com.expensetracker.app.listener

import android.app.Notification
import android.service.notification.StatusBarNotification
import java.util.concurrent.atomic.AtomicReference

object NotificationListenerBridge {
    private val instance = AtomicReference<ExpenseNotificationListener?>()

    internal fun register(listener: ExpenseNotificationListener) {
        instance.set(listener)
    }

    internal fun unregister(listener: ExpenseNotificationListener) {
        instance.compareAndSet(listener, null)
    }

    fun isServiceConnected(): Boolean = instance.get()?.isListenerConnected() == true

    fun refreshActiveNotifications(): Boolean {
        return instance.get()?.captureActiveNotifications() == true
    }

    internal fun extractFrom(sbn: StatusBarNotification): NotificationTextBundle {
        return instance.get()?.extractText(sbn.notification)
            ?: NotificationTextExtractor.extract(sbn.notification)
    }
}

data class NotificationTextBundle(
    val title: String?,
    val body: String
)

internal object NotificationTextExtractor {
    fun extract(notification: Notification?): NotificationTextBundle {
        if (notification == null) return NotificationTextBundle(null, "")

        val extras = notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_TITLE_BIG)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()

        val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.mapNotNull { it?.toString() }
            ?.joinToString("\n")

        val body = listOfNotNull(bigText, text, lines)
            .filter { !it.isNullOrBlank() }
            .distinct()
            .joinToString("\n")
            .trim()

        return NotificationTextBundle(title = title, body = body)
    }
}
