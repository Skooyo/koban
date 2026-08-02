package com.expensetracker.app.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.data.MonthSummary
import com.expensetracker.app.data.PeriodCalculator
import com.expensetracker.app.ui.viewmodel.HistoryMonthsViewModel
import java.math.BigDecimal

@Composable
fun HistoryMonthsScreen(
    onMonthClick: (Int) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: HistoryMonthsViewModel = hiltViewModel()
) {
    val months by viewModel.months.collectAsStateWithLifecycle()

    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        item {
            Text(
                text = "Spending by month",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = "Tap a month to see weekly breakdown",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 8.dp)
            )
        }
        if (months.isEmpty()) {
            item {
                Text(
                    text = "No spending recorded yet.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            items(months, key = { "${it.year}-${it.month}" }) { month ->
                MonthSummaryCard(month = month, onClick = {
                    onMonthClick(PeriodCalculator.encodeYearMonth(month.year, month.month))
                })
            }
        }
    }
}

@Composable
private fun MonthSummaryCard(month: MonthSummary, onClick: () -> Unit) {
    val isCredit = month.total < BigDecimal.ZERO
    val display = if (isCredit) month.total.abs() else month.total
    val prefix = if (isCredit) "− MYR " else "MYR "

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = month.label,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text = "$prefix${AmountFormatter.formatDisplay(display)}",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}
