package com.expensetracker.app.listener

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.expensetracker.app.data.PendingPaymentRepository
import com.expensetracker.app.data.SettingsRepository
import com.expensetracker.app.di.NotificationListenerEntryPoint
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.parser.PaymentRules
import com.expensetracker.app.parser.RuleMatch
import dagger.hilt.android.EntryPointAccessors
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.util.Collections

class ExpenseNotificationListener : NotificationListenerService() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val processingKeys = Collections.synchronizedSet(mutableSetOf<String>())

    @Volatile
    private var pendingPaymentRepository: PendingPaymentRepository? = null

    @Volatile
    private var settingsRepository: SettingsRepository? = null

    @Volatile
    private var listenerConnected = false

    /** The allowlist. Null until it loads; until then the log shows all apps. */
    @Volatile
    private var watchedPackages: Set<String>? = null

    private val initLock = Any()

    override fun onCreate() {
        super.onCreate()
        NotificationListenerBridge.register(this)
        ensureRepositories()
        scope.launch {
            if (ensureRepositories()) settingsRepository!!.allowlistedPackages.collect { watchedPackages = it }
        }
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
        ensureRepositories()
        ListenerKeepAliveService.start(this)
        captureActiveNotifications()
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

            val captureId = recordNotification(
                sbn = sbn,
                event = event,
                title = textBundle.title,
                body = parseText,
                disposition = NotificationDisposition.PENDING,
                detail = "Processing…"
            )

            val processingKey = sbn.key ?: "${sbn.packageName}|${sbn.postTime}|${parseText.hashCode()}"
            if (!processingKeys.add(processingKey)) {
                RecentNotificationsStore.update(
                    captureId,
                    NotificationDisposition.SKIPPED_DUPLICATE,
                    "Already processing this notification"
                )
                return
            }

            scope.launch {
                try {
                    processForExpense(captureId, sbn, parseText)
                } finally {
                    processingKeys.remove(processingKey)
                }
            }
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

    private suspend fun processForExpense(
        captureId: String,
        sbn: StatusBarNotification,
        parseText: String
    ) {
        try {
            if (!ensureRepositories()) {
                RecentNotificationsStore.update(
                    captureId,
                    NotificationDisposition.SKIPPED_ERROR,
                    "App data not ready"
                )
                return
            }
            val settings = settingsRepository!!
            val pending = pendingPaymentRepository!!

            val allowlist = settings.allowlistedPackages.first()
            if (allowlist.isEmpty() || sbn.packageName !in allowlist) {
                RecentNotificationsStore.update(
                    captureId,
                    NotificationDisposition.SKIPPED_ALLOWLIST,
                    "Package not on allowlist"
                )
                return
            }

            when (val match = PaymentRules.match(sbn.packageName, parseText)) {
                RuleMatch.NoMatch -> RecentNotificationsStore.update(
                    captureId,
                    NotificationDisposition.SKIPPED_NO_RULE,
                    "No rule matched this text"
                )
                is RuleMatch.Matched -> {
                    val parsed = match.expense
                    val id = pending.capture(
                        parsed = parsed,
                        format = match.format,
                        rawText = parseText,
                        sourcePackage = sbn.packageName,
                        notificationPostTime = sbn.postTime,
                        notificationKey = sbn.key
                    )
                    if (id != null) {
                        val summary =
                            "${parsed.merchant ?: "Unknown"} · RM ${AmountFormatter.formatDisplay(parsed.amount)}"
                        RecentNotificationsStore.update(captureId, NotificationDisposition.WAITING, summary)
                        NotificationAccessHelper.logDebug("Waiting for check: $summary")
                    } else {
                        RecentNotificationsStore.update(
                            captureId,
                            NotificationDisposition.SKIPPED_DUPLICATE,
                            "Duplicate within dedup window"
                        )
                    }
                }
            }
        } catch (e: Exception) {
            RecentNotificationsStore.update(
                captureId,
                NotificationDisposition.SKIPPED_ERROR,
                e.message ?: "Save failed"
            )
            NotificationAccessHelper.logDebug("Failed to save notification: ${e.message}")
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
            detail = detail
        )
        // Only watched apps go in the log, so other apps do not push payments out of its 200 rows.
        if (watchedPackages?.contains(sbn.packageName) != false) RecentNotificationsStore.add(captured)
        return captured.id
    }

    private fun ensureRepositories(): Boolean {
        if (pendingPaymentRepository != null &&
            settingsRepository != null
        ) {
            return true
        }

        synchronized(initLock) {
            if (pendingPaymentRepository != null &&
                settingsRepository != null
            ) {
                return true
            }
            return try {
                val entryPoint = EntryPointAccessors.fromApplication(
                    applicationContext,
                    NotificationListenerEntryPoint::class.java
                )
                pendingPaymentRepository = entryPoint.pendingPaymentRepository()
                settingsRepository = entryPoint.settingsRepository()
                true
            } catch (e: Exception) {
                NotificationAccessHelper.logDebug("Failed to init repositories: ${e.message}")
                false
            }
        }
    }
}
