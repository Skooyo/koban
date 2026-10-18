package com.expensetracker.app.parser

import android.util.Log
import com.expensetracker.app.BuildConfig
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.net.URLEncoder
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Google AI Studio (Gemini API) client.
 * Cycles between [primaryModel] and [secondaryModel] when one is rate-limited (HTTP 429).
 */
@Singleton
class GeminiClient @Inject constructor(
    private val httpClient: OkHttpClient
) {
    val isConfigured: Boolean
        get() = BuildConfig.GEMINI_API_KEY.isNotBlank()

    val primaryModel: String
        get() = BuildConfig.GEMINI_MODEL_PRIMARY.ifBlank { DEFAULT_PRIMARY }

    val secondaryModel: String
        get() = BuildConfig.GEMINI_MODEL_SECONDARY.ifBlank { DEFAULT_SECONDARY }

    val modelsLabel: String
        get() = "$primaryModel ↔ $secondaryModel"

    private val preferredIndex = AtomicInteger(0)
    private val cooldownUntilMs = LongArray(2)

    /**
     * Calls Gemini generateContent. Runs on the caller's thread —
     * invoke from a background dispatcher / coroutine.
     */
    fun parsePaymentNotification(notificationText: String): LlmParseResult {
        if (!isConfigured) return LlmParseResult.Failed

        val models = listOf(primaryModel, secondaryModel)
        val start = preferredIndex.get().coerceIn(0, 1)
        val order = listOf(start, 1 - start)

        var lastFailure: LlmParseResult = LlmParseResult.Failed
        for (index in order) {
            val model = models[index]
            val now = System.currentTimeMillis()
            if (cooldownUntilMs[index] > now) {
                Log.d(TAG, "Skipping $model (rate-limit cooldown)")
                continue
            }

            when (val attempt = callModel(model, notificationText)) {
                is ModelAttempt.Success -> {
                    preferredIndex.set(index)
                    clearCooldown(index)
                    Log.d(TAG, "Parsed with $model")
                    return attempt.result
                }
                ModelAttempt.RateLimited -> {
                    cooldownUntilMs[index] = now + RATE_LIMIT_COOLDOWN_MS
                    preferredIndex.set(1 - index)
                    Log.w(TAG, "Rate limited on $model — will try alternate model")
                    lastFailure = LlmParseResult.Failed
                }
                ModelAttempt.Failed -> {
                    Log.w(TAG, "Call failed on $model")
                    lastFailure = LlmParseResult.Failed
                }
            }
        }
        return lastFailure
    }

    private fun callModel(model: String, notificationText: String): ModelAttempt {
        return try {
            val encodedKey = URLEncoder.encode(BuildConfig.GEMINI_API_KEY, Charsets.UTF_8.name())
            val url =
                "$GENERATE_CONTENT_BASE/${model}:generateContent?key=$encodedKey"
            val request = Request.Builder()
                .url(url)
                .addHeader("Content-Type", "application/json")
                .post(buildRequestJson(notificationText).toRequestBody(JSON_MEDIA_TYPE))
                .build()

            httpClient.newCall(request).execute().use { response ->
                val body = response.body?.string().orEmpty()
                when {
                    response.code == 429 -> ModelAttempt.RateLimited
                    !response.isSuccessful -> {
                        Log.w(TAG, "Gemini HTTP ${response.code} ($model): ${body.take(240)}")
                        if (body.contains("RESOURCE_EXHAUSTED", ignoreCase = true) ||
                            body.contains("rate limit", ignoreCase = true)
                        ) {
                            ModelAttempt.RateLimited
                        } else {
                            ModelAttempt.Failed
                        }
                    }
                    else -> {
                        val parsed = LlmResponseParser.parseGenerateContentBody(body)
                        if (parsed == LlmParseResult.Failed) ModelAttempt.Failed
                        else ModelAttempt.Success(parsed)
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Gemini call failed ($model): ${e.message}")
            ModelAttempt.Failed
        }
    }

    private fun clearCooldown(index: Int) {
        cooldownUntilMs[index] = 0L
    }

    private fun buildRequestJson(notificationText: String): String {
        val systemInstruction = JSONObject()
            .put(
                "parts",
                JSONArray().put(JSONObject().put("text", SYSTEM_PROMPT))
            )

        val contents = JSONArray().put(
            JSONObject()
                .put("role", "user")
                .put(
                    "parts",
                    JSONArray().put(JSONObject().put("text", notificationText))
                )
        )

        val generationConfig = JSONObject()
            .put("temperature", 0)
            .put("responseMimeType", "application/json")

        return JSONObject()
            .put("system_instruction", systemInstruction)
            .put("contents", contents)
            .put("generationConfig", generationConfig)
            .toString()
    }

    private sealed class ModelAttempt {
        data class Success(val result: LlmParseResult) : ModelAttempt()
        data object RateLimited : ModelAttempt()
        data object Failed : ModelAttempt()
    }

    companion object {
        private const val TAG = "GeminiClient"
        private const val GENERATE_CONTENT_BASE =
            "https://generativelanguage.googleapis.com/v1beta/models"
        private const val DEFAULT_PRIMARY = "gemini-3.1-flash-lite"
        private const val DEFAULT_SECONDARY = "gemini-3.5-flash-lite"
        private const val RATE_LIMIT_COOLDOWN_MS = 60_000L
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
  - merchant: ONLY the merchant, shop, recipient, or counterparty name.
    Examples: "KK - SUPER MART - UMN", "Starbucks", "AISYAH NUR RAHMAN".
    NEVER include card/account tails such as "with your Maybank Debit Card Visa ending with 3729",
    "using your debit card", "ending with 1234", account numbers, refs, or payment method text.
    Strip quotes and trailing punctuation. null if unknown.
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
