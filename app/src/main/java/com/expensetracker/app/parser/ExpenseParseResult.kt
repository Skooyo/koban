package com.expensetracker.app.parser

/**
 * Outcome of [ExpenseNotificationParser.parse]: either a saved-ready expense,
 * an LLM reject of a non-transaction, or no extractable amount (regex / empty).
 */
sealed class ExpenseParseResult {
    data class Success(val expense: ParsedExpense) : ExpenseParseResult()

    /** LLM decided this is not a real payment/transfer/receive. Do not save. */
    data class SkippedNotTransaction(val reason: String?) : ExpenseParseResult()

    /** No amount could be extracted (regex fallback or blank). */
    data object NoAmount : ExpenseParseResult()
}
