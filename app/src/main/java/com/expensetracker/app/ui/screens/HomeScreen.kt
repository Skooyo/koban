package com.expensetracker.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.ui.components.ExpenseListCard
import com.expensetracker.app.ui.components.ListenerStatusBanner
import com.expensetracker.app.ui.components.NoteStrip
import com.expensetracker.app.ui.components.PeriodHero
import com.expensetracker.app.ui.components.PeriodTotalRow
import com.expensetracker.app.ui.components.ReceivedNote
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.viewmodel.HomeViewModel
import kotlinx.coroutines.launch

@Composable
fun HomeScreen(
    onOpenActivity: () -> Unit,
    onAddPayment: () -> Unit,
    onEditPayment: (String) -> Unit,
    onOpenSettings: () -> Unit,
    onCheckPayments: () -> Unit,
    onChoosePaymentApps: () -> Unit,
    message: String?,
    onMessageShown: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: HomeViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val waitingCount by viewModel.waitingCount.collectAsStateWithLifecycle()
    val listensToNoApp by viewModel.listensToNoApp.collectAsStateWithLifecycle()
    val lifecycleOwner = LocalLifecycleOwner.current
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    // Clearing the message changes the key, so show it from a scope that outlives this effect.
    LaunchedEffect(message) {
        if (message != null) {
            scope.launch { snackbar.showSnackbar(message) }
            onMessageShown()
        }
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.refreshAccessStatus()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    fun openActivity(withWeek: Boolean) {
        viewModel.selectActivity(withWeek)
        onOpenActivity()
    }

    val divider = MaterialTheme.colorScheme.outlineVariant

    Box(modifier = modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 112.dp)
        ) {
            item {
                Row(
                    modifier = Modifier.padding(bottom = 16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    ListenerStatusBanner(
                        isAccessGranted = uiState.isAccessGranted,
                        onEnableClick = viewModel::openNotificationSettings,
                        modifier = Modifier.weight(1f)
                    )
                    IconButton(onClick = onOpenSettings, modifier = Modifier.size(48.dp)) {
                        Icon(Icons.Default.Settings, contentDescription = "Settings")
                    }
                }
            }

            if (listensToNoApp) {
                item {
                    NoAppsBanner(onClick = onChoosePaymentApps)
                }
            }

            if (waitingCount > 0) {
                item {
                    WaitingBanner(count = waitingCount, onClick = onCheckPayments)
                }
            }

            item {
                PeriodHero(summary = uiState.today, onOpen = { openActivity(withWeek = true) })
                HorizontalDivider(color = divider, modifier = Modifier.padding(top = 20.dp))
            }

            listOf(uiState.week to true, uiState.month to false).forEach { (summary, withWeek) ->
                item {
                    PeriodTotalRow(
                        title = summary.title,
                        subtitle = summary.subtitle,
                        total = summary.total,
                        onClick = { openActivity(withWeek) }
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
                    ExpenseListCard(
                        expense = expense,
                        categoryName = expense.categoryId?.let { uiState.categoryNames[it] }
                            ?: DefaultCategories.UNCATEGORIZED_NAME,
                        compact = true,
                        timePattern = "EEE HH:mm",
                        onEdit = { onEditPayment(expense.id) }
                    )
                }
            }
        }
        AddPaymentFab(
            onClick = onAddPayment,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(16.dp)
        )
        SnackbarHost(
            snackbar,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 80.dp)
        )
    }
}

/** Shown when the user saved zero payment apps. Opens the picker. */
@Composable
private fun NoAppsBanner(onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .padding(bottom = 16.dp)
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "Koban listens to no app. Choose your payment apps.",
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.weight(1f)
        )
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null)
    }
}

/** "3 payments to check", gold-tinted, above Today. Opens the swipe screen. */
@Composable
private fun WaitingBanner(count: Int, onClick: () -> Unit) {
    val money = LocalMoneyColors.current
    Row(
        modifier = Modifier
            .padding(bottom = 16.dp)
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(money.gold.copy(alpha = 0.18f))
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = if (count == 1) "1 payment to check" else "$count payments to check",
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.SemiBold,
            color = money.goldText,
            modifier = Modifier.weight(1f)
        )
        Icon(
            Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = money.goldText
        )
    }
}
