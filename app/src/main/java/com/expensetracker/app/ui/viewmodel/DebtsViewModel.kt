package com.expensetracker.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.data.OpenDebtView
import com.expensetracker.app.data.SplitBillEntity
import com.expensetracker.app.data.SplitRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/** The debt being marked paid, with the received payments it could match. */
data class PayingState(val debt: OpenDebtView, val candidates: List<ExpenseEntity>)

@HiltViewModel
class DebtsViewModel @Inject constructor(
    private val splitRepository: SplitRepository
) : ViewModel() {

    val debts: StateFlow<List<OpenDebtView>> = splitRepository.observeOpenDebts()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val bills: StateFlow<List<SplitBillEntity>> = splitRepository.observeBills()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val _paying = MutableStateFlow<PayingState?>(null)
    val paying: StateFlow<PayingState?> = _paying.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    private var busy = false

    fun startPaying(debt: OpenDebtView) = run("Couldn't load payments. Try again.") {
        _paying.value = PayingState(debt, splitRepository.repaymentCandidates(debt.debt.id))
    }

    fun cancelPaying() {
        _paying.value = null
    }

    /** A null [expenseId] means paid in cash. */
    fun markPaid(expenseId: String?) {
        val debtId = _paying.value?.debt?.debt?.id ?: return
        _paying.value = null
        run("Couldn't mark it paid. Try again.") { splitRepository.markPaid(debtId, expenseId) }
    }

    fun confirm(debtId: String) =
        run("Couldn't confirm the repayment. Try again.") { splitRepository.confirmSuggestion(debtId) }

    fun dismiss(debtId: String) =
        run("Couldn't dismiss the suggestion. Try again.") { splitRepository.dismissSuggestion(debtId) }

    /** Runs one action at a time, so a double tap does nothing. */
    private fun run(errorMessage: String, action: suspend () -> Unit) {
        if (busy) return
        busy = true
        _error.value = null
        viewModelScope.launch {
            try {
                action()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _error.value = errorMessage
            } finally {
                busy = false
            }
        }
    }
}
