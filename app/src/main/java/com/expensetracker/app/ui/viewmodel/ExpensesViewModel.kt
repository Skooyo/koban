package com.expensetracker.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.CategoryRepository
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.data.ExpenseRepository
import com.expensetracker.app.data.PeopleRepository
import com.expensetracker.app.ui.components.matchesCategory
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ExpensesUiState(
    val expenses: List<ExpenseEntity> = emptyList(),
    val categoryNames: Map<String, String> = emptyMap(),
    val categoryFilter: String? = null
)

@HiltViewModel
class ExpensesViewModel @Inject constructor(
    private val expenseRepository: ExpenseRepository,
    private val categoryRepository: CategoryRepository,
    peopleRepository: PeopleRepository
) : ViewModel() {

    val categories: StateFlow<List<CategoryEntity>> = categoryRepository.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val categoryFilter = MutableStateFlow<String?>(null)

    val uiState: StateFlow<ExpensesUiState> = combine(
        expenseRepository.observeAllActive(),
        categoryRepository.observeAll(),
        categoryFilter
    ) { expenses, categories, filter ->
        ExpensesUiState(
            expenses = expenses.filter { it.matchesCategory(filter) },
            categoryNames = categories.associate { it.id to it.name },
            categoryFilter = filter
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), ExpensesUiState())

    fun setCategoryFilter(filter: String?) {
        categoryFilter.value = filter
    }

    val openPeopleCount: StateFlow<Int> = peopleRepository.observePeople()
        .map { list -> list.count { it.hasOpen } }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0)

    fun dismiss(expense: ExpenseEntity) {
        viewModelScope.launch {
            expenseRepository.dismissExpense(expense.id)
        }
    }

    fun categoryNameFor(expense: ExpenseEntity, names: Map<String, String>): String {
        return expense.categoryId?.let { names[it] } ?: DefaultCategories.UNCATEGORIZED_NAME
    }
}
