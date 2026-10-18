package com.expensetracker.app.ui.screens

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.ui.components.NetSpendingTotal
import com.expensetracker.app.ui.components.PeriodTotalRow
import com.expensetracker.app.ui.components.RelativeBar
import com.expensetracker.app.ui.viewmodel.HistoryWeeksViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HistoryWeeksScreen(
    onBack: () -> Unit,
    onWeekClick: (Long, Long, String) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: HistoryWeeksViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val largest = uiState.weeks.maxOfOrNull { it.total }

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = { Text(uiState.monthLabel) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 16.dp)
        ) {
            item {
                NetSpendingTotal(total = uiState.monthTotal, large = true)
                Text(
                    text = "Weeks, Monday to Sunday",
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(top = 28.dp, bottom = 4.dp)
                )
            }
            if (uiState.weeks.isEmpty()) {
                item {
                    Text(
                        text = "No transactions this month.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                items(uiState.weeks, key = { it.startMs }) { week ->
                    PeriodTotalRow(
                        title = week.label,
                        subtitle = null,
                        total = week.total,
                        onClick = { onWeekClick(week.startMs, week.endMs, week.label) }
                    ) {
                        RelativeBar(total = week.total, max = largest)
                    }
                    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                }
            }
        }
    }
}
