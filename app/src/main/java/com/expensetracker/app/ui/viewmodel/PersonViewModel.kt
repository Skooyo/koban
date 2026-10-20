package com.expensetracker.app.ui.viewmodel

import android.net.Uri
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.data.OpenDebtView
import com.expensetracker.app.data.OwedItemEntity
import com.expensetracker.app.data.PeopleRepository
import com.expensetracker.app.data.PersonDetail
import com.expensetracker.app.data.SplitRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.math.BigDecimal
import javax.inject.Inject

/** The split debt being marked paid, with the received payments it could match. */
data class DebtPayment(val debt: OpenDebtView, val candidates: List<ExpenseEntity>)

@HiltViewModel
class PersonViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val peopleRepository: PeopleRepository,
    private val splitRepository: SplitRepository
) : ViewModel() {

    private val personId: String = savedStateHandle.get<String>("personId").orEmpty()

    private val person = peopleRepository.observePerson(personId)

    val detail: StateFlow<PersonDetail?> = person
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    /** True once the person is missing or archived, for example right after Delete person. */
    val gone: StateFlow<Boolean> = person.map { it == null }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

    /** Bumped after each QR import: the file path stays the same, so the screen reloads on this. */
    private val _qrVersion = MutableStateFlow(0)
    val qrVersion: StateFlow<Int> = _qrVersion.asStateFlow()

    private val _paying = MutableStateFlow<DebtPayment?>(null)
    val paying: StateFlow<DebtPayment?> = _paying.asStateFlow()

    private val _messages = Channel<String>(Channel.BUFFERED)
    val messages: Flow<String> = _messages.receiveAsFlow()

    private var busy = false

    fun showMessage(message: String) {
        _messages.trySend(message)
    }

    // Dialog actions: the dialog shows IllegalArgumentException messages itself.
    suspend fun rename(name: String) = peopleRepository.renamePerson(personId, name)

    suspend fun addItem(description: String, amount: BigDecimal, itemDate: Long) =
        peopleRepository.addOwedItem(personId, description, amount, itemDate)

    suspend fun updateItem(item: OwedItemEntity) = peopleRepository.updateOwedItem(item)

    fun deleteItem(id: String) = run { peopleRepository.deleteOwedItem(id) }

    fun markItemPaid(id: String) = run { peopleRepository.markOwedItemPaid(id) }

    fun delete() = run { peopleRepository.archivePerson(personId) }

    fun setQr(uri: Uri) = run {
        peopleRepository.setQr(personId, uri)
        _qrVersion.value++
    }

    fun saveQrToGallery() = run {
        peopleRepository.saveQrToGallery(personId)
        _messages.send("Saved to gallery. Open your bank app and pick it.")
    }

    fun settleUp() = run { peopleRepository.settleUp(personId) }

    fun confirmSettle() = run {
        if (!peopleRepository.confirmSettleSuggestion(personId)) {
            _messages.send("That payment no longer matches. Check the amounts and settle up by hand.")
        }
    }

    fun dismissSettle() = run { peopleRepository.dismissSettleSuggestion(personId) }

    fun startPaying(debt: OpenDebtView) = run {
        _paying.value = DebtPayment(debt, splitRepository.repaymentCandidates(debt.debt.id))
    }

    fun cancelPaying() {
        _paying.value = null
    }

    /** A null [expenseId] means paid in cash. */
    fun markDebtPaid(expenseId: String?) {
        val debtId = _paying.value?.debt?.debt?.id ?: return
        if (busy) {
            showMessage("Try again in a moment.")
            return
        }
        _paying.value = null
        run { splitRepository.markPaid(debtId, expenseId) }
    }

    fun confirmDebtSuggestion(debtId: String) = run { splitRepository.confirmSuggestion(debtId) }

    fun dismissDebtSuggestion(debtId: String) = run { splitRepository.dismissSuggestion(debtId) }

    /** Runs one action at a time. A tap during another action shows a hint. Validation failures show their message. */
    private fun run(action: suspend () -> Unit) {
        if (busy) {
            showMessage("Try again in a moment.")
            return
        }
        busy = true
        viewModelScope.launch {
            try {
                action()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                val validation = e is IllegalArgumentException || e is IllegalStateException
                _messages.send((if (validation) e.message else null) ?: "Something went wrong. Try again.")
            } finally {
                busy = false
            }
        }
    }
}
