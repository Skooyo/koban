package com.expensetracker.app.ui.screens

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.data.PeriodCalculator
import com.expensetracker.app.ui.components.PeriodTotalRow
import com.expensetracker.app.ui.components.RelativeBar
import com.expensetracker.app.ui.viewmodel.HistoryMonthsViewModel

@Composable
fun HistoryMonthsScreen(
    onMonthClick: (Int) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: HistoryMonthsViewModel = hiltViewModel()
) {
    val months by viewModel.months.collectAsStateWithLifecycle()
    val largest = months.maxOfOrNull { it.total }

    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp)
    ) {
        item {
            Text(
                text = "Spending by month",
                style = MaterialTheme.typography.headlineMedium
            )
            Text(
                text = "Tap a month to see its weeks.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 4.dp, bottom = 8.dp)
            )
        }
        if (months.isEmpty()) {
            item {
                Text(
                    text = "No spending recorded yet.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 16.dp)
                )
            }
        } else {
            items(months, key = { "${it.year}-${it.month}" }) { month ->
                PeriodTotalRow(
                    title = month.label,
                    subtitle = null,
                    total = month.total,
                    onClick = { onMonthClick(PeriodCalculator.encodeYearMonth(month.year, month.month)) }
                ) {
                    RelativeBar(total = month.total, max = largest)
                }
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            }
        }
    }
}
