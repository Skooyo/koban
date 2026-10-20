package com.expensetracker.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.CategoryRepository
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.data.ExpenseRepository
import com.expensetracker.app.data.ExpenseStatus
import com.expensetracker.app.data.ParseConfidence
import com.expensetracker.app.data.PeopleRepository
import com.expensetracker.app.ui.components.matchesCategory
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.getAndUpdate
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.math.BigDecimal
import javax.inject.Inject

data class ExpensesUiState(
    val expenses: List<ExpenseEntity> = emptyList(),
    val categoryNames: Map<String, String> = emptyMap(),
    val categoryFilter: String? = null
)

/** Id of the blank expense that the Add payment dialog edits. */
private const val NEW_EXPENSE_ID = ""

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

    private val _editingExpense = MutableStateFlow<ExpenseEntity?>(null)
    val editingExpense: StateFlow<ExpenseEntity?> = _editingExpense.asStateFlow()

    fun startEditing(expense: ExpenseEntity) {
        _editingExpense.value = expense
    }

    fun clearEditing() {
        _editingExpense.value = null
    }

    /** Opens the edit dialog on a blank payment dated now. */
    fun startAdding() {
        val now = System.currentTimeMillis()
        _editingExpense.value = ExpenseEntity(
            id = NEW_EXPENSE_ID,
            amount = BigDecimal.ZERO,
            currency = "MYR",
            merchant = null,
            rawNotificationText = "",
            sourcePackage = ExpenseRepository.MANUAL_SOURCE,
            notificationPostTime = now,
            createdAt = now,
            dedupKey = "",
            status = ExpenseStatus.EDITED,
            confidence = ParseConfidence.HIGH,
            notificationKey = null
        )
    }

    fun isAdding(expense: ExpenseEntity) = expense.id == NEW_EXPENSE_ID

    fun saveEdit(
        amount: BigDecimal,
        merchant: String?,
        postTime: Long,
        categoryId: String?,
        notes: String?,
        transactionType: com.expensetracker.app.data.TransactionType
    ) {
        // Close the dialog first, so a double tap on Save cannot add the payment twice.
        val id = _editingExpense.getAndUpdate { null }?.id ?: return
        viewModelScope.launch {
            if (id == NEW_EXPENSE_ID) {
                expenseRepository.addManualExpense(amount, merchant, postTime, categoryId, notes, transactionType)
            } else {
                expenseRepository.updateExpense(
                    id, amount, merchant, postTime, categoryId, notes, transactionType
                )
            }
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
