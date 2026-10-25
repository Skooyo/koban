package com.expensetracker.app.ui.viewmodel

import android.content.Context
import android.content.pm.PackageManager
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.CategoryRepository
import com.expensetracker.app.data.ConfirmResult
import com.expensetracker.app.data.DefaultCategories
import com.expensetracker.app.data.MerchantCategoryRepository
import com.expensetracker.app.data.PendingPaymentEntity
import com.expensetracker.app.data.PendingPaymentRepository
import com.expensetracker.app.parser.AmountFormatter
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import javax.inject.Inject

/** One card on the swipe screen. [categoryId] is the card's own category, or else the merchant memory. */
data class CheckCard(
    val payment: PendingPaymentEntity,
    val appName: String,
    val categoryId: String?,
    val categoryName: String
)

@HiltViewModel
class CheckPaymentsViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val repository: PendingPaymentRepository,
    categoryRepository: CategoryRepository,
    private val merchantCategoryRepository: MerchantCategoryRepository
) : ViewModel() {

    companion object {
        const val ALREADY_SAVED_MESSAGE = "Already saved, so it was not added again."
        private const val UNDO_MS = 4000L
    }

    val categories: StateFlow<List<CategoryEntity>> = categoryRepository.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val appNames = mutableMapOf<String, String>()

    /** Waiting payments, oldest first. Null until the first database read, so the screen does not close too early. */
    val waiting: StateFlow<List<CheckCard>?> =
        combine(repository.observeWaiting(), categoryRepository.observeAll()) { rows, categories ->
            val names = categories.associate { it.id to it.name }
            rows.map { payment ->
                val categoryId = (payment.categoryId ?: merchantCategoryRepository.categoryIdForMerchant(payment.merchant))
                    ?.takeIf { it in names }
                CheckCard(
                    payment = payment,
                    appName = appName(payment.sourcePackage),
                    categoryId = categoryId,
                    categoryName = categoryId?.let(names::get) ?: DefaultCategories.UNCATEGORIZED_NAME
                )
            }
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    /** Cards swiped on this visit, for the "N of M" counter. */
    private val _handled = MutableStateFlow(0)
    val handled: StateFlow<Int> = _handled.asStateFlow()

    /** Text of the Undo pill, for example "Saved Kedai Contoh · Undo"; null hides it. */
    private val _undoLabel = MutableStateFlow<String?>(null)
    val undoLabel: StateFlow<String?> = _undoLabel.asStateFlow()

    private var undoJob: Job? = null
    private var heldId: String? = null

    val messages: Flow<String> = repository.lastResult
        .filter { it == ConfirmResult.ALREADY_SAVED }
        .map { ALREADY_SAVED_MESSAGE }

    fun swipe(id: String, save: Boolean) {
        val payment = waiting.value?.find { it.payment.id == id }?.payment ?: return
        val what = payment.merchant
            ?: "${AmountFormatter.currencySymbol(payment.currency)} ${AmountFormatter.formatGrouped(payment.amount)}"
        // Set the pill before the card goes, so the screen never sees an empty list with no pill.
        _undoLabel.value = "${if (save) "Saved" else "Skipped"} $what · Undo"
        heldId = id
        repository.hold(id, save)
        _handled.update { it + 1 }
        undoJob?.cancel()
        undoJob = viewModelScope.launch {
            delay(UNDO_MS)
            _undoLabel.value = null
        }
    }

    fun undo() {
        undoJob?.cancel()
        val id = heldId
        heldId = null
        if (id == null || !repository.undo()) {
            _undoLabel.value = null
            return
        }
        _handled.update { (it - 1).coerceAtLeast(0) }
        // Keep the pill until the card is back on the list, for the same reason as in swipe.
        undoJob = viewModelScope.launch {
            withTimeoutOrNull(1000) { waiting.first { list -> list?.any { it.payment.id == id } == true } }
            _undoLabel.value = null
        }
    }

    fun edit(payment: PendingPaymentEntity) {
        viewModelScope.launch { repository.update(payment) }
    }

    /** Commits the held swipe now. The screen calls it when it leaves. */
    fun flushHold() {
        undoJob?.cancel()
        heldId = null
        _undoLabel.value = null
        repository.flushHold()
    }

    override fun onCleared() {
        repository.flushHold()
    }

    /** The app's name, or its package name when Android does not let Koban see the app. */
    private fun appName(packageName: String): String = appNames.getOrPut(packageName) {
        val pm = context.packageManager
        try {
            pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            packageName
        }
    }
}
