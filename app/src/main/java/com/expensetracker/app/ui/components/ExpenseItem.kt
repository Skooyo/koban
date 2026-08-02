package com.expensetracker.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.data.ParseConfidence
import com.expensetracker.app.data.TransactionType
import com.expensetracker.app.parser.AmountFormatter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun ExpenseListCard(
    expense: ExpenseEntity,
    categoryName: String?,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
    showConfidence: Boolean = false,
    compact: Boolean = false,
    showActions: Boolean = true
) {
    val dateFormat = SimpleDateFormat(
        if (compact) "HH:mm" else "dd MMM yyyy, HH:mm",
        Locale.getDefault()
    )
    val isReceive = expense.transactionType == TransactionType.RECEIVE
    val amountColor = if (isReceive) Color(0xFF66BB6A) else MaterialTheme.colorScheme.primary
    val amountPrefix = if (isReceive) "+ " else "− "
    val padding = if (compact) 10.dp else 14.dp

    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = padding, top = padding, bottom = padding),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(end = 4.dp)
            ) {
                Text(
                    text = expense.merchant?.takeIf { it.isNotBlank() } ?: "Unknown merchant",
                    style = if (compact) MaterialTheme.typography.titleSmall else MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = dateFormat.format(Date(expense.notificationPostTime)),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    TransactionTypeBadge(expense.transactionType)
                }
                categoryName?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.secondary
                    )
                }
                expense.notes?.let { notes ->
                    Text(
                        text = notes,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                if (showConfidence && expense.confidence != ParseConfidence.HIGH) {
                    Text(
                        text = "Needs review · ${expense.confidence.name.lowercase()} confidence",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.tertiary
                    )
                }
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = "$amountPrefix${expense.currency} ${AmountFormatter.formatDisplay(expense.amount)}",
                    style = if (compact) MaterialTheme.typography.titleSmall else MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = amountColor
                )
                Row {
                    if (showActions) {
                        IconButton(onClick = onEdit) {
                            Icon(Icons.Default.Edit, contentDescription = "Edit", tint = MaterialTheme.colorScheme.primary)
                        }
                        IconButton(onClick = onDelete) {
                            Icon(Icons.Default.Delete, contentDescription = "Delete", tint = MaterialTheme.colorScheme.error)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ExpenseItem(
    expense: ExpenseEntity,
    modifier: Modifier = Modifier,
    showConfidence: Boolean = false,
    categoryName: String? = null,
    compact: Boolean = false
) {
    ExpenseListCard(
        expense = expense,
        categoryName = categoryName,
        onEdit = {},
        onDelete = {},
        modifier = modifier,
        showConfidence = showConfidence,
        compact = compact,
        showActions = false
    )
}

@Composable
fun TransactionTypeBadge(type: TransactionType) {
    val (label, color) = when (type) {
        TransactionType.WITHDRAW -> "Withdraw" to Color(0xFFEF5350)
        TransactionType.RECEIVE -> "Receive" to Color(0xFF66BB6A)
    }
    Text(
        text = label,
        style = MaterialTheme.typography.labelSmall,
        color = color,
        fontWeight = FontWeight.SemiBold
    )
}
