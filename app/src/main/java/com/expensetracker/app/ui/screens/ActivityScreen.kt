package com.expensetracker.app.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.data.MonthNav
import com.expensetracker.app.data.MonthSummary
import com.expensetracker.app.data.WeekSummary
import com.expensetracker.app.ui.components.CategoryDonut
import com.expensetracker.app.ui.components.CategoryFilterRow
import com.expensetracker.app.ui.components.MoneyAmount
import com.expensetracker.app.ui.components.NetSpendingTotal
import com.expensetracker.app.ui.components.PeriodTotalRow
import com.expensetracker.app.ui.components.RelativeBar
import com.expensetracker.app.ui.components.UNCATEGORIZED_FILTER
import com.expensetracker.app.ui.components.expensesByDay
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.viewmodel.ActivityViewModel
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.time.YearMonth
import java.util.Locale

@Composable
fun ActivityScreen(
    onAddPayment: () -> Unit,
    onEditPayment: (String) -> Unit,
    message: String?,
    onMessageShown: () -> Unit,
    viewModel: ActivityViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val categories by viewModel.categories.collectAsStateWithLifecycle()
    val sheetMonths by viewModel.sheetMonths.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var sheetOpen by rememberSaveable { mutableStateOf(false) }
    val monthLabel = MonthNav.label(uiState.month)

    // Clearing the message changes the key, so show it from a scope that outlives this effect.
    LaunchedEffect(message) {
        if (message != null) {
            scope.launch { snackbar.showSnackbar(message) }
            onMessageShown()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 96.dp)
        ) {
            item {
                Text(text = "Activity", style = MaterialTheme.typography.headlineMedium)
                MonthBar(
                    label = monthLabel,
                    canGoNext = uiState.canGoNext,
                    onPrevious = viewModel::previousMonth,
                    onNext = viewModel::nextMonth,
                    onPick = { sheetOpen = true },
                    modifier = Modifier.padding(top = 8.dp)
                )
                NetSpendingTotal(total = uiState.monthTotal, large = true, modifier = Modifier.padding(top = 8.dp))
                WeekStrip(
                    weeks = uiState.weeks,
                    selected = uiState.selectedWeek,
                    onToggle = viewModel::toggleWeek,
                    modifier = Modifier.padding(top = 16.dp)
                )
                CategoryDonut(
                    slices = uiState.slices,
                    onSelect = { viewModel.setCategoryFilter(it.categoryId ?: UNCATEGORIZED_FILTER) },
                    modifier = Modifier.padding(top = 12.dp),
                    compact = true
                )
                CategoryFilterRow(
                    categories = categories,
                    selected = uiState.categoryFilter,
                    onSelect = viewModel::setCategoryFilter,
                    modifier = Modifier.padding(top = 12.dp)
                )
            }
            if (uiState.expenses.isEmpty()) {
                item {
                    Text(
                        text = when {
                            uiState.categoryFilter != null -> "No payments in this category."
                            uiState.selectedWeek != null -> "No payments in this week."
                            else -> "No payments in $monthLabel."
                        },
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 24.dp)
                    )
                }
            } else {
                expensesByDay(
                    expenses = uiState.expenses,
                    categoryName = { viewModel.categoryNameFor(it, uiState.categoryNames) },
                    onEdit = { onEditPayment(it.id) }
                )
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

    if (sheetOpen) {
        MonthSheet(
            months = sheetMonths,
            onPick = viewModel::pickMonth,
            onDismiss = { sheetOpen = false }
        )
    }
}

/** Gold "＋ Add" button with dark ink text, as the payment page's bottom button. */
@Composable
internal fun AddPaymentFab(onClick: () -> Unit, modifier: Modifier = Modifier) {
    ExtendedFloatingActionButton(
        onClick = onClick,
        modifier = modifier,
        containerColor = LocalMoneyColors.current.gold,
        contentColor = Ink
    ) {
        Text("＋ Add", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun MonthBar(
    label: String,
    canGoNext: Boolean,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onPick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(modifier = modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onPrevious) {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, contentDescription = "Previous month")
        }
        TextButton(
            onClick = onPick,
            modifier = Modifier
                .weight(1f)
                .heightIn(min = 48.dp)
                .semantics { onClick(label = "Pick a month", action = null) }
        ) {
            Text(label, style = MaterialTheme.typography.titleMedium)
            Icon(Icons.Default.ArrowDropDown, contentDescription = null)
        }
        IconButton(onClick = onNext, enabled = canGoNext) {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = "Next month")
        }
    }
}

@Composable
private fun WeekStrip(
    weeks: List<WeekSummary>,
    selected: Long?,
    onToggle: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    val dayFormat = remember { SimpleDateFormat("d MMM", Locale.getDefault()) }
    val listState = rememberLazyListState()
    LaunchedEffect(selected, weeks) {
        val index = weeks.indexOfFirst { it.startMs == selected }
        if (index >= 0) listState.animateScrollToItem(index)
    }
    LazyRow(modifier = modifier, state = listState, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        items(weeks, key = { it.startMs }) { week ->
            val isSelected = week.startMs == selected
            Surface(
                selected = isSelected,
                onClick = { onToggle(week.startMs) },
                shape = RoundedCornerShape(12.dp),
                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                border = if (isSelected) {
                    BorderStroke(2.dp, LocalMoneyColors.current.gold)
                } else {
                    BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
                },
                modifier = Modifier.heightIn(min = 48.dp)
            ) {
                Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
                    Text(
                        text = "${dayFormat.format(week.startMs)} – ${dayFormat.format(week.endMs - 1)}",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    MoneyAmount(amount = week.total, style = MaterialTheme.typography.titleSmall)
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MonthSheet(
    months: List<MonthSummary>,
    onPick: (YearMonth) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val largest = months.maxOfOrNull { it.total }
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Text(
            text = "Pick a month",
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp)
        )
        LazyColumn(
            modifier = Modifier.navigationBarsPadding(),
            contentPadding = PaddingValues(horizontal = 24.dp)
        ) {
            items(months, key = { "${it.year}-${it.month}" }) { month ->
                val yearMonth = YearMonth.of(month.year, month.month + 1)
                PeriodTotalRow(
                    title = MonthNav.label(yearMonth),
                    subtitle = null,
                    total = month.total,
                    onClick = {
                        onPick(yearMonth)
                        scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() }
                    }
                ) {
                    RelativeBar(total = month.total, max = largest)
                }
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            }
        }
    }
}
