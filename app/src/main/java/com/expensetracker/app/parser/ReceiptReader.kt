package com.expensetracker.app.parser

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import javax.inject.Inject
import javax.inject.Singleton

/** Reads a receipt photo with Gemini and returns the extracted [ReceiptDraft]. */
@Singleton
class ReceiptReader @Inject constructor(
    @ApplicationContext private val context: Context,
    private val geminiClient: GeminiClient
) {
    /** Returns null if the model is not configured, the image is unreadable, or every model fails. */
    suspend fun read(imageUri: Uri): ReceiptDraft? = withContext(Dispatchers.IO) {
        if (!geminiClient.isConfigured) return@withContext null
        val jpeg = encodeJpeg(imageUri) ?: return@withContext null
        val parts = JSONArray()
            .put(
                JSONObject().put(
                    "inline_data",
                    JSONObject()
                        .put("mime_type", "image/jpeg")
                        .put("data", Base64.encodeToString(jpeg, Base64.NO_WRAP))
                )
            )
            .put(JSONObject().put("text", "Read this receipt."))
        geminiClient.generate(
            SYSTEM_PROMPT,
            parts,
            callTimeoutSeconds = 60,
            parse = ReceiptParser::parseGenerateContentBody
        )
    }

    private fun encodeJpeg(uri: Uri): ByteArray? {
        return try {
            val resolver = context.contentResolver
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
            var sample = 1
            // Power-of-two sample size keeps the longest side at or below MAX_SIDE_PX.
            while (maxOf(bounds.outWidth, bounds.outHeight) / sample > MAX_SIDE_PX) sample *= 2
            val options = BitmapFactory.Options().apply { inSampleSize = sample }
            val bitmap = resolver.openInputStream(uri)?.use {
                BitmapFactory.decodeStream(it, null, options)
            } ?: return null
            ByteArrayOutputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)
                bitmap.recycle()
                out.toByteArray()
            }
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        private const val MAX_SIDE_PX = 1600

        private val SYSTEM_PROMPT = """
You read photos of Malaysian shop and restaurant receipts and extract the data.

Return a single JSON object only (no markdown). Schema:
{"merchant": "string|null", "date": "YYYY-MM-DD|null",
 "items": [{"name": "string", "quantity": 1, "price": 12.50}],
 "serviceCharge": 0, "tax": 0, "discount": 0, "rounding": 0, "total": 0}

Rules:
- price: the LINE TOTAL for that item (quantity times unit price), as a number without currency symbol.
- quantity: a whole number, 1 if the receipt shows none.
- serviceCharge, tax, discount, rounding: the amounts printed on the receipt, 0 if absent. discount is a positive number.
- total: the final amount printed on the receipt, null if unreadable.
- date: the receipt date as YYYY-MM-DD, null if unreadable.
- Do not invent items or amounts that are not on the receipt.
        """.trimIndent()
    }
}
