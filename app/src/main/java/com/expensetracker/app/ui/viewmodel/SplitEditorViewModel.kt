package com.expensetracker.app.ui.viewmodel

import android.content.Context
import android.net.Uri
import androidx.core.content.FileProvider
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.DraftItem
import com.expensetracker.app.data.ExpenseDao
import com.expensetracker.app.data.ExpenseEntity
import com.expensetracker.app.data.ME_ID
import com.expensetracker.app.data.SplitCharges
import com.expensetracker.app.data.SplitDraft
import com.expensetracker.app.data.SplitItemInput
import com.expensetracker.app.data.SplitMath
import com.expensetracker.app.data.SplitPersonEntity
import com.expensetracker.app.data.SplitRepository
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.parser.ReceiptReader
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File
import java.math.BigDecimal
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import javax.inject.Inject

enum class SplitStep { Photo, Reading, Items, People, Assign, Link, Summary }

/** One editable item row. Text fields stay as typed; [parseItems] checks them. */
data class ItemRow(
    val key: Long,
    val name: String = "",
    val quantity: String = "1",
    val price: String = "",
    val sharedBy: Set<String> = emptySet()
)

data class SplitEditorState(
    val step: SplitStep = SplitStep.Photo,
    val loading: Boolean = false,
    val billId: String? = null,
    /** A bill with a paid debt. Only its payment link and deletion may change. */
    val locked: Boolean = false,
    val merchant: String = "",
    val billTime: Long = System.currentTimeMillis(),
    val printedTotal: BigDecimal? = null,
    val items: List<ItemRow> = emptyList(),
    val serviceCharge: String = "",
    val tax: String = "",
    val discount: String = "",
    val rounding: String = "",
    val people: List<SplitPersonEntity> = emptyList(),
    val candidates: List<ExpenseEntity> = emptyList(),
    val selectedExpenseId: String? = null,
    val message: String? = null,
    val error: String? = null,
    val saving: Boolean = false,
    val finished: Boolean = false
)

private fun parseMoney(text: String): BigDecimal? =
    if (text.isBlank()) BigDecimal.ZERO else AmountFormatter.parseInput(text)

