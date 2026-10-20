package com.expensetracker.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.ActivitySelection
import com.expensetracker.app.data.CategoryBreakdown
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.CategoryRepository
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.data.ExpenseRepository
import com.expensetracker.app.data.MonthNav
import com.expensetracker.app.data.MonthSummary
import com.expensetracker.app.data.PeriodCalculator
import com.expensetracker.app.data.WeekSummary
import com.expensetracker.app.ui.components.DonutSlice
import com.expensetracker.app.ui.components.donutSlices
import com.expensetracker.app.ui.components.matchesCategory
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.mapLatest
import kotlinx.coroutines.flow.stateIn
import java.math.BigDecimal
import java.time.Instant
import java.time.YearMonth
import java.time.ZoneId
import javax.inject.Inject

data class ActivityUiState(
    val month: YearMonth = YearMonth.now(),
    val canGoNext: Boolean = false,
    val monthTotal: BigDecimal = BigDecimal.ZERO,
    val monthReceived: BigDecimal = BigDecimal.ZERO,
    val weeks: List<WeekSummary> = emptyList(),
    val selectedWeek: Long? = null,
    val expenses: List<ExpenseEntity> = emptyList(),
    val slices: List<DonutSlice> = emptyList(),
    val breakdown: List<CategoryBreakdown> = emptyList(),
    val categoryNames: Map<String, String> = emptyMap(),
    val categoryFilter: String? = null,
    val showAll: Boolean = false
)

/** One month of the All view: its spent total (as the Month view's total) and its payments after the category filter. */
data class ActivityMonthGroup(val month: YearMonth, val total: BigDecimal, val received: BigDecimal, val expenses: List<ExpenseEntity>)

/** Payments, totals, weeks and donut slices of one month (or week), before the category filter. */
private data class MonthData(
    val month: YearMonth,
    val monthTotal: BigDecimal,
    val monthReceived: BigDecimal,
    val weeks: List<WeekSummary>,
    val selectedWeek: Long?,
    val expenses: List<ExpenseEntity>,
    val slices: List<DonutSlice>,
    val breakdown: List<CategoryBreakdown>
)

/** Spent in total and per category over the range the filter sheet shows. */
data class FilterTotals(val total: BigDecimal = BigDecimal.ZERO, val breakdown: List<CategoryBreakdown> = emptyList())

