package com.expensetracker.app.data

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import java.math.BigDecimal

@Entity(
    tableName = "expenses",
    indices = [Index(value = ["dedupKey"], unique = true)]
)
data class ExpenseEntity(
    @PrimaryKey val id: String,
    val amount: BigDecimal,
    val currency: String,
    val merchant: String?,
    val rawNotificationText: String,
    val sourcePackage: String,
    val notificationPostTime: Long,
    val createdAt: Long,
    val dedupKey: String,
    val status: ExpenseStatus,
    val confidence: ParseConfidence,
    val notificationKey: String?,
    val categoryId: String? = null,
    val notes: String? = null,
    val transactionType: TransactionType = TransactionType.WITHDRAW,
    /** What this payment cost me after a split. Null means the full [amount]. */
    val countedAmount: BigDecimal? = null
)

val ExpenseEntity.effectiveAmount: BigDecimal get() = countedAmount ?: amount
