package com.expensetracker.app.parser

import com.expensetracker.app.data.ParseConfidence
import com.expensetracker.app.data.TransactionType
import org.json.JSONObject

/**
 * Parses structured JSON content returned by the OpenRouter chat model
 * into [ParsedExpense], or signals skip / failure.
 */
object LlmResponseParser {

    fun parseModelContent(content: String): LlmParseResult {
        val trimmed = content.trim()
        if (trimmed.isEmpty()) return LlmParseResult.Failed

        return try {
            val json = extractJsonObject(trimmed) ?: return LlmParseResult.Failed
            parseJsonObject(json)
        } catch (_: Exception) {
            LlmParseResult.Failed
        }
    }

    fun parseChatCompletionsBody(responseBody: String): LlmParseResult {
        return try {
            val root = JSONObject(responseBody)
            val content = root
                .optJSONArray("choices")
                ?.optJSONObject(0)
                ?.optJSONObject("message")
                ?.optString("content")
                ?.takeIf { it.isNotBlank() }
                ?: return LlmParseResult.Failed
            parseModelContent(content)
        } catch (_: Exception) {
            LlmParseResult.Failed
        }
    }

    internal fun parseJsonObject(json: JSONObject): LlmParseResult {
        val reason = readOptionalString(json, "reason")

        if (json.optBoolean("skip", false)) {
            return LlmParseResult.NotTransaction(reason ?: "skipped")
        }

        // Prefer isTransaction; accept legacy isPaymentNotification for older responses.
        when {
            json.has("isTransaction") -> {
                if (!json.optBoolean("isTransaction", false)) {
                    return LlmParseResult.NotTransaction(reason)
                }
            }
            json.has("isPaymentNotification") -> {
                if (!json.optBoolean("isPaymentNotification", false)) {
                    return LlmParseResult.NotTransaction(reason)
                }
            }
        }

        val amountRaw = when {
            json.has("amount") && !json.isNull("amount") -> json.get("amount").toString()
            else -> {
                // Claimed transaction but no amount — let regex try if caller falls back.
                // When the model omitted the validity flag entirely, treat missing amount as reject.
                return if (json.has("isTransaction") || json.has("isPaymentNotification")) {
                    LlmParseResult.Failed
                } else {
                    LlmParseResult.NotTransaction(reason ?: "no amount")
                }
            }
        }
        val amount = NotificationParser.normalizeAmount(amountRaw.replace(",", ""))
            ?: return LlmParseResult.Failed

        val currencyRaw = json.optString("currency", "MYR").trim().ifBlank { "MYR" }
        val currency = when (currencyRaw.uppercase()) {
            "RM", "MYR" -> "MYR"
            else -> currencyRaw.uppercase()
        }

        val merchant = readOptionalString(json, "merchant")

        val transactionType = parseTransactionType(json.optString("transactionType", "WITHDRAW"))
        val confidence = parseConfidence(json.optString("confidence", "MEDIUM"))

        return LlmParseResult.Success(
            ParsedExpense(
                amount = AmountFormatter.toMoney(amount),
                currency = currency,
                merchant = merchant,
                confidence = confidence,
                transactionType = transactionType
            )
        )
    }

    private fun extractJsonObject(content: String): JSONObject? {
        val start = content.indexOf('{')
        val end = content.lastIndexOf('}')
        if (start < 0 || end <= start) return null
        return JSONObject(content.substring(start, end + 1))
    }

    private fun readOptionalString(json: JSONObject, key: String): String? {
        if (!json.has(key) || json.isNull(key)) return null
        return json.optString(key, "")
            .trim()
            .takeIf { it.isNotEmpty() && !it.equals("null", ignoreCase = true) }
    }

    private fun parseTransactionType(raw: String): TransactionType {
        return when (raw.trim().uppercase()) {
            "RECEIVE", "CREDIT", "INCOMING", "REFUND" -> TransactionType.RECEIVE
            else -> TransactionType.WITHDRAW
        }
    }

    private fun parseConfidence(raw: String): ParseConfidence {
        return when (raw.trim().uppercase()) {
            "HIGH" -> ParseConfidence.HIGH
            "LOW" -> ParseConfidence.LOW
            else -> ParseConfidence.MEDIUM
        }
    }
}
