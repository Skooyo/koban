package com.expensetracker.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.data.SpendingPeriod
import com.expensetracker.app.ui.components.ListenerStatusBanner
import com.expensetracker.app.ui.components.SpendingPeriodSection
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

    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        item {
            ListenerStatusBanner(
                isAccessGranted = uiState.isAccessGranted,
                onEnableClick = viewModel::openNotificationSettings
            )
        }

        item {
            SpendingPeriodSection(
                summary = uiState.today,
                categoryNames = uiState.categoryNames,
                highlight = true,
                onViewAll = {
                    onNavigateToFiltered(
                        Routes.expensesFilter(
                            uiState.today.periodStart,
                            uiState.today.periodEnd,
                            "Today"
                        )
                    )
                }
            )
        }

        item {
            Text(
                text = "Scroll for weekly & monthly",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.fillMaxWidth()
            )
        }

        item {
            SpendingPeriodSection(
                summary = uiState.week,
                categoryNames = uiState.categoryNames,
                onViewAll = {
                    onNavigateToFiltered(
                        Routes.expensesFilter(
                            uiState.week.periodStart,
                            uiState.week.periodEnd,
                            "This week"
                        )
                    )
                }
            )
        }

        item {
            SpendingPeriodSection(
                summary = uiState.month,
                categoryNames = uiState.categoryNames,
                onViewAll = {
                    onNavigateToFiltered(
                        Routes.expensesFilter(
                            uiState.month.periodStart,
                            uiState.month.periodEnd,
                            "This month"
                        )
                    )
                }
            )
        }
    }
}
