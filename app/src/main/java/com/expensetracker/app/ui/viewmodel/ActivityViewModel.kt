package com.expensetracker.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.ActivitySelection
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.CategoryRepository
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.data.ExpenseRepository
import com.expensetracker.app.data.MonthNav
import com.expensetracker.app.data.MonthSummary
import com.expensetracker.app.data.PeriodCalculator
import com.expensetracker.app.data.WeekSummary
import com.expensetracker.app.ui.components.matchesCategory
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.mapLatest
import kotlinx.coroutines.flow.stateIn
import java.math.BigDecimal
import java.time.YearMonth
import javax.inject.Inject

data class ActivityUiState(
    val month: YearMonth = YearMonth.now(),
    val canGoNext: Boolean = false,
    val monthTotal: BigDecimal = BigDecimal.ZERO,
    val weeks: List<WeekSummary> = emptyList(),
    val selectedWeek: Long? = null,
    val expenses: List<ExpenseEntity> = emptyList(),
    val categoryNames: Map<String, String> = emptyMap(),
    val categoryFilter: String? = null
)

/** Payments, totals and weeks of one month, before the category filter. */
private data class MonthData(
    val selection: ActivitySelection.Selection,
    val monthTotal: BigDecimal,
    val weeks: List<WeekSummary>,
    val selectedWeek: Long?,
    val expenses: List<ExpenseEntity>
)

@HiltViewModel
class ActivityViewModel @Inject constructor(
    private val expenseRepository: ExpenseRepository,
    categoryRepository: CategoryRepository,
    private val activitySelection: ActivitySelection
) : ViewModel() {

    val categories: StateFlow<List<CategoryEntity>> = categoryRepository.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val categoryFilter = MutableStateFlow<String?>(null)

    @OptIn(ExperimentalCoroutinesApi::class)
    private val monthData: Flow<MonthData> = activitySelection.state.flatMapLatest { sel ->
        val year = sel.month.year
        val month = sel.month.monthValue - 1
        val (monthStart, monthEnd) = PeriodCalculator.rangeForMonth(year, month)
        val weekRanges = PeriodCalculator.weeksInMonth(year, month)
        val week = sel.weekStart?.let { start -> weekRanges.firstOrNull { it.first == start } }
        val (listStart, listEnd) = week ?: (monthStart to monthEnd)
        // Full Mon–Sun weeks reach into the neighbor months, so watch the whole span.
        val spanStart = weekRanges.firstOrNull()?.first ?: monthStart
        val spanEnd = weekRanges.lastOrNull()?.second ?: monthEnd
        combine(
            expenseRepository.observeTotalForRange(monthStart, monthEnd),
            expenseRepository.observeInRange(spanStart, spanEnd).mapLatest { span ->
                expenseRepository.weekSummariesForMonth(year, month) to
                    span.filter { it.notificationPostTime in listStart until listEnd }
            }
        ) { total, (weeks, expenses) ->
            MonthData(sel, total ?: BigDecimal.ZERO, weeks, week?.first, expenses)
        }
    }

    val uiState: StateFlow<ActivityUiState> = combine(
        monthData,
        categoryRepository.observeAll(),
        categoryFilter
    ) { data, cats, filter ->
        ActivityUiState(
            month = data.selection.month,
            canGoNext = MonthNav.next(data.selection.month, YearMonth.now()) != null,
            monthTotal = data.monthTotal,
            weeks = data.weeks,
            selectedWeek = data.selectedWeek,
            expenses = data.expenses.filter { it.matchesCategory(filter) },
            categoryNames = cats.associate { it.id to it.name },
            categoryFilter = filter
        )
    }.stateIn(
        viewModelScope,
        SharingStarted.WhileSubscribed(5000),
        ActivityUiState(month = activitySelection.state.value.month)
    )

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

    fun previousMonth() {
        activitySelection.show(MonthNav.previous(activitySelection.state.value.month))
    }

    fun nextMonth() {
        MonthNav.next(activitySelection.state.value.month, YearMonth.now())?.let { activitySelection.show(it) }
    }

    fun pickMonth(month: YearMonth) {
        activitySelection.show(month)
    }

    fun toggleWeek(weekStart: Long) {
        val sel = activitySelection.state.value
        activitySelection.show(sel.month, if (sel.weekStart == weekStart) null else weekStart)
    }

    fun setCategoryFilter(filter: String?) {
        categoryFilter.value = filter
    }

    fun categoryNameFor(expense: ExpenseEntity, names: Map<String, String>): String {
        return expense.categoryId?.let { names[it] } ?: DefaultCategories.UNCATEGORIZED_NAME
    }
}
