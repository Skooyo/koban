package com.expensetracker.app.data

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import java.math.BigDecimal

/** A hand-entered amount the owner owes a person. Never counts as spending. */
@Entity(tableName = "owed_items", indices = [Index("personId")])
data class OwedItemEntity(
    @PrimaryKey val id: String,
    val personId: String,
    val description: String,
    val amount: BigDecimal,
    val itemDate: Long,
    val createdAt: Long,
    val status: DebtStatus,
    val paidAt: Long?
)
