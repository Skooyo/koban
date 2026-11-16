package com.expensetracker.app.listener

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class ExpenseNotificationListener : NotificationListenerService() {

    @Volatile
    private var listenerConnected = false

    override fun onCreate() {
        super.onCreate()
        NotificationListenerBridge.register(this)
        NotificationAccessHelper.logDebug("Notification listener created")
    }

    override fun onDestroy() {
        NotificationListenerBridge.unregister(this)
        super.onDestroy()
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        listenerConnected = true
        RecentNotificationsStore.setConnected(true)
        ListenerReconnectScheduler.cancel()
        ListenerDisconnectNotifier.hide(this)
        ListenerKeepAliveService.start(this)
        captureActiveNotifications()
        CaptureSignal.wakeIfQueued(this)
        NotificationAccessHelper.logDebug("Notification listener connected")
    }

    override fun onListenerDisconnected() {
        listenerConnected = false
        RecentNotificationsStore.setConnected(false)
        NotificationAccessHelper.softReconnectListener(this, bypassThrottle = true)
        super.onListenerDisconnected()
        NotificationAccessHelper.logDebug("Notification listener disconnected — soft reconnect scheduled")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        handleNotification(sbn, NotificationCaptureEvent.POSTED)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        handleNotification(sbn, NotificationCaptureEvent.REMOVED)
    }

    fun isListenerConnected(): Boolean = listenerConnected

    fun captureActiveNotifications(): Boolean {
        if (!listenerConnected) return false
        return try {
            activeNotifications?.forEach { sbn ->
                recordNotification(
                    sbn = sbn,
                    event = NotificationCaptureEvent.ACTIVE_SNAPSHOT,
                    disposition = NotificationDisposition.INFO_ONLY,
                    detail = "Currently active in status bar"
                )
            }
            true
        } catch (e: Exception) {
            NotificationAccessHelper.logDebug("Failed to snapshot active notifications: ${e.message}")
            false
        }
    }

    internal fun extractText(notification: Notification?): NotificationTextBundle {
        return NotificationTextExtractor.extract(notification)
    }

    private fun handleNotification(sbn: StatusBarNotification, event: NotificationCaptureEvent) {
        try {
            // A repost of the same notification is already in the log.
            if (event == NotificationCaptureEvent.POSTED &&
                RecentNotificationsStore.hasSeen(sbn.packageName, sbn.key, sbn.postTime)
            ) return
            val notification = sbn.notification
            if (notification == null) {
                recordNotification(
                    sbn = sbn,
                    event = event,
                    disposition = NotificationDisposition.SKIPPED_EMPTY,
                    detail = "Notification payload was null"
                )
                return
            }

            if (event == NotificationCaptureEvent.REMOVED) {
                recordNotification(
                    sbn = sbn,
                    event = event,
                    disposition = NotificationDisposition.INFO_ONLY,
                    detail = "Removed from status bar"
                )
                return
            }

            if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) {
                recordNotification(
                    sbn = sbn,
                    event = event,
                    disposition = NotificationDisposition.SKIPPED_GROUP_SUMMARY,
                    detail = "Group summary notification"
                )
                return
            }

            val textBundle = extractText(notification)
            val bodyText = textBundle.body.trim()
            val combinedText = buildString {
                textBundle.title?.let { append(it).append(' ') }
                append(bodyText)
            }.trim()
            val parseText = bodyText.ifBlank { combinedText }

            if (parseText.isEmpty()) {
                recordNotification(
                    sbn = sbn,
                    event = event,
                    disposition = NotificationDisposition.SKIPPED_EMPTY,
                    detail = "No title or body text found"
                )
                return
            }

            val watched = PaymentAppsMirror.read(this)
            if (watched != null && sbn.packageName !in watched) return

            val captureId = recordNotification(
                sbn = sbn,
                event = event,
                title = textBundle.title,
                body = parseText,
                disposition = NotificationDisposition.PENDING,
                detail = "Processing…"
            )

            val added = CaptureQueue.get(this).add(
                QueuedNotification(
                    logId = captureId,
                    packageName = sbn.packageName,
                    title = textBundle.title,
                    text = parseText,
                    postTime = sbn.postTime,
                    notificationKey = sbn.key
                )
            )
            if (!added) {
                RecentNotificationsStore.update(
                    captureId,
                    NotificationDisposition.SKIPPED_DUPLICATE,
                    "Already processing this notification"
                )
                return
            }
            CaptureSignal.wake(this)
        } catch (e: Exception) {
            NotificationAccessHelper.logDebug("Failed to process notification: ${e.message}")
            recordNotification(
                sbn = sbn,
                event = event,
                disposition = NotificationDisposition.SKIPPED_ERROR,
                detail = e.message ?: "Unknown error"
            )
        }
    }

    private fun recordNotification(
        sbn: StatusBarNotification,
        event: NotificationCaptureEvent,
        disposition: NotificationDisposition,
        detail: String? = null,
        title: String? = null,
        body: String? = null
    ): String {
        val textBundle = if (title != null || body != null) {
            NotificationTextBundle(title, body.orEmpty())
        } else {
            extractText(sbn.notification)
        }
        val displayBody = body ?: run {
            val bodyText = textBundle.body.trim()
            val combined = buildString {
                textBundle.title?.let { append(it).append(' ') }
                append(bodyText)
            }.trim()
            bodyText.ifBlank { combined }.ifBlank { "—" }
        }

        val captured = CapturedNotification(
            packageName = sbn.packageName,
            title = title ?: textBundle.title,
            body = displayBody,
            postTime = sbn.postTime,
            event = event,
            disposition = disposition,
            detail = detail,
            key = sbn.key
        )
        // Only watched apps go in the log, so other apps do not push payments out of its 200 rows.
        // One row for each notification: a scan or a removal of a logged one adds no copy.
        if (PaymentAppsMirror.read(this)?.contains(sbn.packageName) != false) RecentNotificationsStore.addUnlessSeen(captured)
        return captured.id
    }
}
