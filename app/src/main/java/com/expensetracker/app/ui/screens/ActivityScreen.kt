package com.expensetracker.app.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.FilterList
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.MonthNav
import com.expensetracker.app.data.MonthSummary
import com.expensetracker.app.data.WeekSummary
import com.expensetracker.app.ui.components.CategoryDonut
import com.expensetracker.app.ui.components.MoneyAmount
import com.expensetracker.app.ui.components.NetSpendingTotal
import com.expensetracker.app.ui.components.PeriodTotalRow
import com.expensetracker.app.ui.components.ReceivedNote
import com.expensetracker.app.ui.components.RelativeBar
import com.expensetracker.app.ui.components.UNCATEGORIZED_FILTER
import com.expensetracker.app.ui.components.expensesByDay
import com.expensetracker.app.ui.theme.LocalMoneyColors
import com.expensetracker.app.ui.theme.categoryColor
import com.expensetracker.app.ui.viewmodel.ActivityMonthGroup
import com.expensetracker.app.ui.viewmodel.ActivityViewModel
import com.expensetracker.app.ui.viewmodel.FilterTotals
import kotlinx.coroutines.launch
import java.math.BigDecimal
import java.text.SimpleDateFormat
import java.time.YearMonth
import java.util.Locale

@OptIn(ExperimentalFoundationApi::class)
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
    val allMonths by viewModel.allMonths.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var sheetOpen by rememberSaveable { mutableStateOf(false) }
    var filterSheetOpen by rememberSaveable { mutableStateOf(false) }
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
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "Activity",
                        style = MaterialTheme.typography.headlineMedium,
                        modifier = Modifier.weight(1f)
                    )
                    FilterButton(
                        filter = uiState.categoryFilter,
                        names = uiState.categoryNames,
                        onOpen = { filterSheetOpen = true },
                        onClear = { viewModel.setCategoryFilter(null) }
                    )
                }
                ViewSwitch(
                    showAll = uiState.showAll,
                    onShowAll = viewModel::setShowAll,
                    modifier = Modifier.padding(top = 8.dp)
                )
                if (!uiState.showAll) {
                    MonthBar(
                        label = monthLabel,
                        canGoNext = uiState.canGoNext,
                        onPrevious = viewModel::previousMonth,
                        onNext = viewModel::nextMonth,
                        onPick = { sheetOpen = true },
                        modifier = Modifier.padding(top = 8.dp)
                    )
                    val dayFormat = remember { SimpleDateFormat("d MMM", Locale.getDefault()) }
                    val selectedLabel = uiState.weeks.firstOrNull { it.startMs == uiState.selectedWeek }?.let { weekLabel(it, dayFormat) }
                    NetSpendingTotal(
                        total = uiState.monthTotal,
                        large = true,
                        label = if (selectedLabel != null) "Spent, $selectedLabel" else "Spent",
                        modifier = Modifier.padding(top = 8.dp)
                    )
                    ReceivedNote(received = uiState.monthReceived)
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
                }
            }
            if (uiState.showAll) {
                val groups = allMonths
                if (groups != null && groups.isEmpty()) {
                    item {
                        EmptyText(if (uiState.categoryFilter != null) "No payments in this category." else "No payments yet.")
                    }
                }
                groups?.forEach { group ->
                    stickyHeader(key = "month-${group.month}") { MonthHeader(group) }
                    expensesByDay(
                        expenses = group.expenses,
                        categoryName = { viewModel.categoryNameFor(it, uiState.categoryNames) },
                        onEdit = { onEditPayment(it.id) }
                    )
                }
            } else if (uiState.expenses.isEmpty()) {
                item {
                    EmptyText(
                        when {
                            uiState.categoryFilter != null -> "No payments in this category."
                            uiState.selectedWeek != null -> "No payments in this week."
                            else -> "No payments in $monthLabel."
                        }
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
    if (filterSheetOpen) {
        val filterTotals by viewModel.filterTotals.collectAsStateWithLifecycle()
        CategoryFilterSheet(
            categories = categories,
            totals = filterTotals,
            selected = uiState.categoryFilter,
            onPick = viewModel::setCategoryFilter,
            onDismiss = { filterSheetOpen = false }
        )
    }
}

private fun filterColorId(filter: String): String? = if (filter == UNCATEGORIZED_FILTER) null else filter

/** "Filter" pill; with a filter on, the category's dot and name (opens the sheet) and a ✕ that clears it. */
@Composable
private fun FilterButton(
    filter: String?,
    names: Map<String, String>,
    onOpen: () -> Unit,
    onClear: () -> Unit
) {
    if (filter == null) {
        Surface(
            onClick = onOpen,
            shape = CircleShape,
            color = MaterialTheme.colorScheme.surfaceContainerHigh,
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
            modifier = Modifier
                .heightIn(min = 48.dp)
                .semantics { contentDescription = "Filter by category" }
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Default.FilterList, contentDescription = null, modifier = Modifier.size(18.dp))
                Text("Filter", style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(start = 6.dp))
            }
        }
        return
    }
    val name = names[filter] ?: DefaultCategories.UNCATEGORIZED_NAME
    val color = categoryColor(filterColorId(filter))
    Surface(
        shape = CircleShape,
        color = MaterialTheme.colorScheme.surfaceContainerHigh,
        border = BorderStroke(2.dp, color)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Row(
                modifier = Modifier
                    .heightIn(min = 48.dp)
                    .widthIn(max = 200.dp)
                    .clickable(role = Role.Button, onClickLabel = "Pick a category", onClick = onOpen)
                    .padding(start = 14.dp, end = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(Modifier.size(10.dp).clip(CircleShape).background(color))
                Text(
                    text = name,
                    style = MaterialTheme.typography.labelLarge,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(start = 8.dp)
                )
            }
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clickable(role = Role.Button, onClick = onClear)
                    .semantics { contentDescription = "Filtered by $name. Clear filter" },
                contentAlignment = Alignment.Center
            ) {
                Text("✕", style = MaterialTheme.typography.labelLarge)
            }
        }
    }
}

