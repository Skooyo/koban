package com.expensetracker.app.parser

import android.util.Log
import com.expensetracker.app.BuildConfig
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class OpenRouterClient @Inject constructor(
    private val httpClient: OkHttpClient
) {
    val isConfigured: Boolean
        get() = BuildConfig.OPENROUTER_API_KEY.isNotBlank()

    val model: String
        get() = BuildConfig.OPENROUTER_MODEL.ifBlank { DEFAULT_MODEL }

    /**
     * Calls OpenRouter chat completions. Runs on the caller's thread —
     * invoke from a background dispatcher / coroutine.
     */
    fun parsePaymentNotification(notificationText: String): LlmParseResult {
        if (!isConfigured) return LlmParseResult.Failed

        return try {
            val payload = buildRequestJson(notificationText)
            val request = Request.Builder()
                .url(CHAT_COMPLETIONS_URL)
                .addHeader("Authorization", "Bearer ${BuildConfig.OPENROUTER_API_KEY}")
                .addHeader("Content-Type", "application/json")
                .addHeader("HTTP-Referer", "https://github.com/expensetracker/android")
                .addHeader("X-Title", "Expense Tracker")
                .post(payload.toRequestBody(JSON_MEDIA_TYPE))
                .build()

            httpClient.newCall(request).execute().use { response ->
                val body = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    Log.w(TAG, "OpenRouter HTTP ${response.code}: ${body.take(200)}")
                    return LlmParseResult.Failed
                }
                LlmResponseParser.parseChatCompletionsBody(body)
            }
        } catch (e: Exception) {
            Log.w(TAG, "OpenRouter call failed: ${e.message}")
            LlmParseResult.Failed
        }
    }

    private fun buildRequestJson(notificationText: String): String {
        val messages = JSONArray()
            .put(
                JSONObject()
                    .put("role", "system")
                    .put("content", SYSTEM_PROMPT)
            )
            .put(
                JSONObject()
                    .put("role", "user")
                    .put("content", notificationText)
            )

        return JSONObject()
            .put("model", model)
            .put("temperature", 0)
            .put("response_format", JSONObject().put("type", "json_object"))
            .put("messages", messages)
            .toString()
    }

    companion object {
        private const val TAG = "OpenRouterClient"
        private const val CHAT_COMPLETIONS_URL = "https://openrouter.ai/api/v1/chat/completions"
        private const val DEFAULT_MODEL = "openai/gpt-4o-mini"
        private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

        val SYSTEM_PROMPT = """
You classify Malaysian bank and e-wallet notification text and extract payment data when valid
(Maybank, CIMB, RHB, Hong Leong, Public Bank, Touch 'n Go eWallet, GrabPay, Boost, ShopeePay, MAE, etc.).

Return a single JSON object only (no markdown). Schema:
{
  "isTransaction": boolean,
  "reason": string or null,
  "amount": number or null,
  "currency": "MYR" or null,
  "merchant": string or null,
  "transactionType": "WITHDRAW" | "RECEIVE" | null,
  "confidence": "HIGH" | "MEDIUM" | "LOW" | null
}

Rules:
- isTransaction: true ONLY for a real completed (or clearly executed) money movement: payment, purchase, spend, debit, transfer out, receive, credit, refund, or incoming transfer.
- isTransaction: false for anything that is NOT a real transaction, even if it mentions RM / MYR amounts. Examples: promotional or marketing offers, cashback teases, vouchers, discounts, ads, OTP / verification codes, login alerts, balance-only or available-limit updates, reminders, tips, failed/declined attempts with no settled amount, and generic app news.
- When isTransaction is false: set reason to a short explanation (e.g. "promotional offer"), and set amount, currency, merchant, transactionType, and confidence to null.
- When isTransaction is true:
  - amount: the transaction amount as a number (no currency symbol). Prefer the payment amount over balances.
  - currency: default "MYR" when RM/MYR or Malaysian context; otherwise use the stated ISO-like code.
  - merchant: clean human-readable merchant, recipient, or counterparty name. Strip quotes, account numbers, refs, and trailing punctuation. null if unknown.
  - transactionType: WITHDRAW for spent/paid/debited/transferred out/purchase; RECEIVE for received/credited/refund/incoming.
  - confidence: HIGH when amount and type are clear; MEDIUM if merchant is uncertain; LOW if amount or type is ambiguous.
  - reason: null (or omit).
- Do not invent merchants or amounts not supported by the text.
- Mention of an amount alone does NOT make it a transaction.
""".trimIndent()

        fun createDefaultHttpClient(): OkHttpClient =
            OkHttpClient.Builder()
                .connectTimeout(15, TimeUnit.SECONDS)
                .readTimeout(18, TimeUnit.SECONDS)
                .writeTimeout(15, TimeUnit.SECONDS)
                .callTimeout(20, TimeUnit.SECONDS)
                .build()
    }
}
