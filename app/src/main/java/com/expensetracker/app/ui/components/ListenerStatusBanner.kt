package com.expensetracker.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

@Composable
fun ListenerStatusBanner(
    isAccessGranted: Boolean,
    onEnableClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val containerColor = if (isAccessGranted) Color(0xFFE8F5E9) else Color(0xFFFFEBEE)
    val contentColor = if (isAccessGranted) Color(0xFF2E7D32) else Color(0xFFC62828)
    val icon = if (isAccessGranted) Icons.Default.CheckCircle else Icons.Default.Warning
    val message = if (isAccessGranted) {
        "Listening active — payment notifications are being tracked"
    } else {
        "Notification access required to track expenses"
    }

    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = containerColor)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.weight(1f)
            ) {
                Icon(imageVector = icon, contentDescription = null, tint = contentColor)
                Text(text = message, style = MaterialTheme.typography.bodyMedium, color = contentColor)
            }
            if (!isAccessGranted) {
                TextButton(onClick = onEnableClick) {
                    Text("Enable", color = contentColor)
                }
            }
        }
    }
}
