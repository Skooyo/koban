package com.expensetracker.app.data

import androidx.room.withTransaction
import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.parser.CaptureFormat
import com.expensetracker.app.parser.DedupKeyGenerator
import com.expensetracker.app.parser.ParsedExpense
import com.expensetracker.app.parser.PaymentRules
import com.expensetracker.app.parser.RuleMatch
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

enum class ConfirmResult { SAVED, ALREADY_SAVED, DROPPED }

@Singleton
class PendingPaymentRepository @Inject constructor(
    private val db: ExpenseDatabase,
    private val dao: PendingPaymentDao,
    private val expenseRepository: ExpenseRepository
) {
    companion object {
        private const val TAG = "PendingPaymentRepo"
        private const val HOLD_MS = 4000L
        private const val DROP_MARKER_TTL_MS = 30L * 24 * 60 * 60 * 1000

        /** Some apps reuse one notification key for every payment, so a drop marker keys on the post time too. */
        private fun dropKey(notificationKey: String?, postTime: Long) = notificationKey?.let { "$it@$postTime" }
    }

    private class Held(val id: String, val save: Boolean, val job: Job)

    /** Outlives every screen, so a held swipe still commits after the screen closes. */
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /** Keeps capture and commits one at a time, so a dedup check never races a write. */
    private val mutex = Mutex()

    private val holdLock = Any()
    private var held: Held? = null

    /** The held card plus cards whose commit runs now. Hidden so they do not show again. */
    private val hidden = MutableStateFlow<Set<String>>(emptySet())

    private val _lastResult = MutableSharedFlow<ConfirmResult>(extraBufferCapacity = 4)
    val lastResult: SharedFlow<ConfirmResult> = _lastResult.asSharedFlow()

    /** Stores a waiting payment. Returns its id, or null when it duplicates an expense, a waiting payment or a dropped one. */
    suspend fun capture(
        parsed: ParsedExpense,
        format: CaptureFormat,
        rawText: String,
        sourcePackage: String,
        notificationPostTime: Long,
        notificationKey: String?
    ): String? {
        val amount = AmountFormatter.toMoney(parsed.amount)
        val dedupKey = DedupKeyGenerator.generate(sourcePackage, amount, parsed.merchant, notificationPostTime)
        val now = System.currentTimeMillis()

        return mutex.withLock {
            dao.deleteDroppedBefore(now - DROP_MARKER_TTL_MS)

            val isExpense = expenseRepository.hasExpenseFor(
                amount = amount,
                transactionType = parsed.transactionType,
                merchant = parsed.merchant,
                postTime = notificationPostTime,
                dedupKey = dedupKey,
                notificationKey = notificationKey
            )
            if (isExpense) return@withLock null
            if (dao.findByKeys(dedupKey, notificationKey, notificationPostTime) != null) return@withLock null
            val sameAmountWaiting = dao.findByAmountInWindow(
                amount = amount,
                transactionType = parsed.transactionType,
                matchMerchant = parsed.transactionType == TransactionType.RECEIVE,
                merchant = parsed.merchant,
                windowStart = notificationPostTime - ExpenseRepository.AMOUNT_DEDUP_WINDOW_MS,
                windowEnd = notificationPostTime + ExpenseRepository.AMOUNT_DEDUP_WINDOW_MS
            )
            if (sameAmountWaiting != null) return@withLock null
            if (dao.findDropped(dedupKey, dropKey(notificationKey, notificationPostTime)) != null) return@withLock null

            insertCard(parsed, format, rawText, sourcePackage, notificationPostTime, notificationKey, dedupKey, now)
        }
    }

    /**
     * Makes a card for a logged notification the app skipped or missed, when the owner says it is a
     * real payment. No duplicate check applies, now or on save. False when the text has no amount.
     */
    suspend fun forceCapture(sourcePackage: String, rawText: String, notificationPostTime: Long): Boolean {
        val match = PaymentRules.match(sourcePackage, rawText) as? RuleMatch.Matched ?: return false
        mutex.withLock {
            insertCard(
                match.expense, match.format, rawText, sourcePackage, notificationPostTime,
                notificationKey = null,
                dedupKey = ExpenseRepository.FORCED_DEDUP_PREFIX + UUID.randomUUID(),
                now = System.currentTimeMillis()
            )
        }
        return true
    }

    private suspend fun insertCard(
        parsed: ParsedExpense,
        format: CaptureFormat,
        rawText: String,
        sourcePackage: String,
        notificationPostTime: Long,
        notificationKey: String?,
        dedupKey: String,
        now: Long
    ): String {
        val id = UUID.randomUUID().toString()
        dao.insert(
            PendingPaymentEntity(
                id = id,
                amount = AmountFormatter.toMoney(parsed.amount),
                currency = parsed.currency,
                merchant = parsed.merchant,
                transactionType = parsed.transactionType,
                sourcePackage = sourcePackage,
                rawNotificationText = rawText,
                notificationPostTime = notificationPostTime,
                notificationKey = notificationKey,
                dedupKey = dedupKey,
                format = format,
                categoryId = null,
                likelyPromotion = false,
                createdAt = now,
                edited = false,
                directionUnclear = !parsed.directionClear
            )
        )
        return id
    }

    /** Waiting payments, oldest first, without the held one. */
    fun observeWaiting(): Flow<List<PendingPaymentEntity>> =
        combine(dao.observeAll(), hidden) { rows, hide -> rows.filterNot { it.id in hide } }

    fun observeCount(): Flow<Int> = observeWaiting().map { it.size }

    /** Writes a card edit at once. */
    suspend fun update(payment: PendingPaymentEntity) {
        val amount = AmountFormatter.toMoney(payment.amount)
        dao.update(
            payment.copy(
                amount = amount,
                // A forced card keeps its key, so an edit does not bring the duplicate check back.
                dedupKey = if (payment.dedupKey.startsWith(ExpenseRepository.FORCED_DEDUP_PREFIX)) {
                    payment.dedupKey
                } else {
                    DedupKeyGenerator.generate(
                        payment.sourcePackage, amount, payment.merchant, payment.notificationPostTime
                    )
                },
                edited = true
            )
        )
    }

    /** Gemini suggestions. Ignored for a card the owner already edited. */
    suspend fun enrich(id: String, merchant: String?, categoryId: String?, likelyPromotion: Boolean) {
        // A held card is already swiped; the commit must save only what the owner saw.
        if (id in hidden.value) return
        dao.enrich(id, merchant, categoryId, likelyPromotion)
    }

    /** Holds a swipe for the Undo window, then commits it. An earlier hold commits at once. */
    fun hold(id: String, save: Boolean) {
        synchronized(holdLock) {
            val previous = held
            held = null
            if (previous != null) {
                previous.job.cancel()
                // The same card again only replaces the choice; it restarts the window below.
                if (previous.id != id) launchCommit(previous)
            }
            hidden.update { it + id }
            lateinit var entry: Held
            val job = scope.launch(start = CoroutineStart.LAZY) {
                delay(HOLD_MS)
                if (take(entry)) commit(entry)
            }
            entry = Held(id, save, job)
            held = entry
            job.start()
        }
    }

    /** Releases the hold without a write. False when nothing is held. */
    fun undo(): Boolean {
        val entry = synchronized(holdLock) { held.also { held = null } } ?: return false
        entry.job.cancel()
        hidden.update { it - entry.id }
        return true
    }

    /** Commits the hold now. Safe to call again and when nothing is held. */
    fun flushHold() {
        val entry = synchronized(holdLock) { held.also { held = null } } ?: return
        entry.job.cancel()
        launchCommit(entry)
    }

    /** True when [entry] is still the hold; clears it, so only one caller commits it. */
    private fun take(entry: Held): Boolean = synchronized(holdLock) {
        if (held === entry) {
            held = null
            true
        } else {
            false
        }
    }

    private fun launchCommit(entry: Held) {
        scope.launch { commit(entry) }
    }

    private suspend fun commit(entry: Held) {
        try {
            val result = mutex.withLock {
                val payment = dao.getById(entry.id) ?: return@withLock null
                if (entry.save) {
                    val inserted = expenseRepository.saveConfirmed(payment)
                    // An expense covers it in both outcomes, so the card goes.
                    dao.deleteById(payment.id)
                    if (inserted) ConfirmResult.SAVED else ConfirmResult.ALREADY_SAVED
                } else {
                    db.withTransaction {
                        dao.insertDropped(
                            DroppedNotificationEntity(
                                dedupKey = payment.dedupKey,
                                notificationKey = dropKey(payment.notificationKey, payment.notificationPostTime),
                                droppedAt = System.currentTimeMillis()
                            )
                        )
                        dao.deleteById(payment.id)
                    }
                    ConfirmResult.DROPPED
                }
            }
            if (result != null) _lastResult.emit(result)
        } catch (e: Exception) {
            // The row stays, so the card shows again and the owner can swipe it again.
            android.util.Log.e(TAG, "Commit of waiting payment failed", e)
        } finally {
            hidden.update { it - entry.id }
        }
    }
}
