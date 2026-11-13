package com.expensetracker.app.ui.components

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
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

/** One transaction as a row for a [ListGroup]. Tap the row to edit it. */
@Composable
fun ExpenseListCard(
    expense: ExpenseEntity,
    categoryName: String?,
    onEdit: () -> Unit,
    modifier: Modifier = Modifier,
    showConfidence: Boolean = false,
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
    val subtitle = listOfNotNull(
        listOfNotNull(time, categoryName).joinToString(" · "),
        if (isRepayment) "Repayment"
        else if (partlyCounted) "paid ${AmountFormatter.currencySymbol(expense.currency)} ${AmountFormatter.formatGrouped(expense.amount)}"
        else null,
        expense.notes?.takeIf { it.isNotBlank() }
    ).joinToString("\n")

    KobanRow(
        title = merchant,
        modifier = modifier,
        subtitle = subtitle,
        leading = { CategoryDot(categoryColor(expense.categoryId)) },
        trailing = {
            MoneyAmount(
                amount = signedAmount,
                currency = expense.currency,
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = if (isRepayment) muted else MaterialTheme.colorScheme.onSurface
            )
        },
        titleSuffix = if (showConfidence && expense.confidence != ParseConfidence.HIGH) {
            { CheckBadge() }
        } else null,
        onClick = onEdit
    )
}

/** Small "Check" tag for a payment whose amount or shop the parser was unsure about. */
@Composable
private fun CheckBadge() {
    val review = LocalMoneyColors.current.review
    Text(
        text = "Check",
        style = MaterialTheme.typography.labelSmall,
        color = review,
        maxLines = 1,
        modifier = Modifier
            .border(1.dp, review, RoundedCornerShape(8.dp))
            .padding(horizontal = 6.dp, vertical = 1.dp)
    )
}

/** Transactions under one heading per day, each day in one [ListGroup]. [expenses] must be sorted newest first. */
fun LazyListScope.expensesByDay(
    expenses: List<ExpenseEntity>,
    categoryName: (ExpenseEntity) -> String?,
    onEdit: (ExpenseEntity) -> Unit
) {
    val dayKey = SimpleDateFormat("yyyyMMdd", Locale.US)
    expenses.groupBy { dayKey.format(Date(it.notificationPostTime)) }.forEach { (day, dayExpenses) ->
        item(key = "day-$day") {
            Column(Modifier.padding(top = 20.dp)) {
                DayHeader(timeMs = dayExpenses.first().notificationPostTime, expenses = dayExpenses)
                ListGroup {
                    dayExpenses.forEach { expense ->
                        item {
                            ExpenseListCard(
                                expense = expense,
                                categoryName = categoryName(expense),
                                onEdit = { onEdit(expense) },
                                showConfidence = true
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DayHeader(timeMs: Long, expenses: List<ExpenseEntity>) {
    val spent = expenses.fold(BigDecimal.ZERO) { sum, e ->
        if (e.transactionType == TransactionType.RECEIVE) sum else sum + e.effectiveAmount
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp),
        verticalAlignment = Alignment.Bottom
    ) {
        SectionHeading(dayLabel(timeMs), Modifier.weight(1f).padding(bottom = 0.dp).semantics { heading() })
        MoneyAmount(
            amount = spent,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
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
            SimpleDateFormat("EEE, d MMM", Locale.getDefault()).format(day.time)
        else -> SimpleDateFormat("EEE, d MMM yyyy", Locale.getDefault()).format(day.time)
    }
}
