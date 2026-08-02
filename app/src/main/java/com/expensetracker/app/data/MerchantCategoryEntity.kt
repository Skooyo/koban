package com.expensetracker.app.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "merchant_category_map")
data class MerchantCategoryEntity(
    @PrimaryKey val merchantKey: String,
    val displayName: String,
    val categoryId: String,
    val updatedAt: Long
)
