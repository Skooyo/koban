package com.expensetracker.app.data

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import java.math.BigDecimal

enum class DebtStatus { OPEN, PAID }

@Entity(tableName = "split_bills")
data class SplitBillEntity(
    @PrimaryKey val id: String,
    val merchant: String?,
    val billTime: Long,
    val currency: String,
    val printedTotal: BigDecimal?,
    val serviceCharge: BigDecimal,
    val tax: BigDecimal,
    val discount: BigDecimal,
    val rounding: BigDecimal,
    val linkedExpenseId: String?,
    val createdAt: Long
)

@Entity(tableName = "split_items", indices = [Index("billId")])
data class SplitItemEntity(
    @PrimaryKey val id: String,
    val billId: String,
    val name: String,
    val quantity: Int,
    val price: BigDecimal,
    val position: Int
)

@Entity(tableName = "split_people")
data class SplitPersonEntity(
    @PrimaryKey val id: String,
    val name: String,
    val lastUsedAt: Long,
    val qrPath: String? = null,
    @ColumnInfo(defaultValue = "0") val archived: Boolean = false,
    val suggestedSettleExpenseId: String? = null
)

@Entity(
    tableName = "split_item_shares",
    primaryKeys = ["itemId", "personId"],
    indices = [Index("personId")]
)
data class SplitItemShareEntity(
    val itemId: String,
    val personId: String
)

@Entity(tableName = "split_debts", indices = [Index("billId"), Index("personId")])
data class SplitDebtEntity(
    @PrimaryKey val id: String,
    val billId: String,
    val personId: String,
    val amount: BigDecimal,
    val status: DebtStatus,
    val repaymentExpenseId: String?,
    val suggestedRepaymentExpenseId: String?,
    val paidAt: Long?
)
