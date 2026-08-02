package com.expensetracker.app.data

enum class TransactionType {
    WITHDRAW,
    RECEIVE
}

fun TransactionType.signedAmount(amount: java.math.BigDecimal): java.math.BigDecimal =
    if (this == TransactionType.RECEIVE) amount.negate() else amount
