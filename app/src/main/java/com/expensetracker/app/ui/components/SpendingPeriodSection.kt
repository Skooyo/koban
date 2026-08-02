package com.expensetracker.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.PeriodSummary
import java.math.BigDecimal

@Composable
fun SpendingPeriodSection(
    summary: PeriodSummary,
    categoryNames: Map<String, String>,
    onViewAll: () -> Unit,
    modifier: Modifier = Modifier,
    highlight: Boolean = false
) {
    val containerColor = if (highlight) {
        MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f)
    } else {
        MaterialTheme.colorScheme.surfaceContainerLow
    }

    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = containerColor),
        elevation = CardDefaults.cardElevation(defaultElevation = if (highlight) 4.dp else 1.dp)
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = summary.title,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = summary.subtitle,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            NetSpendingTotal(total = summary.total, large = highlight)

            if (summary.breakdown.isNotEmpty()) {
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                CategoryBreakdownList(breakdown = summary.breakdown)
            }

            if (summary.recentExpenses.isNotEmpty()) {
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                Text(
                    text = "Recent",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold
                )
                summary.recentExpenses.forEach { expense ->
                    val categoryName = expense.categoryId?.let { categoryNames[it] }
                        ?: DefaultCategories.UNCATEGORIZED_NAME
                    ExpenseItem(
                        expense = expense,
                        categoryName = categoryName,
                        compact = true
                    )
                }
                TextButton(
                    onClick = onViewAll,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("View all expenses")
                }
            } else if (summary.total == BigDecimal.ZERO) {
                Text(
                    text = "No transactions yet",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            } else {
                TextButton(
                    onClick = onViewAll,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("View all expenses")
                }
            }
        }
    }
}

@Composable
fun NetSpendingTotal(
    total: BigDecimal,
    modifier: Modifier = Modifier,
    large: Boolean = false
) {
    val isCredit = total < BigDecimal.ZERO
    val displayAmount = if (isCredit) total.abs() else total
    val prefix = if (isCredit) "− MYR " else "MYR "
    val color = if (isCredit) androidx.compose.ui.graphics.Color(0xFF66BB6A) else MaterialTheme.colorScheme.primary

    Column(modifier = modifier) {
        Text(
            text = if (isCredit) "Net (after received)" else "Net spending",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = "$prefix${AmountFormatter.formatDisplay(displayAmount)}",
            style = if (large) MaterialTheme.typography.displaySmall else MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = color
        )
    }
}
