package com.expensetracker.app.data

import androidx.room.ColumnInfo
import java.math.BigDecimal

data class MonthTotalRow(
    @ColumnInfo(name = "yearMonth") val yearMonth: Int,
    @ColumnInfo(name = "total") val total: BigDecimal,
    @ColumnInfo(name = "received") val received: BigDecimal
)

data class MonthSummary(
    val year: Int,
    val month: Int,
    val label: String,
    val total: BigDecimal,
    val received: BigDecimal = BigDecimal.ZERO
)

data class WeekSummary(
    val startMs: Long,
    val endMs: Long,
    val label: String,
    val total: BigDecimal
)
