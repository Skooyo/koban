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
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.PeriodSummary
import com.expensetracker.app.ui.components.ExpenseItem
import com.expensetracker.app.ui.components.ListenerStatusBanner
import com.expensetracker.app.ui.components.NoteStrip
import com.expensetracker.app.ui.components.PeriodHero
import com.expensetracker.app.ui.components.PeriodTotalRow
import com.expensetracker.app.ui.components.ReceivedNote
import com.expensetracker.app.ui.navigation.Routes
import com.expensetracker.app.ui.viewmodel.HomeViewModel

@Composable
fun HomeScreen(
    onNavigateToFiltered: (String) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: HomeViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val lifecycleOwner = LocalLifecycleOwner.current

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.refreshAccessStatus()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    fun open(summary: PeriodSummary) = onNavigateToFiltered(
        Routes.expensesFilter(summary.periodStart, summary.periodEnd, summary.title)
    )

    val divider = MaterialTheme.colorScheme.outlineVariant

    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp)
    ) {
        item {
            ListenerStatusBanner(
                isAccessGranted = uiState.isAccessGranted,
                onEnableClick = viewModel::openNotificationSettings,
                modifier = Modifier.padding(bottom = 16.dp)
            )
        }

        item {
            PeriodHero(summary = uiState.today, onOpen = { open(uiState.today) })
            HorizontalDivider(color = divider, modifier = Modifier.padding(top = 20.dp))
        }

        listOf(uiState.week, uiState.month).forEach { summary ->
            item {
                PeriodTotalRow(
                    title = summary.title,
                    subtitle = summary.subtitle,
                    total = summary.total,
                    onClick = { open(summary) }
                ) {
                    NoteStrip(breakdown = summary.breakdown, height = 6.dp)
                    ReceivedNote(received = summary.received)
                }
                HorizontalDivider(color = divider)
            }
        }

        if (uiState.week.recentExpenses.isNotEmpty()) {
            item {
                Text(
                    text = "Latest this week",
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(top = 28.dp, bottom = 4.dp)
                )
            }
            items(uiState.week.recentExpenses, key = { it.id }) { expense ->
                ExpenseItem(
                    expense = expense,
                    categoryName = expense.categoryId?.let { uiState.categoryNames[it] }
                        ?: DefaultCategories.UNCATEGORIZED_NAME,
                    compact = true,
                    timePattern = "EEE HH:mm"
                )
            }
        }
    }
}
