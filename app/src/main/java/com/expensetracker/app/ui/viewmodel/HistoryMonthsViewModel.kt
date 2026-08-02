package com.expensetracker.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.ExpenseRepository
import com.expensetracker.app.data.MonthSummary
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

@HiltViewModel
class HistoryMonthsViewModel @Inject constructor(
    expenseRepository: ExpenseRepository
) : ViewModel() {
    val months: StateFlow<List<MonthSummary>> = expenseRepository.observeMonthlySummaries()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
}
