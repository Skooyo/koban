package com.expensetracker.app.listener

import java.util.UUID

enum class NotificationCaptureEvent {
    POSTED,
    REMOVED,
    ACTIVE_SNAPSHOT
}

enum class NotificationDisposition {
    PENDING,
    SAVED,
    SKIPPED_ALLOWLIST,
    SKIPPED_NO_AMOUNT,
    SKIPPED_NOT_TRANSACTION,
    SKIPPED_DUPLICATE,
    SKIPPED_GROUP_SUMMARY,
    SKIPPED_EMPTY,
    SKIPPED_ERROR,
    INFO_ONLY
}

data class CapturedNotification(
    val id: String = UUID.randomUUID().toString(),
    val packageName: String,
    val title: String?,
    val body: String,
    val postTime: Long,
    val capturedAt: Long = System.currentTimeMillis(),
    val event: NotificationCaptureEvent = NotificationCaptureEvent.POSTED,
    val disposition: NotificationDisposition = NotificationDisposition.PENDING,
    val detail: String? = null
)

data class ListenerDebugState(
    val isConnected: Boolean = false,
    val lastConnectedAt: Long? = null,
    val lastDisconnectedAt: Long? = null,
    val totalCaptured: Int = 0
)
