package com.expensetracker.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.CategoryRepository
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.data.ExpenseRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.math.BigDecimal
import javax.inject.Inject

data class ExpensesUiState(
    val expenses: List<ExpenseEntity> = emptyList(),
    val categoryNames: Map<String, String> = emptyMap()
)

@HiltViewModel
class ExpensesViewModel @Inject constructor(
    private val expenseRepository: ExpenseRepository,
    private val categoryRepository: CategoryRepository
) : ViewModel() {

    val categories: StateFlow<List<CategoryEntity>> = categoryRepository.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val uiState: StateFlow<ExpensesUiState> = combine(
        expenseRepository.observeAllActive(),
        categoryRepository.observeAll()
    ) { expenses, categories ->
        ExpensesUiState(
            expenses = expenses,
            categoryNames = categories.associate { it.id to it.name }
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), ExpensesUiState())

    private val _editingExpense = MutableStateFlow<ExpenseEntity?>(null)
    val editingExpense: StateFlow<ExpenseEntity?> = _editingExpense.asStateFlow()

    fun startEditing(expense: ExpenseEntity) {
        _editingExpense.value = expense
    }

    fun clearEditing() {
        _editingExpense.value = null
    }

    fun saveEdit(
        amount: BigDecimal,
        merchant: String?,
        postTime: Long,
        categoryId: String?,
        notes: String?,
        transactionType: com.expensetracker.app.data.TransactionType
    ) {
        val id = _editingExpense.value?.id ?: return
        viewModelScope.launch {
            expenseRepository.updateExpense(
                id, amount, merchant, postTime, categoryId, notes, transactionType
            )
            _editingExpense.value = null
        }
    }

    fun dismiss(expense: ExpenseEntity) {
        viewModelScope.launch {
            expenseRepository.dismissExpense(expense.id)
        }
    }

    fun categoryNameFor(expense: ExpenseEntity, names: Map<String, String>): String {
        return expense.categoryId?.let { names[it] } ?: DefaultCategories.UNCATEGORIZED_NAME
    }
}
