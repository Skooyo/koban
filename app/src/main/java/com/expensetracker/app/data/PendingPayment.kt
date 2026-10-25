package com.expensetracker.app.data

import androidx.room.ColumnInfo
import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Index
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Update
import com.expensetracker.app.parser.CaptureFormat
import kotlinx.coroutines.flow.Flow
import java.math.BigDecimal

/** A captured payment that waits for the owner to save or drop it. Never counts in any total. */
@Entity(tableName = "pending_payments", indices = [Index("notificationKey")])
data class PendingPaymentEntity(
    @PrimaryKey val id: String,
    val amount: BigDecimal,
    val currency: String,
    val merchant: String?,
    val transactionType: TransactionType,
    val sourcePackage: String,
    val rawNotificationText: String,
    val notificationPostTime: Long,
    val notificationKey: String?,
    val dedupKey: String,
    val format: CaptureFormat,
    val categoryId: String?,
    val likelyPromotion: Boolean,
    val createdAt: Long,
    /** True after the owner changes the card, so the saved expense is EDITED. */
    val edited: Boolean,
    /** True when the text gave no clear Spent or Received; Save waits for the owner's choice. */
    @ColumnInfo(defaultValue = "0") val directionUnclear: Boolean = false
)

/** A payment the owner dropped. Capture checks it so a re-posted notification does not come back. */
@Entity(tableName = "dropped_notifications")
data class DroppedNotificationEntity(
    @PrimaryKey val dedupKey: String,
    val notificationKey: String?,
    val droppedAt: Long
)

@Dao
interface PendingPaymentDao {
    @Query("SELECT * FROM pending_payments ORDER BY createdAt ASC")
    fun observeAll(): Flow<List<PendingPaymentEntity>>

    @Query("SELECT * FROM pending_payments WHERE id = :id")
    suspend fun getById(id: String): PendingPaymentEntity?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(payment: PendingPaymentEntity)

    @Update
    suspend fun update(payment: PendingPaymentEntity)

    @Query("DELETE FROM pending_payments WHERE id = :id")
    suspend fun deleteById(id: String)

    /** A null [notificationKey] matches nothing, because NULL = NULL is not true in SQL. */
    @Query(
        "SELECT * FROM pending_payments WHERE dedupKey = :dedupKey OR notificationKey = :notificationKey LIMIT 1"
    )
    suspend fun findByKeys(dedupKey: String, notificationKey: String?): PendingPaymentEntity?

    /** Same rule as [ExpenseDao.findByAmountInWindow], so one payment told by two apps is one card. */
    @Query(
        """
        SELECT * FROM pending_payments
        WHERE amount = :amount
        AND transactionType = :transactionType
        AND (:matchMerchant = 0 OR merchant IS :merchant)
        AND notificationPostTime >= :windowStart AND notificationPostTime <= :windowEnd
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
    ): PendingPaymentEntity?

    /** Owner edits win: an edited card keeps its values. */
    @Query(
        """
        UPDATE pending_payments SET merchant = COALESCE(:merchant, merchant),
        categoryId = COALESCE(:categoryId, categoryId),
        likelyPromotion = :likelyPromotion
        WHERE id = :id AND edited = 0
        """
    )
    suspend fun enrich(id: String, merchant: String?, categoryId: String?, likelyPromotion: Boolean)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDropped(marker: DroppedNotificationEntity)

    @Query(
        "SELECT * FROM dropped_notifications WHERE dedupKey = :dedupKey OR notificationKey = :notificationKey LIMIT 1"
    )
    suspend fun findDropped(dedupKey: String, notificationKey: String?): DroppedNotificationEntity?

    @Query("DELETE FROM dropped_notifications WHERE droppedAt < :cutoff")
    suspend fun deleteDroppedBefore(cutoff: Long)
}