@HiltViewModel
class SplitEditorViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    @ApplicationContext private val context: Context,
    private val splitRepository: SplitRepository,
    private val expenseDao: ExpenseDao,
    private val receiptReader: ReceiptReader
) : ViewModel() {

    private val editBillId: String? = savedStateHandle["billId"]
    private val startExpenseId: String? = savedStateHandle["expenseId"]

    private val _state = MutableStateFlow(SplitEditorState())
    val state: StateFlow<SplitEditorState> = _state.asStateFlow()

    val recentPeople: StateFlow<List<SplitPersonEntity>> = splitRepository.observeRecentPeople()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private var nextKey = 0L
    private var readJob: Job? = null

    init {
        if (editBillId != null) {
            _state.update { it.copy(loading = true) }
            viewModelScope.launch { loadExisting(editBillId) }
        } else if (startExpenseId != null) {
            _state.update { it.copy(loading = true) }
            viewModelScope.launch {
                val existing = splitRepository.billForExpense(startExpenseId)
                if (existing != null) {
                    loadExisting(existing.id)
                } else {
                    val expense = expenseDao.getById(startExpenseId)
                    _state.update {
                        it.copy(
                            loading = false,
                            selectedExpenseId = startExpenseId,
                            // The pre-linked payment time is the best bill time until a receipt gives a date.
                            billTime = expense?.notificationPostTime ?: it.billTime
                        )
                    }
                }
            }
        }
    }

    private suspend fun loadExisting(billId: String) {
        val draft = splitRepository.loadDraft(billId)
        if (draft == null) {
            _state.update { it.copy(loading = false, finished = true) }
            return
        }
        val locked = splitRepository.isLocked(billId)
        _state.update {
            it.copy(
                loading = false,
                billId = billId,
                locked = locked,
                step = SplitStep.Summary,
                merchant = draft.merchant.orEmpty(),
                billTime = draft.billTime,
                printedTotal = draft.printedTotal,
                items = draft.items.map { item ->
                    ItemRow(
                        nextKey++, item.name, item.quantity.toString(),
                        AmountFormatter.formatDisplay(item.price), item.sharedBy
                    )
                },
                serviceCharge = chargeText(draft.charges.serviceCharge),
                tax = chargeText(draft.charges.tax),
                discount = chargeText(draft.charges.discount),
                rounding = chargeText(draft.charges.rounding),
                people = draft.people,
                selectedExpenseId = draft.linkedExpenseId
            )
        }
    }

    private fun chargeText(value: BigDecimal): String =
        if (value.signum() == 0) "" else AmountFormatter.formatDisplay(value)

    // ---- Photo and reading ----

    /** Creates the cache file the camera writes to and returns its content Uri. */
    fun newPhotoUri(): Uri {
        val dir = File(context.cacheDir, "receipts").apply { mkdirs() }
        val file = File(dir, "receipt.jpg")
        return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    }

    private fun photoFile() = File(File(context.cacheDir, "receipts"), "receipt.jpg")

    /** Reads the receipt, then deletes the cached camera photo. Photos are not kept. */
    fun readReceipt(uri: Uri) {
        _state.update { it.copy(step = SplitStep.Reading, message = null) }
        readJob?.cancel()
        readJob = viewModelScope.launch {
            val draft = try {
                receiptReader.read(uri)
            } finally {
                photoFile().delete()
            }
            if (draft == null) {
                _state.update {
                    it.copy(
                        step = SplitStep.Items,
                        items = emptyList(),
                        message = "Couldn't read this receipt. Add the items by hand."
                    )
                }
            } else {
                _state.update {
                    it.copy(
                        step = SplitStep.Items,
                        merchant = draft.merchant.orEmpty(),
                        billTime = draft.dateMillis ?: it.billTime,
                        printedTotal = draft.printedTotal,
                        items = draft.items.map { item ->
                            ItemRow(
                                nextKey++, item.name, item.quantity.toString(),
                                AmountFormatter.formatDisplay(item.price)
                            )
                        },
                        serviceCharge = chargeText(draft.serviceCharge),
                        tax = chargeText(draft.tax),
                        discount = chargeText(draft.discount),
                        rounding = chargeText(draft.rounding)
                    )
                }
            }
        }
    }

    fun typeItemsInstead() {
        _state.update { it.copy(step = SplitStep.Items, message = null) }
        if (_state.value.items.isEmpty()) addItem()
    }

    fun photoCancelled() = photoFile().delete()

    // ---- Items ----

    fun addItem() = _state.update { it.copy(items = it.items + ItemRow(nextKey++)) }

    fun updateItem(key: Long, transform: (ItemRow) -> ItemRow) = _state.update { s ->
        s.copy(items = s.items.map { if (it.key == key) transform(it) else it })
    }

    fun removeItem(key: Long) = _state.update { s -> s.copy(items = s.items.filterNot { it.key == key }) }

    fun setMerchant(value: String) = _state.update { it.copy(merchant = value) }
    fun setServiceCharge(value: String) = _state.update { it.copy(serviceCharge = value) }
    fun setTax(value: String) = _state.update { it.copy(tax = value) }
    fun setDiscount(value: String) = _state.update { it.copy(discount = value) }
    fun setRounding(value: String) = _state.update { it.copy(rounding = value) }

    /** Moves the whole gap to the printed total into the rounding field. */
    fun addRoundingDifference() {
        val s = _state.value
        val diff = difference(s) ?: return
        val current = parseMoney(s.rounding) ?: return
        _state.update { it.copy(rounding = AmountFormatter.formatDisplay(current + diff)) }
    }

    // ---- People ----

    fun addPerson(rawName: String) {
        val name = rawName.trim()
        if (name.isEmpty() || name.equals("me", ignoreCase = true)) return
        _state.update { s ->
            if (s.people.any { it.name.equals(name, ignoreCase = true) }) return@update s
            val known = recentPeople.value.firstOrNull { it.name.equals(name, ignoreCase = true) }
            s.copy(people = s.people + (known ?: SplitPersonEntity(UUID.randomUUID().toString(), name, 0L)))
        }
    }

    fun togglePerson(person: SplitPersonEntity) {
        if (_state.value.people.any { it.id == person.id }) {
            _state.update { s ->
                s.copy(
                    people = s.people.filterNot { it.id == person.id },
                    items = s.items.map { it.copy(sharedBy = it.sharedBy - person.id) }
                )
            }
        } else {
            addPerson(person.name)
        }
    }

    // ---- Assign ----

    fun toggleShare(key: Long, personId: String) = updateItem(key) {
        it.copy(sharedBy = if (personId in it.sharedBy) it.sharedBy - personId else it.sharedBy + personId)
    }

    // ---- Link ----

    fun selectExpense(id: String?) = _state.update { it.copy(selectedExpenseId = id) }

    private fun loadCandidates() {
        val s = _state.value
        val total = totalOf(s) ?: return
        viewModelScope.launch {
            val found = splitRepository.paymentCandidates(s.billId, total, s.billTime)
            val selected = s.selectedExpenseId?.let { id ->
                if (found.any { it.id == id }) null else expenseDao.getById(id)
            }
            _state.update { it.copy(candidates = listOfNotNull(selected) + found) }
        }
    }

    /** Locked bills only: saves the new link at once and shows the summary again. */
    fun saveLockedPayment() {
        val billId = _state.value.billId ?: return
        if (_state.value.saving) return
        _state.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            try {
                splitRepository.linkPayment(billId, _state.value.selectedExpenseId)
                _state.update { it.copy(step = SplitStep.Summary, saving = false) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: IllegalStateException) {
                _state.update { it.copy(saving = false, error = e.message) }
            } catch (e: Exception) {
                _state.update { it.copy(saving = false, error = "Couldn't save the split. Try again.") }
            }
        }
    }

    fun editItems() = _state.update { it.copy(step = SplitStep.Items, error = null) }

    fun changePayment() {
        _state.update { it.copy(step = SplitStep.Link) }
        loadCandidates()
    }

    fun deleteSplit() {
        val billId = _state.value.billId ?: return
        if (_state.value.saving) return
        _state.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            try {
                splitRepository.deleteSplit(billId)
                _state.update { it.copy(finished = true) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(saving = false, error = "Couldn't delete the split. Try again.") }
            }
        }
    }

    // ---- Navigation between steps ----

    fun next() {
        val s = _state.value
        val target = when (s.step) {
            SplitStep.Items -> SplitStep.People
            SplitStep.People -> SplitStep.Assign
            SplitStep.Assign -> SplitStep.Link
            SplitStep.Link -> SplitStep.Summary
            else -> return
        }
        _state.update { it.copy(step = target, error = null) }
        if (target == SplitStep.Link) loadCandidates()
    }

    /** Returns false when the screen should leave the flow. */
    fun back(): Boolean {
        val s = _state.value
        val target = when (s.step) {
            SplitStep.Photo -> return false
            SplitStep.Reading -> {
                readJob?.cancel()
                SplitStep.Photo
            }
            SplitStep.Items -> if (s.billId != null) return false else SplitStep.Photo
            SplitStep.People -> SplitStep.Items
            SplitStep.Assign -> SplitStep.People
            SplitStep.Link -> if (s.locked) SplitStep.Summary else SplitStep.Assign
            SplitStep.Summary -> if (s.locked) return false else SplitStep.Link
        }
        _state.update { it.copy(step = target, error = null) }
        return true
    }

    // ---- Save ----

    fun done() {
        val s = _state.value
        if (s.locked || s.saving) return
        val items = parseItems(s) ?: return
        val charges = chargesOf(s) ?: return
        val draft = SplitDraft(
            billId = s.billId,
            merchant = s.merchant.trim().ifBlank { null },
            billTime = s.billTime,
            currency = "MYR",
            printedTotal = s.printedTotal,
            items = items,
            charges = charges,
            people = s.people,
            linkedExpenseId = s.selectedExpenseId
        )
        _state.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            try {
                splitRepository.saveSplit(draft)
                _state.update { it.copy(finished = true) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: IllegalStateException) {
                _state.update { it.copy(saving = false, error = e.message) }
            } catch (e: Exception) {
                _state.update { it.copy(saving = false, error = "Couldn't save the split. Try again.") }
            }
        }
    }

    // ---- Derived values (pure, used by the screen) ----

    companion object {
        /** Null when any row has a bad name, quantity or price. */
        fun parseItems(s: SplitEditorState): List<DraftItem>? = s.items.map { row ->
            val price = AmountFormatter.parseInput(row.price)
            val quantity = row.quantity.trim().toIntOrNull()
            if (row.name.isBlank() || price == null || price.signum() <= 0 || quantity == null || quantity < 1) {
                return null
            }
            DraftItem(row.name.trim(), quantity, price, row.sharedBy)
        }

        fun chargesOf(s: SplitEditorState): SplitCharges? {
            val service = parseMoney(s.serviceCharge) ?: return null
            val tax = parseMoney(s.tax) ?: return null
            val discount = parseMoney(s.discount) ?: return null
            val rounding = parseMoney(s.rounding) ?: return null
            return SplitCharges(service, tax, discount, rounding)
        }

        fun inputsOf(s: SplitEditorState): List<SplitItemInput>? =
            parseItems(s)?.map { SplitItemInput(it.price, it.sharedBy) }

        fun totalOf(s: SplitEditorState): BigDecimal? {
            val items = inputsOf(s) ?: return null
            val charges = chargesOf(s) ?: return null
            return SplitMath.computedTotal(items, charges)
        }

        /** Printed total minus computed total, or null when equal, unknown or not valid yet. */
        fun difference(s: SplitEditorState): BigDecimal? {
            val printed = s.printedTotal ?: return null
            val diff = printed - (totalOf(s) ?: return null)
            return diff.takeIf { it.signum() != 0 }
        }

        fun unassigned(s: SplitEditorState): Set<Long> {
            val indexes = SplitMath.unassignedItemIndexes(s.items.map { SplitItemInput(BigDecimal.ZERO, it.sharedBy) })
            return indexes.map { s.items[it].key }.toSet()
        }

        /** Names with amounts, Me last. Null until the bill is complete. */
        fun summaryLines(s: SplitEditorState): List<Pair<String, BigDecimal>>? {
            val inputs = inputsOf(s) ?: return null
            val charges = chargesOf(s) ?: return null
            if (SplitMath.unassignedItemIndexes(inputs).isNotEmpty()) return null
            val shares = SplitMath.shares(inputs, charges)
            val names = s.people.associate { it.id to it.name }
            val others = shares.filterKeys { it != ME_ID }.map { (id, amount) -> (names[id] ?: id) to amount }
            return others + ("Me" to shares.getValue(ME_ID))
        }

        fun shareText(s: SplitEditorState): String? {
            val lines = summaryLines(s) ?: return null
            val total = totalOf(s) ?: return null
            val date = SimpleDateFormat("d MMM yyyy", Locale.ENGLISH).format(Date(s.billTime))
            val head = "${s.merchant.trim().ifBlank { "Bill" }}, $date"
            val body = lines.joinToString("\n") { (name, amount) ->
                "$name: RM ${AmountFormatter.formatGrouped(amount)}"
            }
            return "$head\n$body\nTotal: RM ${AmountFormatter.formatGrouped(total)}"
        }
    }
}
