package com.expensetracker.app.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
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
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Snackbar
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
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.ui.components.CategoryDonut
import com.expensetracker.app.ui.components.CategoryDot
import com.expensetracker.app.ui.components.DonutSlice
import com.expensetracker.app.ui.components.LargeTopBar
import com.expensetracker.app.ui.components.ListGroup
import com.expensetracker.app.ui.components.MoneyAmount
import com.expensetracker.app.ui.components.MoneyText
import com.expensetracker.app.ui.components.ReceivedNote
import com.expensetracker.app.ui.components.RelativeBar
import com.expensetracker.app.ui.components.SegmentedControl
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
        Column(Modifier.fillMaxSize()) {
            LargeTopBar(
                title = "Activity",
                actions = { FilterButton(onOpen = { filterSheetOpen = true }) }
            )
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 112.dp)
            ) {
                item {
                    Column {
                        SegmentedControl(
                            labels = listOf("Month", "All"),
                            selectedIndex = if (uiState.showAll) 1 else 0,
                            onPick = { viewModel.setShowAll(it == 1) }
                        )
                        uiState.categoryFilter?.let { filter ->
                            FilterChip(
                                name = uiState.categoryNames[filter] ?: DefaultCategories.UNCATEGORIZED_NAME,
                                total = uiState.monthTotal.takeIf { !uiState.showAll },
                                period = if (uiState.selectedWeek != null) "this week" else "this month",
                                onClear = { viewModel.setCategoryFilter(null) },
                                modifier = Modifier.padding(top = 12.dp)
                            )
                        }
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
                            ChartCard(
                                slices = uiState.slices,
                                label = if (selectedLabel != null) "Spent, $selectedLabel" else "Spent",
                                total = uiState.monthTotal,
                                received = uiState.monthReceived,
                                onRingClick = { filterSheetOpen = true },
                                modifier = Modifier.padding(top = 8.dp)
                            )
                            WeekStrip(
                                weeks = uiState.weeks,
                                selected = uiState.selectedWeek,
                                onToggle = viewModel::toggleWeek,
                                modifier = Modifier.padding(top = 12.dp)
                            )
                        }
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
        ) { data ->
            Snackbar(data, modifier = Modifier.padding(horizontal = 16.dp), shape = RoundedCornerShape(16.dp))
        }
    }

    if (sheetOpen) {
        MonthSheet(
            months = sheetMonths,
            current = uiState.month,
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

private fun rm(amount: BigDecimal) = "${AmountFormatter.currencySymbol("MYR")} ${AmountFormatter.formatGrouped(amount)}"

/** Outlined "Filter" button; opens the category sheet. */
@Composable
private fun FilterButton(onOpen: () -> Unit) {
    Surface(
        onClick = onOpen,
        shape = CircleShape,
        color = Color.Transparent,
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
}

/** The category now shown: a gold-soft chip that clears the filter, and what was spent in it. */
@Composable
private fun FilterChip(name: String, total: BigDecimal?, period: String, onClear: () -> Unit, modifier: Modifier = Modifier) {
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Surface(
            onClick = onClear,
            shape = RoundedCornerShape(12.dp),
            color = MaterialTheme.colorScheme.primaryContainer,
            modifier = Modifier
                .heightIn(min = 48.dp)
                .widthIn(max = 200.dp)
                .semantics { contentDescription = "Filtered by $name. Clear filter" }
        ) {
            Row(Modifier.padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(18.dp))
                Text(
                    text = name,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(start = 8.dp)
                )
            }
        }
        if (total != null) {
            Row(Modifier.weight(1f, fill = false)) {
                MoneyAmount(amount = total, style = MaterialTheme.typography.bodyMedium, color = muted)
                Text(" $period", style = MaterialTheme.typography.bodyMedium, color = muted, maxLines = 1)
            }
        }
    }
}

/** Ring, "Spent" and the big total, and the money received, in one card. */
@Composable
private fun ChartCard(
    slices: List<DonutSlice>,
    label: String,
    total: BigDecimal,
    received: BigDecimal,
    onRingClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceContainer)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        CategoryDonut(slices = slices, onClick = onRingClick)
        Column(Modifier.weight(1f)) {
            Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            MoneyText(
                rm(total),
                Modifier.padding(top = 4.dp),
                style = MaterialTheme.typography.displayMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
            if (received > BigDecimal.ZERO) {
                MoneyText(
                    "+ ${rm(received)} received",
                    Modifier.padding(top = 4.dp),
                    style = MaterialTheme.typography.bodyMedium,
                    color = LocalMoneyColors.current.received
                )
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
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 16.dp)
        ) {
            item {
                ListGroup {
                    item { FilterOptionRow(null, "All categories", totals.total, selected == null) { pick(null) } }
                    options.forEach { (id, name) ->
                        item { FilterOptionRow(categoryColor(filterColorId(id)), name, spent[id], selected == id) { pick(id) } }
                    }
                }
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
            .selectable(selected = selected, role = Role.RadioButton, onClick = onClick)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(Modifier.size(24.dp), contentAlignment = Alignment.Center) {
            if (dot != null) CategoryDot(dot)
            else Icon(Icons.AutoMirrored.Filled.List, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
        }
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
            if (selected) Icon(Icons.Default.Check, contentDescription = null, tint = LocalMoneyColors.current.goldText)
        }
    }
}

/** The one gold action of Home and Activity: add icon and "Add payment". */
@Composable
internal fun AddPaymentFab(onClick: () -> Unit, modifier: Modifier = Modifier) {
    ExtendedFloatingActionButton(
        onClick = onClick,
        modifier = modifier,
        icon = { Icon(Icons.Default.Add, contentDescription = null) },
        text = { Text("Add payment", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold) },
        containerColor = MaterialTheme.colorScheme.primary,
        contentColor = MaterialTheme.colorScheme.onPrimary
    )
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
        if (index >= 0) listState.animateScrollToItem(index + 1)
    }
    LazyRow(modifier = modifier, state = listState, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        item(key = "whole-month") {
            PeriodChip(selected == null, onClick = { selected?.let(onToggle) }) {
                Text("Whole month", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
            }
        }
        items(weeks, key = { it.startMs }) { week ->
            val isSelected = week.startMs == selected
            PeriodChip(isSelected, onClick = { onToggle(week.startMs) }) {
                Column {
                    Text(
                        text = weekLabel(week, dayFormat),
                        style = MaterialTheme.typography.labelMedium,
                        color = if (isSelected) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    MoneyAmount(
                        amount = week.total,
                        style = MaterialTheme.typography.titleSmall,
                        color = if (isSelected) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurface
                    )
                }
            }
        }
    }
}

/** Chip of the week strip: gold-soft with a check when chosen, outlined when not. */
@Composable
private fun PeriodChip(selected: Boolean, onClick: () -> Unit, content: @Composable () -> Unit) {
    Surface(
        selected = selected,
        onClick = onClick,
        shape = RoundedCornerShape(12.dp),
        color = if (selected) MaterialTheme.colorScheme.primaryContainer else Color.Transparent,
        contentColor = if (selected) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurface,
        border = if (selected) null else BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
        modifier = Modifier.heightIn(min = 48.dp)
    ) {
        Row(Modifier.padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            if (selected) Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.padding(end = 8.dp).size(18.dp))
            content()
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MonthSheet(
    months: List<MonthSummary>,
    current: YearMonth,
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
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 16.dp)
        ) {
            item {
                ListGroup {
                    months.forEach { month ->
                        val yearMonth = YearMonth.of(month.year, month.month + 1)
                        val isCurrent = yearMonth == current
                        item {
                            Column(
                                Modifier
                                    .fillMaxWidth()
                                    .selectable(selected = isCurrent, role = Role.RadioButton) {
                                        onPick(yearMonth)
                                        scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() }
                                    }
                                    .heightIn(min = 56.dp)
                                    .padding(horizontal = 16.dp, vertical = 12.dp)
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = MonthNav.label(yearMonth),
                                        style = MaterialTheme.typography.titleMedium,
                                        color = if (isCurrent) LocalMoneyColors.current.goldText else MaterialTheme.colorScheme.onSurface,
                                        modifier = Modifier.weight(1f)
                                    )
                                    MoneyAmount(amount = month.total, style = MaterialTheme.typography.bodyLarge)
                                }
                                RelativeBar(
                                    total = month.total,
                                    max = largest,
                                    modifier = Modifier.padding(top = 8.dp),
                                    color = if (isCurrent) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
