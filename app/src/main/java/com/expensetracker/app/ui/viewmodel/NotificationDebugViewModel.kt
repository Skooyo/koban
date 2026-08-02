package com.expensetracker.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.listener.CapturedNotification
import com.expensetracker.app.listener.ListenerDebugState
import com.expensetracker.app.listener.NotificationAccessHelper
import com.expensetracker.app.listener.NotificationListenerBridge
import com.expensetracker.app.listener.ReconnectResult
import com.expensetracker.app.listener.NotificationCaptureEvent
import com.expensetracker.app.listener.NotificationDisposition
import com.expensetracker.app.listener.RecentNotificationsStore
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import javax.inject.Inject

enum class NotificationDebugFilter {
    ALL,
    POSTED_ONLY,
    SAVED,
    SKIPPED
}

data class NotificationDebugUiState(
    val isAccessGranted: Boolean = false,
    val listenerState: ListenerDebugState = ListenerDebugState(),
    val isServiceConnected: Boolean = false,
    val notifications: List<CapturedNotification> = emptyList(),
    val filter: NotificationDebugFilter = NotificationDebugFilter.ALL,
    val refreshMessage: String? = null
) {
    val filteredNotifications: List<CapturedNotification>
        get() = when (filter) {
            NotificationDebugFilter.ALL -> notifications
            NotificationDebugFilter.POSTED_ONLY -> notifications.filter {
                it.event == NotificationCaptureEvent.POSTED
            }
            NotificationDebugFilter.SAVED -> notifications.filter {
                it.disposition == NotificationDisposition.SAVED
            }
            NotificationDebugFilter.SKIPPED -> notifications.filter {
                it.disposition != NotificationDisposition.SAVED &&
                    it.disposition != NotificationDisposition.PENDING &&
                    it.disposition != NotificationDisposition.INFO_ONLY
            }
        }
}

@HiltViewModel
class NotificationDebugViewModel @Inject constructor(
    @ApplicationContext private val context: Context
) : ViewModel() {

    private val accessGranted = MutableStateFlow(false)
    private val filter = MutableStateFlow(NotificationDebugFilter.ALL)
    private val refreshMessage = MutableStateFlow<String?>(null)

    val uiState: StateFlow<NotificationDebugUiState> = combine(
        accessGranted,
        RecentNotificationsStore.notifications,
        RecentNotificationsStore.listenerState,
        filter,
        refreshMessage
    ) { granted, notifications, listenerState, activeFilter, message ->
        NotificationDebugUiState(
            isAccessGranted = granted,
            listenerState = listenerState,
            isServiceConnected = NotificationListenerBridge.isServiceConnected(),
            notifications = notifications,
            filter = activeFilter,
            refreshMessage = message
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), NotificationDebugUiState())

    fun refresh() {
        accessGranted.value = NotificationAccessHelper.isNotificationAccessGranted(context)
        refreshMessage.value = null
        NotificationAccessHelper.ensureListenerActive(context)
    }

    fun reconnectListener() {
        viewModelScope.launch {
            refreshMessage.value = "Reconnecting…"
            when (NotificationAccessHelper.reconnectListener(context)) {
                ReconnectResult.ACCESS_NOT_GRANTED -> {
                    refreshMessage.value =
                        "Notification access was removed — re-enable in system settings."
                    return@launch
                }
                ReconnectResult.THROTTLED -> {
                    refreshMessage.value = "Reconnect already attempted recently."
                    return@launch
                }
                ReconnectResult.FAILED -> {
                    refreshMessage.value = "Reconnect failed — open notification access settings."
                    return@launch
                }
                ReconnectResult.ATTEMPTED -> Unit
            }
            delay(65_000)
            refreshMessage.value = if (NotificationListenerBridge.isServiceConnected()) {
                "Listener connected."
            } else {
                "Still disconnected — use the alert notification or open notification access settings."
            }
        }
    }

    fun setFilter(value: NotificationDebugFilter) {
        filter.value = value
    }

    fun clearLog() {
        RecentNotificationsStore.clear()
        refreshMessage.value = "Log cleared"
    }

    fun snapshotActiveNotifications() {
        val refreshed = NotificationListenerBridge.refreshActiveNotifications()
        refreshMessage.value = if (refreshed) {
            "Snapshotted active status-bar notifications"
        } else {
            "Listener not connected — toggle notification access off/on, then try again"
        }
    }

    fun dismissMessage() {
        refreshMessage.value = null
    }
}
