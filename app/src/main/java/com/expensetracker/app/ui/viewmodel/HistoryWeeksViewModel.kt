package com.expensetracker.app.ui.viewmodel

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.ExpenseRepository
import com.expensetracker.app.data.PeriodCalculator
import com.expensetracker.app.data.WeekSummary
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class HistoryWeeksUiState(
    val monthLabel: String = "",
    val weeks: List<WeekSummary> = emptyList(),
    val monthTotal: java.math.BigDecimal = java.math.BigDecimal.ZERO
)

@HiltViewModel
class HistoryWeeksViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val expenseRepository: ExpenseRepository
) : ViewModel() {

    private val yearMonth: Int = savedStateHandle.get<Int>("yearMonth")
        ?: savedStateHandle.get<String>("yearMonth")?.toIntOrNull()
        ?: 0

    private val year: Int = PeriodCalculator.decodeYearMonth(yearMonth).first
    private val month: Int = PeriodCalculator.decodeYearMonth(yearMonth).second

    private val _uiState = MutableStateFlow(
        HistoryWeeksUiState(monthLabel = PeriodCalculator.monthLabel(year, month))
    )
    val uiState: StateFlow<HistoryWeeksUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            val weeks = expenseRepository.weekSummariesForMonth(year, month)
            val (monthStart, monthEnd) = PeriodCalculator.rangeForMonth(year, month)
            val monthTotal = expenseRepository.getMonthTotalOnce(monthStart, monthEnd)
            _uiState.value = HistoryWeeksUiState(
                monthLabel = PeriodCalculator.monthLabel(year, month),
                weeks = weeks,
                monthTotal = monthTotal
            )
        }
    }
}