/** Sheet to pick one category; each row shows what was spent in it over the shown range. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CategoryFilterSheet(
    categories: List<CategoryEntity>,
    totals: FilterTotals,
    selected: String?,
    onPick: (String?) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val spent = totals.breakdown.associate { (it.categoryId ?: UNCATEGORIZED_FILTER) to it.total }
    // No spending (null) sorts last; the sort is stable, so ties keep the category order.
    val options = (categories.map { it.id to it.name } + (UNCATEGORIZED_FILTER to DefaultCategories.UNCATEGORIZED_NAME))
        .sortedByDescending { spent[it.first] }
    val pick: (String?) -> Unit = { id ->
        onPick(id)
        scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() }
    }
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Text(
            text = "Show one category",
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp)
        )
        LazyColumn(
            modifier = Modifier
                .navigationBarsPadding()
                .selectableGroup(),
            contentPadding = PaddingValues(horizontal = 24.dp)
        ) {
            item(key = "all") {
                FilterOptionRow(null, "All categories", totals.total, selected == null) { pick(null) }
            }
            items(options, key = { it.first }) { (id, name) ->
                FilterOptionRow(categoryColor(filterColorId(id)), name, spent[id], selected == id) { pick(id) }
            }
        }
    }
}

@Composable
private fun FilterOptionRow(dot: Color?, name: String, total: BigDecimal?, selected: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .selectable(selected = selected, role = Role.RadioButton, onClick = onClick),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(dot ?: Color.Transparent)
        )
        Text(
            text = name,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = if (selected) FontWeight.Bold else null,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier
                .weight(1f)
                .padding(start = 12.dp, end = 8.dp)
        )
        if (total != null) {
            MoneyAmount(amount = total, style = MaterialTheme.typography.bodyLarge)
        } else {
            Text(
                text = "—",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.semantics { contentDescription = "No spending" }
            )
        }
        Box(modifier = Modifier.padding(start = 8.dp).size(24.dp), contentAlignment = Alignment.Center) {
            if (selected) Icon(Icons.Default.Check, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
        }
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
private fun EmptyText(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodyLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(top = 24.dp)
    )
}

/** "Month" | "All" pill switch, styled as the payment page's Expense/Income switch. */
@Composable
private fun ViewSwitch(showAll: Boolean, onShowAll: (Boolean) -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .padding(4.dp)
            .selectableGroup()
    ) {
        TypeSegment("Month", !showAll, MaterialTheme.colorScheme.inverseSurface) { onShowAll(false) }
        TypeSegment("All", showAll, MaterialTheme.colorScheme.inverseSurface) { onShowAll(true) }
    }
}

/** Sticky month header of the All view: month name and that month's spent total. */
@Composable
private fun MonthHeader(group: ActivityMonthGroup) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.background)
            .padding(top = 20.dp, bottom = 4.dp)
            .semantics(mergeDescendants = true) { heading() }
    ) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = MonthNav.label(group.month),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f)
            )
            MoneyAmount(amount = group.total, style = MaterialTheme.typography.titleMedium)
        }
        ReceivedNote(received = group.received)
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

private fun weekLabel(week: WeekSummary, dayFormat: SimpleDateFormat) =
    "${dayFormat.format(week.startMs)} – ${dayFormat.format(week.endMs - 1)}"

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
                        text = weekLabel(week, dayFormat),
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
