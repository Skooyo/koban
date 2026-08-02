package com.expensetracker.app.parser

import com.expensetracker.app.data.ParseConfidence
import com.expensetracker.app.data.TransactionType
import java.math.BigDecimal

data class ParsedExpense(
    val amount: BigDecimal,
    val currency: String,
    val merchant: String?,
    val confidence: ParseConfidence,
    val transactionType: TransactionType = TransactionType.WITHDRAW
)
