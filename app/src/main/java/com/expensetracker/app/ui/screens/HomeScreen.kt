package com.expensetracker.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.filled.Settings
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.PeriodSummary
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.ui.components.CategoryDot
import com.expensetracker.app.ui.components.ExpenseListCard
import com.expensetracker.app.ui.components.KobanRow
import com.expensetracker.app.ui.components.LargeTopBar
import com.expensetracker.app.ui.components.ListGroup
import com.expensetracker.app.ui.components.ListenerStatusBanner
import com.expensetracker.app.ui.components.Mon
import com.expensetracker.app.ui.components.MonFace
import com.expensetracker.app.ui.components.MoneyText
import com.expensetracker.app.ui.components.NoteStrip
import com.expensetracker.app.ui.components.SectionHeading
import com.expensetracker.app.ui.components.TonalButton
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.theme.categoryColor
import com.expensetracker.app.ui.viewmodel.HomeViewModel
import java.math.BigDecimal
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.launch

private fun rm(amount: BigDecimal) = "${AmountFormatter.currencySymbol("MYR")} ${AmountFormatter.formatGrouped(amount)}"

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

    // The period start changes at midnight, so the date moves on with it.
    val dateText = remember(uiState.today.periodStart) {
        SimpleDateFormat("EEE, d MMM", Locale.getDefault()).format(Date())
    }

    Box(modifier = modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize()) {
            LargeTopBar(
                title = "Today",
                subtitle = dateText,
                actions = {
                    IconButton(onClick = onOpenSettings, modifier = Modifier.size(48.dp)) {
                        Icon(Icons.Default.Settings, contentDescription = "Settings")
                    }
                }
            )
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 112.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                item {
                    ListenerStatusBanner(
                        isAccessGranted = uiState.isAccessGranted,
                        onEnableClick = viewModel::openNotificationSettings
                    )
                }

                if (listensToNoApp) {
                    item {
                        ListGroup {
                            item {
                                KobanRow(
                                    title = "Koban listens to no app. Choose your payment apps.",
                                    showChevron = true,
                                    onClick = onChoosePaymentApps
                                )
                            }
                        }
                    }
                }

                if (waitingCount > 0) {
                    item {
                        ListGroup {
                            item {
                                KobanRow(
                                    title = if (waitingCount == 1) "1 payment to check" else "$waitingCount payments to check",
                                    leading = {
                                        Icon(
                                            Icons.Default.Receipt,
                                            contentDescription = null,
                                            tint = LocalMoneyColors.current.goldText
                                        )
                                    },
                                    showChevron = true,
                                    onClick = onCheckPayments
                                )
                            }
                        }
                    }
                }

                if (uiState.isAccessGranted && !uiState.hasAnyPayment && waitingCount == 0 && !listensToNoApp) {
                    item {
                        FirstPaymentCard(onAddPayment = onAddPayment, onOpenSettings = onOpenSettings)
                    }
                }

                item {
                    SpentTodayCard(summary = uiState.today, onOpen = { openActivity(withWeek = true) })
                }

                item {
                    ListGroup {
                        listOf(uiState.week to true, uiState.month to false).forEach { (summary, withWeek) ->
                            item { PeriodRow(summary, onClick = { openActivity(withWeek) }) }
                        }
                    }
                }

                if (uiState.week.recentExpenses.isNotEmpty()) {
                    item {
                        SectionHeading("Latest this week", Modifier.padding(top = 12.dp))
                    }
                    item {
                        ListGroup {
                            uiState.week.recentExpenses.forEach { expense ->
                                item {
                                    ExpenseListCard(
                                        expense = expense,
                                        categoryName = expense.categoryId?.let { uiState.categoryNames[it] }
                                            ?: DefaultCategories.UNCATEGORIZED_NAME,
                                        timePattern = "EEE HH:mm",
                                        onEdit = { onEditPayment(expense.id) }
                                    )
                                }
                            }
                        }
                    }
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

/** Today's total, the money received, and the split by category. Tap opens the Activity tab. */
@Composable
private fun SpentTodayCard(summary: PeriodSummary, onOpen: () -> Unit) {
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceContainer)
            .clickable(onClickLabel = "Open Activity", onClick = onOpen)
            .padding(20.dp)
    ) {
        Text("Spent today", style = MaterialTheme.typography.bodyMedium, color = muted)
        MoneyText(
            rm(summary.total),
            Modifier.padding(top = 8.dp),
            style = MaterialTheme.typography.displayLarge,
            color = MaterialTheme.colorScheme.onSurface
        )
        if (summary.received > BigDecimal.ZERO) {
            MoneyText(
                "+ ${rm(summary.received)} received",
                Modifier.padding(top = 4.dp),
                style = MaterialTheme.typography.bodyMedium,
                color = LocalMoneyColors.current.received
            )
        }
        if (summary.breakdown.isNotEmpty()) {
            NoteStrip(summary.breakdown, Modifier.padding(top = 16.dp), height = 8.dp)
            Column(Modifier.padding(top = 8.dp)) {
                summary.breakdown.forEach { item ->
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        CategoryDot(categoryColor(item.categoryId))
                        Text(
                            item.name,
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier
                                .weight(1f)
                                .padding(horizontal = 12.dp)
                        )
                        MoneyText(
                            rm(item.total),
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
            }
        }
    }
}

/** This week or this month: total on the right, money received under it. */
@Composable
private fun PeriodRow(summary: PeriodSummary, onClick: () -> Unit) {
    KobanRow(
        title = summary.title,
        subtitle = summary.subtitle,
        trailing = {
            Column(horizontalAlignment = Alignment.End) {
                MoneyText(
                    rm(summary.total),
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    color = MaterialTheme.colorScheme.onSurface
                )
                if (summary.received > BigDecimal.ZERO) {
                    MoneyText(
                        "+ ${rm(summary.received)}",
                        style = MaterialTheme.typography.bodySmall,
                        color = LocalMoneyColors.current.received
                    )
                }
            }
        },
        showChevron = true,
        onClick = onClick
    )
}

/** Empty Home after setup: Mon waits, plus one optional step for later. */
@Composable
private fun FirstPaymentCard(onAddPayment: () -> Unit, onOpenSettings: () -> Unit) {
    Column {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(MaterialTheme.colorScheme.surfaceContainer)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Mon(MonFace.IDLE, 56.dp)
            Spacer(Modifier.height(12.dp))
            Text(
                text = "Waiting for your first payment",
                style = MaterialTheme.typography.titleMedium,
                textAlign = TextAlign.Center
            )
            Text(
                text = "Pay for anything. It shows up here.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 4.dp, bottom = 16.dp)
            )
            TonalButton("Add one by hand", onAddPayment, Modifier.fillMaxWidth())
        }
        SectionHeading("Set up later", Modifier.padding(top = 24.dp))
        ListGroup {
            item {
                KobanRow(
                    title = "Online features",
                    subtitle = "Read receipts, join groups",
                    showChevron = true,
                    onClick = onOpenSettings
                )
            }
        }
    }
}
