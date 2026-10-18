package com.expensetracker.app.data

data class PeriodSummary(
    val title: String,
    val subtitle: String,
    val total: java.math.BigDecimal,
    val breakdown: List<CategoryBreakdown>,
    val recentExpenses: List<ExpenseEntity>,
    val periodStart: Long = 0L,
    val periodEnd: Long = 0L,
    val received: java.math.BigDecimal = java.math.BigDecimal.ZERO
)
