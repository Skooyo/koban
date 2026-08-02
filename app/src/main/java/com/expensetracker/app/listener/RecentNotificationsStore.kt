package com.expensetracker.app.listener

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

object RecentNotificationsStore {
    private const val MAX_SIZE = 200
    private val lock = Any()
    private val items = ArrayDeque<CapturedNotification>()

    private val _notifications = MutableStateFlow<List<CapturedNotification>>(emptyList())
    val notifications: StateFlow<List<CapturedNotification>> = _notifications.asStateFlow()

    private val _listenerState = MutableStateFlow(ListenerDebugState())
    val listenerState: StateFlow<ListenerDebugState> = _listenerState.asStateFlow()

    fun add(notification: CapturedNotification) {
        synchronized(lock) {
            items.addFirst(notification)
            while (items.size > MAX_SIZE) {
                items.removeLast()
            }
            publish()
        }
    }

    fun update(id: String, disposition: NotificationDisposition, detail: String? = null) {
        synchronized(lock) {
            val index = items.indexOfFirst { it.id == id }
            if (index < 0) return
            val current = items.removeAt(index)
            items.add(index, current.copy(disposition = disposition, detail = detail))
            publish()
        }
    }

    fun setConnected(connected: Boolean) {
        val now = System.currentTimeMillis()
        _listenerState.update { state ->
            state.copy(
                isConnected = connected,
                lastConnectedAt = if (connected) now else state.lastConnectedAt,
                lastDisconnectedAt = if (!connected) now else state.lastDisconnectedAt
            )
        }
    }

    fun clear() {
        synchronized(lock) {
            items.clear()
            publish()
        }
    }

    fun snapshot(): List<CapturedNotification> = synchronized(lock) {
        items.toList()
    }

    fun uniquePackages(): List<String> = synchronized(lock) {
        items.map { it.packageName }.distinct().sorted()
    }

    private fun publish() {
        val list = items.toList()
        _notifications.value = list
        _listenerState.update { it.copy(totalCaptured = list.size) }
    }
}
