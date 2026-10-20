package com.expensetracker.app.ui.viewmodel

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.CategoryRepository
import com.expensetracker.app.data.ExpenseRepository
import com.expensetracker.app.data.TransactionType
import com.expensetracker.app.ui.components.AmountInput
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/** What the payment page shows. [amountText] is the raw number-pad text, as [AmountInput] keeps it. */
data class PaymentForm(
    val amountText: String,
    val type: TransactionType,
    val categoryId: String?,
    val postTime: Long,
    val merchant: String,
    val notes: String
)

sealed interface PaymentEvent {
    data object Close : PaymentEvent
    data class OpenSplit(val expenseId: String) : PaymentEvent
}

@HiltViewModel
class PaymentViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val expenseRepository: ExpenseRepository,
    categoryRepository: CategoryRepository
) : ViewModel() {

    private val expenseId: String? = savedStateHandle["expenseId"]
    val isEditing: Boolean = expenseId != null

    /** The category the payment had when the page opened; null when adding. */
    var loadedCategoryId: String? = null
        private set

    private val _form = MutableStateFlow<PaymentForm?>(null)
    /** Null while an edited payment loads. */
    val form: StateFlow<PaymentForm?> = _form.asStateFlow()

    val categories: StateFlow<List<CategoryEntity>> = categoryRepository.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val _events = Channel<PaymentEvent>(Channel.BUFFERED)
    val events: Flow<PaymentEvent> = _events.receiveAsFlow()

    /** Set on the first save, so a double tap cannot add the payment twice. */
    private var saving = false

    init {
        if (expenseId == null) {
            _form.value = PaymentForm("", TransactionType.WITHDRAW, null, System.currentTimeMillis(), "", "")
        } else {
            viewModelScope.launch {
                val expense = expenseRepository.getById(expenseId)
                if (expense == null) {
                    _events.send(PaymentEvent.Close)
                    return@launch
                }
                loadedCategoryId = expense.categoryId
                _form.value = PaymentForm(
                    amountText = AmountInput.fromAmount(expense.amount),
                    type = expense.transactionType,
                    categoryId = expense.categoryId,
                    postTime = expense.notificationPostTime,
                    merchant = expense.merchant.orEmpty(),
                    notes = expense.notes.orEmpty()
                )
            }
        }
    }

    private fun edit(change: (PaymentForm) -> PaymentForm) = _form.update { it?.let(change) }

    fun press(key: Char) = edit { it.copy(amountText = AmountInput.press(it.amountText, key)) }
    fun backspace() = edit { it.copy(amountText = AmountInput.backspace(it.amountText)) }
    fun setType(t: TransactionType) = edit { it.copy(type = t) }
    fun setCategory(id: String?) = edit { it.copy(categoryId = id) }
    fun setDate(time: Long) = edit { it.copy(postTime = time) }
    fun setMerchant(s: String) = edit { it.copy(merchant = s) }
    fun setNotes(s: String) = edit { it.copy(notes = s) }

    fun save() = persist(PaymentEvent.Close)

    /** Saves first, so the split editor loads the new amount. Only an edited payment has an id to split. */
    fun saveAndSplit() {
        persist(PaymentEvent.OpenSplit(expenseId ?: return))
    }

    private fun persist(after: PaymentEvent) {
        val f = _form.value ?: return
        val amount = AmountInput.toAmount(f.amountText) ?: return
        if (saving) return
        saving = true
        val merchant = f.merchant.ifBlank { null }
        val notes = f.notes.ifBlank { null }
        viewModelScope.launch {
            if (expenseId == null) {
                expenseRepository.addManualExpense(amount, merchant, f.postTime, f.categoryId, notes, f.type)
            } else {
                expenseRepository.updateExpense(expenseId, amount, merchant, f.postTime, f.categoryId, notes, f.type)
            }
            _events.send(after)
        }
    }
}
