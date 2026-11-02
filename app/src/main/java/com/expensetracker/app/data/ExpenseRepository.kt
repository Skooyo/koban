package com.expensetracker.app.data

import com.expensetracker.app.parser.AmountFormatter
import com.expensetracker.app.parser.DedupKeyGenerator
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.math.BigDecimal
import java.math.RoundingMode
import java.util.Calendar
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ExpenseRepository @Inject constructor(
    private val expenseDao: ExpenseDao,
    private val categoryRepository: CategoryRepository,
    private val merchantCategoryRepository: MerchantCategoryRepository,
    private val splitRepository: SplitRepository
) {
    companion object {
        private const val TAG = "ExpenseRepository"
        const val MANUAL_SOURCE = "manual"
        private const val RECENT_IN_PERIOD = 5

        /** How far either side of a notification the same amount counts as the same payment. */
        const val AMOUNT_DEDUP_WINDOW_MS = 5 * 60 * 1000L
    }

    /** Serialises dedup check + insert so two racing saves cannot both pass the check. */
    private val saveMutex = Mutex()

    fun observeAllActive(): Flow<List<ExpenseEntity>> = expenseDao.observeAllActive()

    fun observeTotalForRange(start: Long, end: Long): Flow<BigDecimal?> =
        expenseDao.observeTotalForRange(start, end)

    fun observeReceivedForRange(start: Long, end: Long): Flow<BigDecimal?> =
        expenseDao.observeReceivedForRange(start, end)

    fun observeInRange(start: Long, end: Long): Flow<List<ExpenseEntity>> =
        expenseDao.observeInRange(start, end)

    fun observeMonthlySummaries(): Flow<List<MonthSummary>> {
        return expenseDao.observeMonthlyTotals().map { rows ->
            rows.map { row ->
                val (year, month) = PeriodCalculator.decodeYearMonth(row.yearMonth)
                MonthSummary(
                    year = year,
                    month = month,
                    label = PeriodCalculator.monthLabel(year, month),
                    total = row.total,
                    received = row.received
                )
            }
        }
    }

    suspend fun weekSummariesForMonth(year: Int, month: Int): List<WeekSummary> {
        val weeks = PeriodCalculator.weeksInMonth(year, month)
        return weeks.map { (start, end) ->
            WeekSummary(
                startMs = start,
                endMs = end,
                label = PeriodCalculator.weekLabel(start, end),
                total = getTotalForRangeOnce(start, end)
            )
        }
    }

    fun observeCurrentPeriodSummary(period: SpendingPeriod): Flow<PeriodSummary> {
        val (start, end) = PeriodCalculator.range(period)
        val anchor = Calendar.getInstance()
        return combine(
            expenseDao.observeTotalForRange(start, end),
            observeCategoryBreakdown(start, end),
            expenseDao.observeInRange(start, end),
            expenseDao.observeReceivedForRange(start, end)
        ) { total, breakdown, expenses, received ->
            PeriodSummary(
                title = PeriodCalculator.title(period),
                subtitle = PeriodCalculator.label(period, anchor),
                total = total ?: BigDecimal.ZERO,
                breakdown = breakdown,
                recentExpenses = expenses.take(RECENT_IN_PERIOD),
                periodStart = start,
                periodEnd = end,
                received = received ?: BigDecimal.ZERO
            )
        }
    }

    fun observeCategoryBreakdown(start: Long, end: Long): Flow<List<CategoryBreakdown>> {
        return combine(
            expenseDao.observeTotalsByCategory(start, end),
            categoryRepository.observeAll()
        ) { rows, categories ->
            val categoryMap = categories.associateBy { it.id }
            val absSum = rows.fold(BigDecimal.ZERO) { acc, row -> acc + row.total.abs() }
            rows.map { row ->
                val category = row.categoryId?.let { categoryMap[it] }
                val name = category?.name ?: DefaultCategories.UNCATEGORIZED_NAME
                val color = category?.colorHex ?: DefaultCategories.UNCATEGORIZED_COLOR
                val fraction = if (absSum > BigDecimal.ZERO) {
                    row.total.abs().divide(absSum, 4, RoundingMode.HALF_UP).toFloat()
                } else {
                    0f
                }
                CategoryBreakdown(
                    categoryId = row.categoryId,
                    name = name,
                    colorHex = color,
                    total = row.total,
                    fraction = fraction
                )
            }
        }
    }

    /**
     * True when an expense already covers this payment: same notification, same dedup key
     * near [postTime], or the same amount and direction within the amount window.
     */
    suspend fun hasExpenseFor(
        amount: BigDecimal,
        transactionType: TransactionType,
        merchant: String?,
        postTime: Long,
        dedupKey: String,
        notificationKey: String?
    ): Boolean {
        if (notificationKey != null && expenseDao.findByNotificationKey(notificationKey, postTime) != null) return true
        val lookback = postTime - DedupKeyGenerator.dedupLookbackMs()
        if (expenseDao.findByDedupKeySince(dedupKey, lookback) != null) return true
        return expenseDao.findByAmountInWindow(
            amount = AmountFormatter.toMoney(amount),
            transactionType = transactionType,
            // Two transfers of one amount from different senders are not duplicates.
            matchMerchant = transactionType == TransactionType.RECEIVE,
            merchant = merchant,
            windowStart = postTime - AMOUNT_DEDUP_WINDOW_MS,
            windowEnd = postTime + AMOUNT_DEDUP_WINDOW_MS
        ) != null
    }

    /** Saves a waiting payment the owner confirmed, with the card's values. False when it already exists. */
    suspend fun saveConfirmed(payment: PendingPaymentEntity): Boolean {
        val amount = AmountFormatter.toMoney(payment.amount)

        return saveMutex.withLock {
            val duplicate = hasExpenseFor(
                amount = amount,
                transactionType = payment.transactionType,
                merchant = payment.merchant,
                postTime = payment.notificationPostTime,
                dedupKey = payment.dedupKey,
                notificationKey = payment.notificationKey
            )
            if (duplicate) return@withLock false

            // The card's category wins over the merchant memory.
            val categoryId = payment.categoryId
                ?: merchantCategoryRepository.categoryIdForMerchant(payment.merchant)

            val entity = ExpenseEntity(
                id = UUID.randomUUID().toString(),
                amount = amount,
                currency = payment.currency,
                merchant = payment.merchant,
                rawNotificationText = payment.rawNotificationText,
                sourcePackage = payment.sourcePackage,
                notificationPostTime = payment.notificationPostTime,
                createdAt = System.currentTimeMillis(),
                dedupKey = payment.dedupKey,
                status = if (payment.edited) ExpenseStatus.EDITED else ExpenseStatus.AUTO_SAVED,
                // The owner checked this payment.
                confidence = ParseConfidence.HIGH,
                notificationKey = payment.notificationKey,
                categoryId = categoryId,
                notes = null,
                transactionType = payment.transactionType
            )
            val inserted = expenseDao.insert(entity) != -1L
            if (inserted && payment.edited) {
                merchantCategoryRepository.saveMapping(payment.merchant, categoryId)
            }
            if (inserted && entity.transactionType == TransactionType.RECEIVE) {
                try {
                    splitRepository.suggestRepayment(entity)
                } catch (e: Exception) {
                    android.util.Log.w(TAG, "Repayment suggestion failed", e)
                }
            }
            inserted
        }
    }

    suspend fun updateExpense(
        id: String,
        amount: BigDecimal,
        merchant: String?,
        notificationPostTime: Long,
        categoryId: String?,
        notes: String?,
        transactionType: TransactionType
    ) {
        val existing = expenseDao.getById(id) ?: return
        merchantCategoryRepository.saveMapping(merchant, categoryId)
        // A new category applies to every payment from this merchant in the same direction, past ones included.
        if (categoryId != null && categoryId != existing.categoryId) {
            merchantCategoryRepository.normalizeKey(merchant)?.let {
                expenseDao.setCategoryForMerchant(it, transactionType, categoryId)
            }
        }
        expenseDao.update(
            existing.copy(
                amount = AmountFormatter.toMoney(amount),
                merchant = merchant,
                notificationPostTime = notificationPostTime,
                categoryId = categoryId,
                notes = notes?.trim()?.ifBlank { null },
                transactionType = transactionType,
                status = ExpenseStatus.EDITED
            )
        )
        try {
            splitRepository.onExpenseEdited(id)
        } catch (e: Exception) {
            android.util.Log.w(TAG, "Split recompute failed", e)
        }
    }

    /** A payment the owner types in, for one that came without a readable notification. */
    suspend fun addManualExpense(
        amount: BigDecimal,
        merchant: String?,
        notificationPostTime: Long,
        categoryId: String?,
        notes: String?,
        transactionType: TransactionType
    ) {
        merchantCategoryRepository.saveMapping(merchant, categoryId)
        if (categoryId != null) {
            merchantCategoryRepository.normalizeKey(merchant)?.let {
                expenseDao.setCategoryForMerchant(it, transactionType, categoryId)
            }
        }
        val id = UUID.randomUUID().toString()
        val entity = ExpenseEntity(
            id = id,
            amount = AmountFormatter.toMoney(amount),
            currency = "MYR",
            merchant = merchant?.trim()?.ifBlank { null },
            rawNotificationText = "",
            sourcePackage = MANUAL_SOURCE,
            notificationPostTime = notificationPostTime,
            createdAt = System.currentTimeMillis(),
            dedupKey = "manual:$id",
            status = ExpenseStatus.EDITED,
            confidence = ParseConfidence.HIGH,
            notificationKey = null,
            categoryId = categoryId,
            notes = notes?.trim()?.ifBlank { null },
            transactionType = transactionType
        )
        expenseDao.insert(entity)
        if (transactionType == TransactionType.RECEIVE) {
            try {
                splitRepository.suggestRepayment(entity)
            } catch (e: Exception) {
                android.util.Log.w(TAG, "Repayment suggestion failed", e)
            }
        }
    }

    suspend fun getById(id: String): ExpenseEntity? = expenseDao.getById(id)

    suspend fun dismissExpense(id: String) {
        val existing = expenseDao.getById(id) ?: return
        expenseDao.update(existing.copy(status = ExpenseStatus.DISMISSED))
    }

    private suspend fun getTotalForRangeOnce(start: Long, end: Long): BigDecimal {
        return expenseDao.getTotalForRangeOnce(start, end) ?: BigDecimal.ZERO
    }
}
