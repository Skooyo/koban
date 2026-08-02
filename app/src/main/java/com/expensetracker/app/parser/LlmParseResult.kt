package com.expensetracker.app.parser

/**
 * Result of an OpenRouter LLM parse attempt.
 * [Failed] triggers regex fallback; [NotTransaction] skips saving without fallback.
 */
sealed class LlmParseResult {
    data class Success(val expense: ParsedExpense) : LlmParseResult()

    /** Model classified the notification as not a real money transaction. */
    data class NotTransaction(val reason: String? = null) : LlmParseResult()

    data object Failed : LlmParseResult()
}
