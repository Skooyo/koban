package com.expensetracker.app.data

import androidx.room.withTransaction
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.math.BigDecimal
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

data class DraftItem(
    val name: String,
    val quantity: Int,
    /** Line price: what the whole line costs. */
    val price: BigDecimal,
    val sharedBy: Set<String>
)

/** [people] excludes Me. Item [DraftItem.sharedBy] holds person ids from [people], or [ME_ID]. */
data class SplitDraft(
    val billId: String?,
    val merchant: String?,
    val billTime: Long,
    val currency: String,
    val printedTotal: BigDecimal?,
    val items: List<DraftItem>,
    val charges: SplitCharges,
    val people: List<SplitPersonEntity>,
    val linkedExpenseId: String?
)

data class OpenDebtView(
    val debt: SplitDebtEntity,
    val personName: String,
    val billMerchant: String?,
    val billTime: Long,
    val suggestedRepayment: ExpenseEntity?
)

@Singleton
class SplitRepository @Inject constructor(
    private val db: ExpenseDatabase,
    private val splitDao: SplitDao,
    private val expenseDao: ExpenseDao
) {
    companion object {
        private const val PAYMENT_WINDOW_MS = 3 * 24 * 60 * 60 * 1000L
        private const val REPAYMENT_LEAD_MS = 24 * 60 * 60 * 1000L
        private val ZERO_MONEY = BigDecimal("0.00")
    }

    fun observeBills(): Flow<List<SplitBillEntity>> = splitDao.observeBills()

    fun observeRecentPeople(): Flow<List<SplitPersonEntity>> = splitDao.observePeople()

    fun observeOpenDebts(): Flow<List<OpenDebtView>> =
        splitDao.observeOpenDebts().map { rows ->
            rows.mapNotNull { row ->
                val debt = splitDao.getDebt(row.debtId) ?: return@mapNotNull null
                OpenDebtView(
                    debt = debt,
                    personName = row.personName,
                    billMerchant = row.merchant,
                    billTime = row.billTime,
                    suggestedRepayment = debt.suggestedRepaymentExpenseId?.let { expenseDao.getById(it) }
                )
            }
        }

    suspend fun billForExpense(expenseId: String): SplitBillEntity? = splitDao.getBillByLinkedExpense(expenseId)

    suspend fun isLocked(billId: String): Boolean =
        splitDao.getDebts(billId).any { it.status == DebtStatus.PAID }

    suspend fun loadDraft(billId: String): SplitDraft? {
        val bill = splitDao.getBill(billId) ?: return null
        val items = splitDao.getItems(billId)
        val sharesByItem = splitDao.getShares(billId).groupBy({ it.itemId }, { it.personId })
        val peopleById = splitDao.getAllPeopleIncludingArchived().associateBy { it.id }
        val usedIds = (sharesByItem.values.flatten() + splitDao.getDebts(billId).map { it.personId })
            .toSet() - ME_ID
        return SplitDraft(
            billId = bill.id,
            merchant = bill.merchant,
            billTime = bill.billTime,
            currency = bill.currency,
            printedTotal = bill.printedTotal,
            items = items.map {
                DraftItem(it.name, it.quantity, it.price, sharesByItem[it.id].orEmpty().toSet())
            },
            charges = SplitCharges(bill.serviceCharge, bill.tax, bill.discount, bill.rounding),
            people = usedIds.mapNotNull { peopleById[it] },
            linkedExpenseId = bill.linkedExpenseId
        )
    }

    suspend fun saveSplit(draft: SplitDraft): String = db.withTransaction {
        val billId = draft.billId ?: UUID.randomUUID().toString()
        val existing = draft.billId?.let { splitDao.getBill(it) }
        if (existing != null && isLocked(billId)) {
            throw IllegalStateException("This split already has a repayment, so it can't change.")
        }
        val now = System.currentTimeMillis()

        // Map each draft person id to a stored person by normalized name. A match revives an archived person.
        val stored = splitDao.getAllPeopleIncludingArchived().sortedBy { it.archived }.toMutableList()
        val idMap = mutableMapOf(ME_ID to ME_ID)
        for (person in draft.people) {
            val name = person.name.trim()
            val key = PeopleMath.normalizedName(name)
            val match = stored.firstOrNull { PeopleMath.normalizedName(it.name) == key }
            val resolved = (match ?: SplitPersonEntity(UUID.randomUUID().toString(), name, now))
                .copy(lastUsedAt = now, archived = false)
            splitDao.upsertPerson(resolved)
            if (match == null) stored.add(resolved)
            idMap[person.id] = resolved.id
        }

        val oldDebtPeople = splitDao.getDebts(billId).map { it.personId }
        splitDao.deleteSharesByBill(billId)
        splitDao.deleteItemsByBill(billId)
        splitDao.deleteDebtsByBill(billId)

        val itemEntities = draft.items.mapIndexed { index, item ->
            SplitItemEntity(UUID.randomUUID().toString(), billId, item.name, item.quantity, item.price, index)
        }
        val shareEntities = draft.items.flatMapIndexed { index, item ->
            item.sharedBy.map { SplitItemShareEntity(itemEntities[index].id, idMap.getValue(it)) }
        }
        val inputs = draft.items.map { item ->
            SplitItemInput(item.price, item.sharedBy.map { idMap.getValue(it) }.toSet())
        }
        val debts = SplitMath.shares(inputs, draft.charges)
            .filter { (person, amount) -> person != ME_ID && amount.signum() != 0 }
            .map { (person, amount) ->
                SplitDebtEntity(
                    id = UUID.randomUUID().toString(),
                    billId = billId,
                    personId = person,
                    amount = amount,
                    status = DebtStatus.OPEN,
                    repaymentExpenseId = null,
                    suggestedRepaymentExpenseId = null,
                    paidAt = null
                )
            }

        splitDao.insertBill(
            SplitBillEntity(
                id = billId,
                merchant = draft.merchant,
                billTime = draft.billTime,
                currency = draft.currency,
                printedTotal = draft.printedTotal,
                serviceCharge = draft.charges.serviceCharge,
                tax = draft.charges.tax,
                discount = draft.charges.discount,
                rounding = draft.charges.rounding,
                linkedExpenseId = existing?.linkedExpenseId,
                createdAt = existing?.createdAt ?: now
            )
        )
        splitDao.insertItems(itemEntities)
        splitDao.insertShares(shareEntities)
        splitDao.insertDebts(debts)
        (oldDebtPeople + debts.map { it.personId }).toSet().forEach { clearSettleSuggestion(it) }

        applyLink(billId, draft.linkedExpenseId)
        billId
    }

    suspend fun linkPayment(billId: String, expenseId: String?) {
        db.withTransaction { applyLink(billId, expenseId) }
    }

    /** Moves the bill's link to [expenseId], clears the old expense, and recomputes the new one. */
    private suspend fun applyLink(billId: String, expenseId: String?) {
        val bill = splitDao.getBill(billId) ?: return
        val oldId = bill.linkedExpenseId
        if (expenseId != null && splitDao.getBillByLinkedExpense(expenseId)?.id.let { it != null && it != billId }) {
            throw IllegalStateException("This payment already belongs to another split.")
        }
        if (oldId != null && oldId != expenseId) {
            expenseDao.getById(oldId)?.let { expenseDao.update(it.copy(countedAmount = null)) }
        }
        if (oldId != expenseId) splitDao.insertBill(bill.copy(linkedExpenseId = expenseId))
        if (expenseId != null) recomputeCounted(billId, expenseId)
    }

    private suspend fun recomputeCounted(billId: String, expenseId: String) {
        val expense = expenseDao.getById(expenseId) ?: return
        val owed = splitDao.getDebts(billId).fold(BigDecimal.ZERO) { sum, d -> sum + d.amount }
        expenseDao.update(expense.copy(countedAmount = SplitMath.ownerSpending(expense.amount, owed)))
    }

    suspend fun onExpenseEdited(expenseId: String) {
        db.withTransaction {
            splitDao.getBillByLinkedExpense(expenseId)?.let { recomputeCounted(it.id, expenseId) }
        }
    }

    suspend fun deleteSplit(billId: String) {
        db.withTransaction {
            val bill = splitDao.getBill(billId) ?: return@withTransaction
            val debts = splitDao.getDebts(billId)
            val repaymentIds = debts.mapNotNull { it.repaymentExpenseId }
            splitDao.deleteSharesByBill(billId)
            splitDao.deleteItemsByBill(billId)
            splitDao.deleteDebtsByBill(billId)
            debts.filter { it.status == DebtStatus.OPEN }.map { it.personId }.toSet()
                .forEach { clearSettleSuggestion(it) }
            splitDao.deleteBill(billId)
            // A repayment that still pays a debt in another bill stays used.
            val freed = repaymentIds.filter { splitDao.getDebtsByRepayment(it).isEmpty() }
            for (id in (listOfNotNull(bill.linkedExpenseId) + freed).distinct()) {
                expenseDao.getById(id)?.let { expenseDao.update(it.copy(countedAmount = null)) }
            }
        }
    }

    /** Unlinked withdrawals within 3 days of the bill: exact-amount ones first, newest first. */
    suspend fun paymentCandidates(billId: String?, total: BigDecimal, billTime: Long): List<ExpenseEntity> =
        expenseDao.getRecentByType(TransactionType.WITHDRAW, billTime - PAYMENT_WINDOW_MS)
            .filter { it.notificationPostTime <= billTime + PAYMENT_WINDOW_MS }
            .filter { splitDao.getBillByLinkedExpense(it.id).let { b -> b == null || b.id == billId } }
            .partition { it.amount.compareTo(total) == 0 }
            .let { it.first + it.second }

    suspend fun repaymentCandidates(debtId: String): List<ExpenseEntity> {
        val debt = splitDao.getDebt(debtId) ?: return emptyList()
        val bill = splitDao.getBill(debt.billId) ?: return emptyList()
        val personOpen = splitDao.getOpenDebts().filter { it.personId == debt.personId }
            .fold(BigDecimal.ZERO) { sum, d -> sum + d.amount }
        return expenseDao.getRecentByType(TransactionType.RECEIVE, bill.billTime - REPAYMENT_LEAD_MS).filter {
            it.amount.compareTo(debt.amount) == 0 || it.amount.compareTo(personOpen) == 0
        }
    }

    suspend fun markPaid(debtId: String, repaymentExpenseId: String?) {
        db.withTransaction {
            val debt = splitDao.getDebt(debtId) ?: return@withTransaction
            if (debt.status == DebtStatus.PAID) return@withTransaction
            if (repaymentExpenseId == null) {
                close(listOf(debt), null)
                return@withTransaction
            }
            val expense = expenseDao.getById(repaymentExpenseId)
            if (expense == null || !isUsableRepayment(expense)) {
                throw IllegalArgumentException("Repayment expense is not available")
            }
            val personOpen = splitDao.getOpenDebts().filter { it.personId == debt.personId }
            val total = personOpen.fold(BigDecimal.ZERO) { sum, d -> sum + d.amount }
            val closing = when {
                expense.amount.compareTo(total) == 0 -> personOpen
                expense.amount.compareTo(debt.amount) == 0 -> listOf(debt)
                else -> throw IllegalArgumentException("Repayment amount does not match this debt")
            }
            close(closing, expense)
        }
    }

    suspend fun confirmSuggestion(debtId: String) {
        db.withTransaction {
            val expenseId = splitDao.getDebt(debtId)?.suggestedRepaymentExpenseId ?: return@withTransaction
            val debts = suggestedWith(expenseId)
            val expense = expenseDao.getById(expenseId)
            val owed = debts.fold(BigDecimal.ZERO) { sum, d -> sum + d.amount }
            if (expense == null || !isUsableRepayment(expense) || expense.amount.compareTo(owed) != 0) {
                // Stale suggestion: the receive changed or was used. Clear it, do not close.
                debts.forEach { splitDao.updateDebt(it.copy(suggestedRepaymentExpenseId = null)) }
                return@withTransaction
            }
            close(debts, expense)
        }
    }

    internal fun isUsableRepayment(expense: ExpenseEntity): Boolean =
        expense.transactionType == TransactionType.RECEIVE &&
            expense.status != ExpenseStatus.DISMISSED &&
            expense.countedAmount == null

    suspend fun dismissSuggestion(debtId: String) {
        db.withTransaction {
            val expenseId = splitDao.getDebt(debtId)?.suggestedRepaymentExpenseId ?: return@withTransaction
            suggestedWith(expenseId).forEach {
                splitDao.updateDebt(it.copy(suggestedRepaymentExpenseId = null))
            }
        }
    }

    private suspend fun suggestedWith(expenseId: String): List<SplitDebtEntity> =
        splitDao.getOpenDebts().filter { it.suggestedRepaymentExpenseId == expenseId }

    /** Closes every open debt of [personId]. A non-null [expense] is marked used even when no debt is open. */
    internal suspend fun closeAllFor(personId: String, expense: ExpenseEntity?) {
        db.withTransaction {
            close(splitDao.getOpenDebtsFor(personId), expense)
            clearSettleSuggestion(personId)
        }
    }

    internal suspend fun clearSettleSuggestion(personId: String) {
        val person = splitDao.getPerson(personId) ?: return
        if (person.suggestedSettleExpenseId == null) return
        splitDao.upsertPerson(person.copy(suggestedSettleExpenseId = null))
    }

    /** Marks [debts] PAID. A null [expense] means cash. */
    private suspend fun close(debts: List<SplitDebtEntity>, expense: ExpenseEntity?) {
        val now = System.currentTimeMillis()
        // A settle suggestion goes stale when its person's debts change or its expense gets used.
        val personIds = debts.map { it.personId }.toSet()
        splitDao.getAllPeopleIncludingArchived()
            .filter { it.suggestedSettleExpenseId != null }
            .filter { it.id in personIds || (expense != null && it.suggestedSettleExpenseId == expense.id) }
            .forEach { splitDao.upsertPerson(it.copy(suggestedSettleExpenseId = null)) }
        // Other open debts must not keep a suggestion that this close made stale.
        val staleIds = debts.mapNotNull { it.suggestedRepaymentExpenseId }.toSet() +
            listOfNotNull(expense?.id)
        val closingIds = debts.map { it.id }.toSet()
        splitDao.getOpenDebts()
            .filter { it.id !in closingIds && it.suggestedRepaymentExpenseId in staleIds }
            .forEach { splitDao.updateDebt(it.copy(suggestedRepaymentExpenseId = null)) }
        debts.forEach {
            splitDao.updateDebt(
                it.copy(
                    status = DebtStatus.PAID,
                    repaymentExpenseId = expense?.id,
                    suggestedRepaymentExpenseId = null,
                    paidAt = now
                )
            )
        }
        // Zero marks the receive as used so it is not offered again. Totals count spending only.
        expense?.let { expenseDao.update(it.copy(countedAmount = ZERO_MONEY)) }
    }

    suspend fun suggestRepayment(receive: ExpenseEntity) {
        if (receive.transactionType != TransactionType.RECEIVE) return
        db.withTransaction {
            val allOpen = splitDao.getOpenDebts()
            val open = allOpen.filter { it.suggestedRepaymentExpenseId == null }
            val people = splitDao.getAllPeopleIncludingArchived()
            val names = people.associate { it.id to it.name }
            val billTimes = open.map { it.billId }.distinct()
                .associateWith { splitDao.getBill(it)?.billTime ?: Long.MAX_VALUE }
            val refs = open.sortedBy { billTimes.getValue(it.billId) }.map {
                OpenDebtRef(it.id, it.personId, names[it.personId].orEmpty(), it.amount)
            }
            val matched = RepaymentMatcher.match(receive.amount, receive.merchant, refs).toSet()
            open.filter { it.id in matched }.forEach {
                splitDao.updateDebt(it.copy(suggestedRepaymentExpenseId = receive.id))
            }
            if (matched.isNotEmpty()) return@withTransaction

            // No subset of debts fits: offer a settle up to the one person whose whole net equals the amount.
            val debtsByPerson = allOpen.groupBy { it.personId }
            val candidates = people
                .filter { !it.archived && it.suggestedSettleExpenseId == null && it.id in debtsByPerson }
                .map { person ->
                    PeopleMath.SettleCandidate(
                        person.id,
                        person.name,
                        PeopleMath.net(
                            debtsByPerson.getValue(person.id).map { it.amount },
                            splitDao.getOpenOwedItems(person.id).map { it.amount }
                        )
                    )
                }
            val personId = PeopleMath.settleMatch(receive.amount, receive.merchant, candidates)
                ?: return@withTransaction
            people.first { it.id == personId }.let {
                splitDao.upsertPerson(it.copy(suggestedSettleExpenseId = receive.id))
            }
        }
    }
}
