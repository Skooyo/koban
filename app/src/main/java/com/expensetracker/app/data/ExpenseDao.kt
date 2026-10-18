package com.expensetracker.app.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow
import java.math.BigDecimal

@Dao
interface ExpenseDao {
    @Query("SELECT * FROM expenses WHERE status != 'DISMISSED' ORDER BY notificationPostTime DESC")
    fun observeAllActive(): Flow<List<ExpenseEntity>>

    @Query("SELECT * FROM expenses WHERE status != 'DISMISSED' AND notificationPostTime >= :since ORDER BY notificationPostTime DESC")
    fun observeSince(since: Long): Flow<List<ExpenseEntity>>

    @Query(
        """
        SELECT * FROM expenses
        WHERE status != 'DISMISSED'
        AND (confidence = 'LOW' OR confidence = 'MEDIUM' OR notificationPostTime >= :last24h)
        ORDER BY notificationPostTime DESC
        """
    )
    fun observeReviewCandidates(last24h: Long): Flow<List<ExpenseEntity>>

    @Query(
        """
        SELECT COALESCE(SUM(
            CASE WHEN transactionType = 'RECEIVE' THEN 0 ELSE COALESCE(countedAmount, amount) END
        ), 0) FROM expenses
        WHERE status != 'DISMISSED'
        AND notificationPostTime >= :start AND notificationPostTime < :end
        """
    )
    fun observeTotalForRange(start: Long, end: Long): Flow<java.math.BigDecimal?>

    /** Money received in the range. Shown beside spending, never subtracted from it. */
    @Query(
        """
        SELECT COALESCE(SUM(amount), 0) FROM expenses
        WHERE status != 'DISMISSED' AND transactionType = 'RECEIVE'
        AND notificationPostTime >= :start AND notificationPostTime < :end
        """
    )
    fun observeReceivedForRange(start: Long, end: Long): Flow<BigDecimal?>

    @Query(
        """
        SELECT * FROM expenses WHERE status != 'DISMISSED'
        AND notificationPostTime >= :start AND notificationPostTime < :end
        ORDER BY notificationPostTime DESC
        """
    )
    fun observeInRange(start: Long, end: Long): Flow<List<ExpenseEntity>>

    @Query(
        """
        SELECT categoryId,
        COALESCE(SUM(
            CASE WHEN transactionType = 'RECEIVE' THEN 0 ELSE COALESCE(countedAmount, amount) END
        ), 0) AS total
        FROM expenses
        WHERE status != 'DISMISSED'
        AND notificationPostTime >= :start AND notificationPostTime < :end
        GROUP BY categoryId
        HAVING total != 0
        ORDER BY total DESC
        """
    )
    fun observeTotalsByCategory(start: Long, end: Long): Flow<List<CategoryTotalRow>>

    @Query(
        """
        SELECT COALESCE(SUM(
            CASE WHEN transactionType = 'RECEIVE' THEN 0 ELSE COALESCE(countedAmount, amount) END
        ), 0) FROM expenses
        WHERE status != 'DISMISSED'
        AND notificationPostTime >= :startOfDay AND notificationPostTime < :endOfDay
        """
    )
    fun observeTotalForDay(startOfDay: Long, endOfDay: Long): Flow<java.math.BigDecimal?>

    @Query("SELECT * FROM expenses WHERE dedupKey = :dedupKey AND notificationPostTime >= :since LIMIT 1")
    suspend fun findByDedupKeySince(dedupKey: String, since: Long): ExpenseEntity?

    /**
     * Package-agnostic duplicate lookup: the same payment can be announced by two different
     * apps (e.g. bank app and wallet app), so only amount, direction and time are compared.
     * [matchMerchant] also compares the merchant (the sender of a RECEIVE).
     */
    @Query(
        """
        SELECT * FROM expenses
        WHERE status != 'DISMISSED'
        AND amount = :amount
        AND transactionType = :transactionType
        AND (:matchMerchant = 0 OR merchant IS :merchant)
        AND notificationPostTime >= :windowStart AND notificationPostTime <= :windowEnd
        ORDER BY notificationPostTime DESC
        LIMIT 1
        """
    )
    suspend fun findByAmountInWindow(
        amount: BigDecimal,
        transactionType: TransactionType,
        matchMerchant: Boolean,
        merchant: String?,
        windowStart: Long,
        windowEnd: Long
    ): ExpenseEntity?

    @Query(
        """
        SELECT * FROM expenses
        WHERE notificationKey = :notificationKey
        AND status != 'DISMISSED'
        LIMIT 1
        """
    )
    suspend fun findByNotificationKey(notificationKey: String): ExpenseEntity?

    /** Active rows of one type since [since] that no split has adjusted yet, newest first. */
    @Query(
        """
        SELECT * FROM expenses
        WHERE status != 'DISMISSED' AND transactionType = :type
        AND countedAmount IS NULL AND notificationPostTime >= :since
        ORDER BY notificationPostTime DESC
        """
    )
    suspend fun getRecentByType(type: TransactionType, since: Long): List<ExpenseEntity>

    @Query("SELECT * FROM expenses WHERE id = :id")
    suspend fun getById(id: String): ExpenseEntity?

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insert(expense: ExpenseEntity): Long

    @Update
    suspend fun update(expense: ExpenseEntity)

    @Query(
        """
        SELECT
            (CAST(strftime('%Y', notificationPostTime / 1000, 'unixepoch', 'localtime') AS INTEGER) * 100
            + CAST(strftime('%m', notificationPostTime / 1000, 'unixepoch', 'localtime') AS INTEGER)) AS yearMonth,
            COALESCE(SUM(
                CASE WHEN transactionType = 'RECEIVE' THEN 0 ELSE COALESCE(countedAmount, amount) END
            ), 0) AS total
        FROM expenses
        WHERE status != 'DISMISSED'
        GROUP BY yearMonth
        ORDER BY yearMonth DESC
        """
    )
    fun observeMonthlyTotals(): Flow<List<MonthTotalRow>>

    @Query(
        """
        SELECT COALESCE(SUM(
            CASE WHEN transactionType = 'RECEIVE' THEN 0 ELSE COALESCE(countedAmount, amount) END
        ), 0) FROM expenses
        WHERE status != 'DISMISSED'
        AND notificationPostTime >= :start AND notificationPostTime < :end
        """
    )
    suspend fun getTotalForRangeOnce(start: Long, end: Long): BigDecimal?
}
