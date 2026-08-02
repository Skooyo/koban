package com.expensetracker.app.parser

import android.util.Log
import com.expensetracker.app.data.SettingsRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Parses payment notifications via OpenRouter when configured, otherwise
 * falls back to [NotificationParser] regex extraction.
 */
@Singleton
class ExpenseNotificationParser @Inject constructor(
    private val openRouterClient: OpenRouterClient,
    private val settingsRepository: SettingsRepository
) {
    val isLlmConfigured: Boolean
        get() = openRouterClient.isConfigured

    suspend fun parse(notificationBody: String): ExpenseParseResult {
        val body = notificationBody.trim()
        if (body.isBlank()) return ExpenseParseResult.NoAmount

        val llmEnabled = settingsRepository.llmParsingEnabled.first()
        if (llmEnabled && openRouterClient.isConfigured) {
            val llmResult = withContext(Dispatchers.IO) {
                openRouterClient.parsePaymentNotification(body)
            }
            when (llmResult) {
                is LlmParseResult.Success -> {
                    Log.d(TAG, "LLM parse OK: ${llmResult.expense.merchant} ${llmResult.expense.amount}")
                    return ExpenseParseResult.Success(llmResult.expense)
                }
                is LlmParseResult.NotTransaction -> {
                    Log.d(TAG, "LLM: not a transaction (${llmResult.reason ?: "no reason"})")
                    return ExpenseParseResult.SkippedNotTransaction(llmResult.reason)
                }
                LlmParseResult.Failed -> {
                    Log.d(TAG, "LLM failed — falling back to regex")
                }
            }
        }

        val regexParsed = NotificationParser.parse(body)
        return if (regexParsed != null) {
            ExpenseParseResult.Success(regexParsed)
        } else {
            ExpenseParseResult.NoAmount
        }
    }

    companion object {
        private const val TAG = "ExpenseNotifParser"
    }
}
