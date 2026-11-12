package com.expensetracker.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.expensetracker.app.update.UpdateState
import kotlin.math.roundToInt

/** Shows for Available, Downloading, Installing and Failed. Nothing for the other states. */
@Composable
fun UpdateDialog(state: UpdateState, onUpdate: () -> Unit, onDismiss: () -> Unit) {
    when (state) {
        is UpdateState.Available -> {
            val update = state.update
            val sizeMb = (update.apkSize / 1_000_000.0).roundToInt().coerceAtLeast(1)
            AlertDialog(
                onDismissRequest = onDismiss,
                title = { Text("Update available") },
                text = {
                    Column(
                        modifier = Modifier.verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text("Koban ${update.versionName} is ready ($sizeMb MB).")
                        if (update.notes.isNotBlank()) Text(update.notes)
                    }
                },
                confirmButton = { TextButton(onClick = onUpdate) { Text("Update") } },
                dismissButton = { TextButton(onClick = onDismiss) { Text("Later") } }
            )
        }
        UpdateState.Downloading -> AlertDialog(
            onDismissRequest = {},
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text("Downloading the update…")
                    LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
                }
            },
            confirmButton = {}
        )
        UpdateState.Installing -> AlertDialog(
            onDismissRequest = {},
            text = { Text("Installing…") },
            confirmButton = {}
        )
        is UpdateState.Failed -> AlertDialog(
            onDismissRequest = onDismiss,
            text = { Text(state.message) },
            confirmButton = { TextButton(onClick = onDismiss) { Text("OK") } }
        )
        UpdateState.Idle, UpdateState.UpToDate -> Unit
    }
}
