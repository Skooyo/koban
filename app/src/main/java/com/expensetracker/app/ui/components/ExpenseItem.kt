package com.expensetracker.app.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.data.ParseConfidence
import com.expensetracker.app.data.TransactionType
import com.expensetracker.app.data.effectiveAmount
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.theme.categoryColor
import java.math.BigDecimal
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** One transaction. Tap the row to edit it when [showActions] is true. */
@Composable
fun ExpenseListCard(
    expense: ExpenseEntity,
    categoryName: String?,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
    showConfidence: Boolean = false,
    compact: Boolean = false,
    showActions: Boolean = true,
    timePattern: String = "HH:mm"
) {
    val time = remember(expense.notificationPostTime, timePattern) {
        SimpleDateFormat(timePattern, Locale.getDefault()).format(Date(expense.notificationPostTime))
    }
    val merchant = expense.merchant?.takeIf { it.isNotBlank() } ?: "Unknown merchant"
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    val counted = expense.countedAmount
    val isRepayment = expense.transactionType == TransactionType.RECEIVE && counted?.signum() == 0
    val partlyCounted = expense.transactionType == TransactionType.WITHDRAW &&
        counted != null && counted.compareTo(expense.amount) != 0
    val signedAmount = when {
        isRepayment -> expense.amount
        expense.transactionType == TransactionType.RECEIVE -> expense.amount.negate()
        else -> expense.effectiveAmount
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .then(if (showActions) Modifier.clickable(onClickLabel = "Edit", onClick = onEdit) else Modifier)
            .height(IntrinsicSize.Min)
            .padding(vertical = if (compact) 8.dp else 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            Modifier
                .width(4.dp)
                .fillMaxHeight()
                .clip(RoundedCornerShape(2.dp))
                .categoryFill(expense.categoryId, categoryColor(expense.categoryId))
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(start = 12.dp, end = 8.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = merchant,
                style = if (compact) MaterialTheme.typography.titleSmall else MaterialTheme.typography.titleMedium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = listOfNotNull(categoryName, time).joinToString(", "),
                style = MaterialTheme.typography.bodySmall,
                color = muted,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (isRepayment) {
                Text(text = "Repayment", style = MaterialTheme.typography.bodySmall, color = muted)
            } else if (partlyCounted) {
                Text(
                    text = "paid ${AmountFormatter.currencySymbol(expense.currency)} ${AmountFormatter.formatGrouped(expense.amount)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = muted
                )
            }
            expense.notes?.takeIf { it.isNotBlank() }?.let { notes ->
                Text(
                    text = notes,
                    style = MaterialTheme.typography.bodySmall,
                    color = muted,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
            if (showConfidence && expense.confidence != ParseConfidence.HIGH) {
                Text(
                    text = if (expense.confidence == ParseConfidence.LOW) "Check the amount" else "Check the merchant",
                    style = MaterialTheme.typography.labelMedium,
                    color = LocalMoneyColors.current.review
                )
            }
        }
        MoneyAmount(
            amount = signedAmount,
            currency = expense.currency,
            style = if (compact) MaterialTheme.typography.titleSmall else MaterialTheme.typography.titleMedium,
            color = if (isRepayment) muted else MaterialTheme.colorScheme.onSurface
        )
        if (showActions) {
            IconButton(onClick = onDelete) {
                Icon(Icons.Default.Delete, contentDescription = "Delete $merchant", tint = muted)
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
    compact: Boolean = false,
    timePattern: String = "HH:mm"
) {
    ExpenseListCard(
        expense = expense,
        categoryName = categoryName,
        onEdit = {},
        onDelete = {},
        modifier = modifier,
        showConfidence = showConfidence,
        compact = compact,
        showActions = false,
        timePattern = timePattern
    )
}

/** Transactions under one header per day. [expenses] must be sorted newest first. */
fun LazyListScope.expensesByDay(
    expenses: List<ExpenseEntity>,
    categoryName: (ExpenseEntity) -> String?,
    onEdit: (ExpenseEntity) -> Unit,
    onDelete: (ExpenseEntity) -> Unit
) {
    val dayKey = SimpleDateFormat("yyyyMMdd", Locale.US)
    expenses.groupBy { dayKey.format(Date(it.notificationPostTime)) }.forEach { (day, dayExpenses) ->
        item(key = "day-$day") {
            DayHeader(timeMs = dayExpenses.first().notificationPostTime, expenses = dayExpenses)
        }
        items(dayExpenses, key = { it.id }) { expense ->
            ExpenseListCard(
                expense = expense,
                categoryName = categoryName(expense),
                onEdit = { onEdit(expense) },
                onDelete = { onDelete(expense) },
                showConfidence = true
            )
        }
    }
}

@Composable
private fun DayHeader(timeMs: Long, expenses: List<ExpenseEntity>) {
    val spent = expenses.fold(BigDecimal.ZERO) { sum, e ->
        if (e.transactionType == TransactionType.RECEIVE) sum else sum + e.effectiveAmount
    }
    Column(modifier = Modifier.padding(top = 20.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 6.dp),
            verticalAlignment = Alignment.Bottom
        ) {
            Text(
                text = dayLabel(timeMs),
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.weight(1f)
            )
            MoneyAmount(
                amount = spent,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
    }
}

private fun dayLabel(timeMs: Long): String {
    val day = Calendar.getInstance().apply { timeInMillis = timeMs }
    val today = Calendar.getInstance()
    val yesterday = (today.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, -1) }
    fun Calendar.sameDayAs(other: Calendar) =
        get(Calendar.YEAR) == other.get(Calendar.YEAR) &&
            get(Calendar.DAY_OF_YEAR) == other.get(Calendar.DAY_OF_YEAR)
    return when {
        day.sameDayAs(today) -> "Today"
        day.sameDayAs(yesterday) -> "Yesterday"
        day.get(Calendar.YEAR) == today.get(Calendar.YEAR) ->
            SimpleDateFormat("EEEE, d MMM", Locale.getDefault()).format(day.time)
        else -> SimpleDateFormat("EEEE, d MMM yyyy", Locale.getDefault()).format(day.time)
    }
}
