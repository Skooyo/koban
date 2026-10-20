package com.expensetracker.app.data

import android.net.Uri
import androidx.room.withTransaction
import com.expensetracker.app.parser.AmountFormatter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import java.math.BigDecimal
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

data class PersonSummary(val person: SplitPersonEntity, val balance: Balance, val hasOpen: Boolean)

data class PersonDetail(
    val person: SplitPersonEntity,
    val balance: Balance,
    val owedToMe: List<OpenDebtView>,
    val iOwe: List<OwedItemEntity>,
    val settleSuggestion: ExpenseEntity?
)

/** The contact book: people, what is open both ways, their QR, and settling up. */
@Singleton
class PeopleRepository @Inject constructor(
    private val db: ExpenseDatabase,
    private val splitDao: SplitDao,
    private val expenseDao: ExpenseDao,
    private val splitRepository: SplitRepository,
    private val qrStore: QrStore
) {
    fun observePeople(): Flow<List<PersonSummary>> =
        combine(
            splitDao.observeAllPeople(),
            splitDao.observeOpenDebts(),
            splitDao.observeAllOpenOwedItems()
        ) { people, debts, items ->
            val owedByPerson = debts.groupBy({ it.personId }, { it.amount })
            val iOweByPerson = items.groupBy({ it.personId }, { it.amount })
            people.map { person ->
                val owed = owedByPerson[person.id].orEmpty()
                val iOwe = iOweByPerson[person.id].orEmpty()
                PersonSummary(person, PeopleMath.balance(owed, iOwe), owed.isNotEmpty() || iOwe.isNotEmpty())
            }
        }

    /** Emits null when the person is missing or archived. */
    fun observePerson(personId: String): Flow<PersonDetail?> =
        combine(
            splitDao.observePerson(personId),
            splitRepository.observeOpenDebts().map { all -> all.filter { it.debt.personId == personId } },
            splitDao.observeOwedItems(personId)
        ) { person, debts, items ->
            if (person == null || person.archived) return@combine null
            PersonDetail(
                person = person,
                balance = PeopleMath.balance(debts.map { it.debt.amount }, items.map { it.amount }),
                owedToMe = debts,
                iOwe = items,
                settleSuggestion = person.suggestedSettleExpenseId?.let { expenseDao.getById(it) }
            )
        }

    /** Returns the id of the person with this name, reviving an archived one, or of a new person. */
    suspend fun addPerson(name: String): String = db.withTransaction {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) throw IllegalArgumentException("Enter a name.")
        val now = System.currentTimeMillis()
        val key = PeopleMath.normalizedName(trimmed)
        val match = splitDao.getAllPeopleIncludingArchived()
            .sortedBy { it.archived }
            .firstOrNull { PeopleMath.normalizedName(it.name) == key }
        when {
            match == null -> SplitPersonEntity(UUID.randomUUID().toString(), trimmed, now)
                .also { splitDao.upsertPerson(it) }.id
            match.archived -> match.also { splitDao.upsertPerson(it.copy(archived = false, lastUsedAt = now)) }.id
            else -> match.id
        }
    }

    suspend fun renamePerson(personId: String, name: String) {
        db.withTransaction {
            val trimmed = name.trim()
            if (trimmed.isEmpty()) throw IllegalArgumentException("Enter a name.")
            val person = splitDao.getPerson(personId) ?: return@withTransaction
            val key = PeopleMath.normalizedName(trimmed)
            if (splitDao.getPeople().any { it.id != personId && PeopleMath.normalizedName(it.name) == key }) {
                throw IllegalArgumentException("Someone already has that name.")
            }
            splitDao.upsertPerson(person.copy(name = trimmed))
        }
    }

    suspend fun archivePerson(personId: String) {
        val qrPath = db.withTransaction {
            val person = splitDao.getPerson(personId) ?: return@withTransaction null
            if (splitDao.getOpenDebtsFor(personId).isNotEmpty() || splitDao.getOpenOwedItems(personId).isNotEmpty()) {
                throw IllegalStateException("Settle up with them first.")
            }
            splitDao.deletePaidOwedItems(personId)
            splitDao.upsertPerson(person.copy(archived = true, qrPath = null, suggestedSettleExpenseId = null))
            person.qrPath
        }
        // Delete the file only after the row no longer points at it.
        withContext(Dispatchers.IO) { qrStore.delete(qrPath) }
    }

    suspend fun setQr(personId: String, uri: Uri) {
        if (splitDao.getPerson(personId) == null) return
        val path = withContext(Dispatchers.IO) { qrStore.importQr(personId, uri) }
        db.withTransaction {
            val person = splitDao.getPerson(personId) ?: return@withTransaction
            splitDao.upsertPerson(person.copy(qrPath = path))
        }
    }

    suspend fun saveQrToGallery(personId: String): Uri {
        val person = splitDao.getPerson(personId)
        val path = person?.qrPath ?: throw IllegalStateException("No QR saved yet")
        val displayName = "koban-${person.name.replace(Regex("[^\\p{L}]"), "-")}-qr.jpg"
        return withContext(Dispatchers.IO) { qrStore.saveToGallery(path, displayName) }
    }

    suspend fun addOwedItem(personId: String, description: String, amount: BigDecimal, itemDate: Long) {
        validateOwedItem(description, amount)
        db.withTransaction {
            splitDao.insertOwedItem(
                OwedItemEntity(
                    id = UUID.randomUUID().toString(),
                    personId = personId,
                    description = description.trim(),
                    amount = AmountFormatter.toMoney(amount),
                    itemDate = itemDate,
                    createdAt = System.currentTimeMillis(),
                    status = DebtStatus.OPEN,
                    paidAt = null
                )
            )
            splitRepository.clearSettleSuggestion(personId)
        }
    }

    suspend fun updateOwedItem(item: OwedItemEntity) {
        validateOwedItem(item.description, item.amount)
        db.withTransaction {
            splitDao.updateOwedItem(
                item.copy(description = item.description.trim(), amount = AmountFormatter.toMoney(item.amount))
            )
            splitRepository.clearSettleSuggestion(item.personId)
        }
    }

    suspend fun deleteOwedItem(id: String) {
        db.withTransaction {
            val item = splitDao.getOwedItem(id) ?: return@withTransaction
            splitDao.deleteOwedItem(id)
            splitRepository.clearSettleSuggestion(item.personId)
        }
    }

    suspend fun markOwedItemPaid(id: String) {
        db.withTransaction {
            val item = splitDao.getOwedItem(id) ?: return@withTransaction
            if (item.status == DebtStatus.PAID) return@withTransaction
            splitDao.updateOwedItem(item.copy(status = DebtStatus.PAID, paidAt = System.currentTimeMillis()))
            splitRepository.clearSettleSuggestion(item.personId)
        }
    }

    suspend fun settleUp(personId: String) {
        db.withTransaction { settle(personId, null) }
    }

    /**
     * Settles up with the suggested RECEIVE linked. Returns false and closes nothing when there is no
     * suggestion or it is stale (the receive changed, was used, or the net moved); a stale one is cleared.
     */
    suspend fun confirmSettleSuggestion(personId: String): Boolean =
        db.withTransaction {
            val expenseId = splitDao.getPerson(personId)?.suggestedSettleExpenseId ?: return@withTransaction false
            val expense = expenseDao.getById(expenseId)
            val net = PeopleMath.net(
                splitDao.getOpenDebtsFor(personId).map { it.amount },
                splitDao.getOpenOwedItems(personId).map { it.amount }
            )
            if (expense == null || !splitRepository.isUsableRepayment(expense) || expense.amount.compareTo(net) != 0) {
                splitRepository.clearSettleSuggestion(personId)
                return@withTransaction false
            }
            settle(personId, expense)
            true
        }

    suspend fun dismissSettleSuggestion(personId: String) {
        db.withTransaction { splitRepository.clearSettleSuggestion(personId) }
    }

    /** Closes everything open for [personId]. Only split debts get the [expense] link. Call inside a transaction. */
    private suspend fun settle(personId: String, expense: ExpenseEntity?) {
        splitRepository.closeAllFor(personId, expense)
        val now = System.currentTimeMillis()
        splitDao.getOpenOwedItems(personId).forEach {
            splitDao.updateOwedItem(it.copy(status = DebtStatus.PAID, paidAt = now))
        }
    }

    private fun validateOwedItem(description: String, amount: BigDecimal) {
        if (description.isBlank()) throw IllegalArgumentException("Enter what it was for.")
        if (amount.signum() <= 0) throw IllegalArgumentException("Enter an amount above zero.")
    }
}