@HiltViewModel
class ActivityViewModel @Inject constructor(
    private val expenseRepository: ExpenseRepository,
    categoryRepository: CategoryRepository,
    private val activitySelection: ActivitySelection
) : ViewModel() {

    val categories: StateFlow<List<CategoryEntity>> = categoryRepository.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    @OptIn(ExperimentalCoroutinesApi::class)
    private val monthData: Flow<MonthData> = activitySelection.state
        .map { it.month to it.weekStart }
        .distinctUntilChanged()
        .flatMapLatest { (shownMonth, weekStart) ->
            val year = shownMonth.year
            val month = shownMonth.monthValue - 1
            val (monthStart, monthEnd) = PeriodCalculator.rangeForMonth(year, month)
            val weekRanges = PeriodCalculator.weeksInMonth(year, month)
            val week = weekStart?.let { start -> weekRanges.firstOrNull { it.first == start } }
            val (listStart, listEnd) = week ?: (monthStart to monthEnd)
            // Full Mon–Sun weeks reach into the neighbor months, so watch the whole span.
            val spanStart = weekRanges.firstOrNull()?.first ?: monthStart
            val spanEnd = weekRanges.lastOrNull()?.second ?: monthEnd
            // The header totals follow the list range: the whole month, or the selected full Mon–Sun week.
            combine(
                expenseRepository.observeTotalForRange(listStart, listEnd),
                expenseRepository.observeReceivedForRange(listStart, listEnd),
                expenseRepository.observeInRange(spanStart, spanEnd).mapLatest { span ->
                    expenseRepository.weekSummariesForMonth(year, month) to
                        span.filter { it.notificationPostTime in listStart until listEnd }
                },
                expenseRepository.observeCategoryBreakdown(listStart, listEnd)
            ) { total, received, (weeks, expenses), breakdown ->
                MonthData(shownMonth, total ?: BigDecimal.ZERO, received ?: BigDecimal.ZERO, weeks, week?.first, expenses, donutSlices(breakdown), breakdown)
            }
        }

    val uiState: StateFlow<ActivityUiState> = combine(
        monthData,
        categoryRepository.observeAll(),
        activitySelection.state.map { it.categoryFilter to it.showAll }.distinctUntilChanged()
    ) { data, cats, (filter, showAll) ->
        ActivityUiState(
            month = data.month,
            canGoNext = MonthNav.next(data.month, YearMonth.now()) != null,
            monthTotal = data.monthTotal,
            monthReceived = data.monthReceived,
            weeks = data.weeks,
            selectedWeek = data.selectedWeek,
            expenses = data.expenses.filter { it.matchesCategory(filter) },
            slices = data.slices,
            breakdown = data.breakdown,
            categoryNames = cats.associate { it.id to it.name },
            categoryFilter = filter,
            showAll = showAll
        )
    }.stateIn(
        viewModelScope,
        SharingStarted.WhileSubscribed(5000),
        ActivityUiState(month = activitySelection.state.value.month, showAll = activitySelection.state.value.showAll)
    )

    /** Every payment, newest first, split by month; null while loading. Only watched in the All view. */
    @OptIn(ExperimentalCoroutinesApi::class)
    val allMonths: StateFlow<List<ActivityMonthGroup>?> = activitySelection.state
        .map { it.showAll }
        .distinctUntilChanged()
        .flatMapLatest { showAll ->
            if (!showAll) {
                flowOf(null)
            } else {
                combine(
                    expenseRepository.observeAllActive(),
                    expenseRepository.observeMonthlySummaries(),
                    activitySelection.state.map { it.categoryFilter }.distinctUntilChanged()
                ) { expenses, months, filter ->
                    val byMonth = months.associateBy { YearMonth.of(it.year, it.month + 1) }
                    val zone = ZoneId.systemDefault()
                    expenses.filter { it.matchesCategory(filter) }
                        .groupBy { YearMonth.from(Instant.ofEpochMilli(it.notificationPostTime).atZone(zone)) }
                        .map { (month, list) ->
                            val summary = byMonth[month]
                            ActivityMonthGroup(month, summary?.total ?: BigDecimal.ZERO, summary?.received ?: BigDecimal.ZERO, list)
                        }
                }
            }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    /** Totals for the filter sheet: the donut's range (month or selected week) in the Month view, all time in the All view. */
    @OptIn(ExperimentalCoroutinesApi::class)
    val filterTotals: StateFlow<FilterTotals> = activitySelection.state
        .map { it.showAll }
        .distinctUntilChanged()
        .flatMapLatest { showAll ->
            if (showAll) {
                combine(
                    expenseRepository.observeTotalForRange(0, Long.MAX_VALUE),
                    expenseRepository.observeCategoryBreakdown(0, Long.MAX_VALUE)
                ) { total, breakdown -> FilterTotals(total ?: BigDecimal.ZERO, breakdown) }
            } else {
                uiState.map { FilterTotals(it.monthTotal, it.breakdown) }
            }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), FilterTotals())

    /** Months with payments, newest first, plus the current month even when it is empty. */
    val sheetMonths: StateFlow<List<MonthSummary>> = expenseRepository.observeMonthlySummaries()
        .map { months ->
            val now = YearMonth.now()
            if (months.any { it.year == now.year && it.month == now.monthValue - 1 }) {
                months
            } else {
                val current = MonthSummary(now.year, now.monthValue - 1, MonthNav.label(now), BigDecimal.ZERO)
                (months + current).sortedByDescending { it.year * 12 + it.month }
            }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    // Stepping inside the tab keeps the category filter; only Home's deep link clears it.
    fun previousMonth() {
        val sel = activitySelection.state.value
        activitySelection.show(MonthNav.previous(sel.month), categoryFilter = sel.categoryFilter)
    }

    fun nextMonth() {
        val sel = activitySelection.state.value
        MonthNav.next(sel.month, YearMonth.now())?.let { activitySelection.show(it, categoryFilter = sel.categoryFilter) }
    }

    fun pickMonth(month: YearMonth) {
        activitySelection.show(month, categoryFilter = activitySelection.state.value.categoryFilter)
    }

    fun toggleWeek(weekStart: Long) {
        val sel = activitySelection.state.value
        activitySelection.show(sel.month, if (sel.weekStart == weekStart) null else weekStart, sel.categoryFilter)
    }

    fun setCategoryFilter(filter: String?) {
        activitySelection.setCategoryFilter(filter)
    }

    fun setShowAll(showAll: Boolean) {
        activitySelection.setShowAll(showAll)
    }

    fun categoryNameFor(expense: ExpenseEntity, names: Map<String, String>): String {
        return expense.categoryId?.let { names[it] } ?: DefaultCategories.UNCATEGORIZED_NAME
    }
}
