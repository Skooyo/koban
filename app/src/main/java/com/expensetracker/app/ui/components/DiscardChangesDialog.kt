package com.expensetracker.app.ui.components

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp

/** Asks before typed changes are dropped. A tap outside means keep editing. */
@Composable
fun DiscardChangesDialog(onDiscard: () -> Unit, onKeepEditing: () -> Unit) {
    AlertDialog(
        onDismissRequest = onKeepEditing,
        shape = RoundedCornerShape(28.dp),
        containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
        title = { Text("Discard changes?", style = MaterialTheme.typography.headlineSmall) },
        text = { Text("Your changes are not saved.", style = MaterialTheme.typography.bodyMedium) },
        confirmButton = { TextButton(
            onClick = onDiscard,
            colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)
        ) { Text("Discard") } },
        dismissButton = { TextButton(onClick = onKeepEditing) { Text("Keep editing") } }
    )
}
