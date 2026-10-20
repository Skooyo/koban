package com.expensetracker.app.ui.viewmodel

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.CategoryRepository
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.data.ExpenseRepository
import com.expensetracker.app.data.TransactionType
import com.expensetracker.app.data.effectiveAmount
import com.expensetracker.app.ui.components.DonutSlice
import com.expensetracker.app.ui.components.donutSlices
import com.expensetracker.app.ui.components.matchesCategory
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.getAndUpdate
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.math.BigDecimal
import javax.inject.Inject

data class FilteredExpensesUiState(
    val title: String = "",
    val expenses: List<ExpenseEntity> = emptyList(),
    val categoryNames: Map<String, String> = emptyMap(),
    val total: BigDecimal = BigDecimal.ZERO,
    val slices: List<DonutSlice> = emptyList(),
    val categoryFilter: String? = null
)

@HiltViewModel
class FilteredExpensesViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val expenseRepository: ExpenseRepository,
    private val categoryRepository: CategoryRepository
) : ViewModel() {

    private val startMs: Long = savedStateHandle.get<String>("start")?.toLongOrNull() ?: 0L
    private val endMs: Long = savedStateHandle.get<String>("end")?.toLongOrNull() ?: Long.MAX_VALUE
    private val title: String = savedStateHandle.get<String>("title") ?: "Expenses"

    val categories: StateFlow<List<CategoryEntity>> = categoryRepository.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val categoryFilter = MutableStateFlow<String?>(null)

    val uiState: StateFlow<FilteredExpensesUiState> = combine(
        expenseRepository.observeInRange(startMs, endMs),
        expenseRepository.observeTotalForRange(startMs, endMs),
        expenseRepository.observeCategoryBreakdown(startMs, endMs),
        categoryRepository.observeAll(),
        categoryFilter
    ) { expenses, total, breakdown, cats, filter ->
        val shown = expenses.filter { it.matchesCategory(filter) }
        FilteredExpensesUiState(
            title = title,
            expenses = shown,
            categoryNames = cats.associate { it.id to it.name },
            total = if (filter == null) {
                total ?: BigDecimal.ZERO
            } else {
                shown.filter { it.transactionType != TransactionType.RECEIVE }
                    .fold(BigDecimal.ZERO) { sum, e -> sum + e.effectiveAmount }
            },
            slices = donutSlices(breakdown),
            categoryFilter = filter
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), FilteredExpensesUiState(title = title))

    fun setCategoryFilter(filter: String?) {
        categoryFilter.value = filter
    }

    fun delete(expense: ExpenseEntity) {
        viewModelScope.launch {
            expenseRepository.dismissExpense(expense.id)
        }
    }

    fun categoryNameFor(expense: ExpenseEntity, names: Map<String, String>): String {
        return expense.categoryId?.let { names[it] } ?: DefaultCategories.UNCATEGORIZED_NAME
    }
}
