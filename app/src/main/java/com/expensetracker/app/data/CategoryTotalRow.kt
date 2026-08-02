package com.expensetracker.app.data

import androidx.room.ColumnInfo
import java.math.BigDecimal

data class CategoryTotalRow(
    @ColumnInfo(name = "categoryId") val categoryId: String?,
    @ColumnInfo(name = "total") val total: BigDecimal
)

data class CategoryBreakdown(
    val categoryId: String?,
    val name: String,
    val colorHex: String,
    val total: BigDecimal,
    val fraction: Float
)
