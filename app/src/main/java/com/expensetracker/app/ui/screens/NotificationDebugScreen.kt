package com.expensetracker.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.listener.CapturedNotification
import com.expensetracker.app.listener.NotificationCaptureEvent
import com.expensetracker.app.listener.NotificationDisposition
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.viewmodel.NotificationDebugFilter
import com.expensetracker.app.ui.viewmodel.NotificationDebugViewModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun NotificationDebugScreen(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: NotificationDebugViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val lifecycleOwner = LocalLifecycleOwner.current

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.refresh()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = { Text("Notification log") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = viewModel::refresh) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh")
                    }
                }
            )
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                StatusCard(
                    isAccessGranted = uiState.isAccessGranted,
                    isServiceConnected = uiState.isServiceConnected,
                    listenerState = uiState.listenerState,
                    totalCaptured = uiState.notifications.size,
                    refreshMessage = uiState.refreshMessage,
                    onReconnect = viewModel::reconnectListener,
                    onSnapshot = viewModel::snapshotActiveNotifications,
                    onClear = viewModel::clearLog
                )
            }

            item {
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    NotificationDebugFilter.entries.forEach { option ->
                        FilterChip(
                            selected = uiState.filter == option,
                            onClick = { viewModel.setFilter(option) },
                            label = { Text(option.label()) }
                        )
                    }
                }
            }

            if (uiState.filteredNotifications.isEmpty()) {
                item {
                    Text(
                        text = if (uiState.notifications.isEmpty()) {
                            "No notifications captured yet. Make a payment or tap “Snapshot active notifications” after granting access."
                        } else {
                            "No notifications match this filter."
                        },
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                items(
                    count = uiState.filteredNotifications.size,
                    key = { index -> uiState.filteredNotifications[index].id }
                ) { index ->
                    CapturedNotificationCard(uiState.filteredNotifications[index], viewModel::markAsPayment)
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun StatusCard(
    isAccessGranted: Boolean,
    isServiceConnected: Boolean,
    listenerState: com.expensetracker.app.listener.ListenerDebugState,
    totalCaptured: Int,
    refreshMessage: String?,
    onReconnect: () -> Unit,
    onSnapshot: () -> Unit,
    onClear: () -> Unit
) {
    val healthy = isAccessGranted && isServiceConnected
    val statusColor = if (healthy) LocalMoneyColors.current.received else LocalMoneyColors.current.review

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceContainer)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(Modifier.size(10.dp).clip(CircleShape).background(statusColor))
            Text(
                text = when {
                    !isAccessGranted -> "Notification access not granted"
                    !isServiceConnected -> "Access granted, listener not connected"
                    else -> "Listener active"
                },
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
        Text(
            text = buildString {
                append("Captured $totalCaptured · ${if (listenerState.isConnected) "listener connected" else "listener not connected"}")
                listenerState.lastConnectedAt?.let { append(" · last connected ${formatTimestamp(it)}") }
            },
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            OutlinedButton(onClick = onReconnect, modifier = Modifier.defaultMinSize(minHeight = 48.dp)) {
                Text("Reconnect listener")
            }
            OutlinedButton(onClick = onSnapshot, modifier = Modifier.defaultMinSize(minHeight = 48.dp)) {
                Text("Snapshot")
            }
            TextButton(
                onClick = onClear,
                modifier = Modifier.defaultMinSize(minHeight = 48.dp),
                colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)
            ) {
                Text("Clear log")
            }
        }
        refreshMessage?.let { message ->
            Text(
                text = message,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}

@Composable
private fun CapturedNotificationCard(
    notification: CapturedNotification,
    onMarkAsPayment: (CapturedNotification) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceContainer)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "${notification.packageName} · ${notification.event.label()} · ${formatTimestamp(notification.capturedAt)}",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f)
            )
            StatusBadge(notification.disposition.label(), notification.disposition.color())
        }
        notification.title?.let { title ->
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
        Text(
            text = notification.body,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        notification.detail?.let { detail ->
            Text(
                text = detail,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Text(
            text = "Posted ${formatTimestamp(notification.postTime)}",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        // Any logged notification the app did not turn into a card: skipped, missed or only seen in the tray.
        if (notification.disposition != NotificationDisposition.WAITING &&
            notification.disposition != NotificationDisposition.PENDING
        ) {
            TextButton(
                onClick = { onMarkAsPayment(notification) },
                modifier = Modifier.align(Alignment.End).defaultMinSize(minHeight = 48.dp)
            ) {
                Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text("Add as payment")
            }
        }
    }
}

/** Outlined status badge: label and outline share one color. */
@Composable
private fun StatusBadge(text: String, color: Color) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelSmall,
        color = color,
        modifier = Modifier
            .border(1.dp, color, CircleShape)
            .padding(horizontal = 8.dp, vertical = 2.dp)
    )
}

private fun NotificationDebugFilter.label(): String = when (this) {
    NotificationDebugFilter.ALL -> "All"
    NotificationDebugFilter.POSTED_ONLY -> "Posted"
    NotificationDebugFilter.WAITING -> "Waiting"
    NotificationDebugFilter.SKIPPED -> "Skipped"
}

private fun NotificationCaptureEvent.label(): String = when (this) {
    NotificationCaptureEvent.POSTED -> "Posted"
    NotificationCaptureEvent.REMOVED -> "Removed"
    NotificationCaptureEvent.ACTIVE_SNAPSHOT -> "Active"
}

private fun NotificationDisposition.label(): String = when (this) {
    NotificationDisposition.PENDING -> "Pending"
    NotificationDisposition.WAITING -> "Waiting for check"
    NotificationDisposition.SKIPPED_ALLOWLIST -> "Not a payment app"
    NotificationDisposition.SKIPPED_NO_RULE -> "No rule matched"
    NotificationDisposition.SKIPPED_DUPLICATE -> "Duplicate"
    NotificationDisposition.SKIPPED_GROUP_SUMMARY -> "Group"
    NotificationDisposition.SKIPPED_EMPTY -> "Empty"
    NotificationDisposition.SKIPPED_ERROR -> "Error"
    NotificationDisposition.INFO_ONLY -> "Info"
}

@Composable
private fun NotificationDisposition.color(): Color = when (this) {
    NotificationDisposition.WAITING -> LocalMoneyColors.current.review
    NotificationDisposition.SKIPPED_NO_RULE, NotificationDisposition.SKIPPED_ERROR -> MaterialTheme.colorScheme.error
    NotificationDisposition.PENDING -> MaterialTheme.colorScheme.primary
    else -> MaterialTheme.colorScheme.onSurfaceVariant
}

private fun formatTimestamp(ms: Long): String {
    return SimpleDateFormat("MMM d, HH:mm:ss", Locale.getDefault()).format(Date(ms))
}
