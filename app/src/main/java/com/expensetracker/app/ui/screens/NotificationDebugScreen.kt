package com.expensetracker.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
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
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.listener.CapturedNotification
import com.expensetracker.app.listener.NotificationCaptureEvent
import com.expensetracker.app.listener.NotificationDisposition
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
                    totalCaptured = uiState.notifications.size
                )
            }

            item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(
                        onClick = viewModel::reconnectListener,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Reconnect listener")
                    }
                    OutlinedButton(
                        onClick = viewModel::snapshotActiveNotifications,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Snapshot active notifications")
                    }
                    OutlinedButton(
                        onClick = viewModel::clearLog,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Clear log")
                    }
                    uiState.refreshMessage?.let { message ->
                        Text(
                            text = message,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }
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
                    CapturedNotificationCard(uiState.filteredNotifications[index])
                }
            }
        }
    }
}

@Composable
private fun StatusCard(
    isAccessGranted: Boolean,
    isServiceConnected: Boolean,
    listenerState: com.expensetracker.app.listener.ListenerDebugState,
    totalCaptured: Int
) {
    val healthy = isAccessGranted && isServiceConnected
    val containerColor = if (healthy) Color(0xFFE8F5E9) else Color(0xFFFFF3E0)
    val contentColor = if (healthy) Color(0xFF2E7D32) else Color(0xFFE65100)

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = containerColor)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            androidx.compose.foundation.layout.Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = if (healthy) Icons.Default.CheckCircle else Icons.Default.Warning,
                    contentDescription = null,
                    tint = contentColor
                )
                Text(
                    text = when {
                        !isAccessGranted -> "Notification access not granted"
                        !isServiceConnected -> "Access granted, listener not connected"
                        else -> "Listener active"
                    },
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = contentColor
                )
            }
            Text(
                text = "Captured: $totalCaptured · Connected: ${listenerState.isConnected}",
                style = MaterialTheme.typography.bodySmall,
                color = contentColor
            )
            listenerState.lastConnectedAt?.let {
                Text(
                    text = "Last connected: ${formatTimestamp(it)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = contentColor
                )
            }
        }
    }
}

@Composable
private fun CapturedNotificationCard(notification: CapturedNotification) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            androidx.compose.foundation.layout.Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = notification.packageName,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.weight(1f)
                )
                Text(
                    text = notification.disposition.label(),
                    style = MaterialTheme.typography.labelMedium,
                    color = notification.disposition.color()
                )
            }
            Text(
                text = "${notification.event.label()} · ${formatTimestamp(notification.capturedAt)}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            notification.title?.let { title ->
                Text(
                    text = "Title: $title",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium
                )
            }
            Text(
                text = notification.body,
                style = MaterialTheme.typography.bodyMedium
            )
            notification.detail?.let { detail ->
                Text(
                    text = detail,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Text(
                text = "Posted: ${formatTimestamp(notification.postTime)}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

private fun NotificationDebugFilter.label(): String = when (this) {
    NotificationDebugFilter.ALL -> "All"
    NotificationDebugFilter.POSTED_ONLY -> "Posted"
    NotificationDebugFilter.SAVED -> "Saved"
    NotificationDebugFilter.SKIPPED -> "Skipped"
}

private fun NotificationCaptureEvent.label(): String = when (this) {
    NotificationCaptureEvent.POSTED -> "Posted"
    NotificationCaptureEvent.REMOVED -> "Removed"
    NotificationCaptureEvent.ACTIVE_SNAPSHOT -> "Active"
}

private fun NotificationDisposition.label(): String = when (this) {
    NotificationDisposition.PENDING -> "Pending"
    NotificationDisposition.SAVED -> "Saved"
    NotificationDisposition.SKIPPED_ALLOWLIST -> "Allowlist"
    NotificationDisposition.SKIPPED_NO_AMOUNT -> "No amount"
    NotificationDisposition.SKIPPED_NOT_TRANSACTION -> "Not transaction"
    NotificationDisposition.SKIPPED_DUPLICATE -> "Duplicate"
    NotificationDisposition.SKIPPED_GROUP_SUMMARY -> "Group"
    NotificationDisposition.SKIPPED_EMPTY -> "Empty"
    NotificationDisposition.SKIPPED_ERROR -> "Error"
    NotificationDisposition.INFO_ONLY -> "Info"
}

@Composable
private fun NotificationDisposition.color(): Color = when (this) {
    NotificationDisposition.SAVED -> Color(0xFF2E7D32)
    NotificationDisposition.PENDING -> MaterialTheme.colorScheme.primary
    NotificationDisposition.INFO_ONLY -> MaterialTheme.colorScheme.onSurfaceVariant
    else -> Color(0xFFE65100)
}

private fun formatTimestamp(ms: Long): String {
    return SimpleDateFormat("MMM d, HH:mm:ss", Locale.getDefault()).format(Date(ms))
}
