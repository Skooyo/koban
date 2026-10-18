package com.expensetracker.app.parser

import org.json.JSONObject
import java.math.BigDecimal
import java.util.Calendar

/** `price` is the line total (not the unit price). */
data class ReceiptItemDraft(val name: String, val quantity: Int, val price: BigDecimal)

data class ReceiptDraft(
    val merchant: String?,
    val dateMillis: Long?,
    val items: List<ReceiptItemDraft>,
    val serviceCharge: BigDecimal,
    val tax: BigDecimal,
    val discount: BigDecimal,
    val rounding: BigDecimal,
    val printedTotal: BigDecimal?
)

/** Turns the model's receipt JSON into a [ReceiptDraft]. Pure JVM. */
object ReceiptParser {

    private val DATE_REGEX = Regex("""^(\d{4})-(\d{2})-(\d{2})$""")
    private val ZERO = BigDecimal("0.00")

    fun parseModelContent(content: String): ReceiptDraft? {
        return try {
            val start = content.indexOf('{')
            val end = content.lastIndexOf('}')
            if (start < 0 || end <= start) return null
            toDraft(JSONObject(content.substring(start, end + 1)))
        } catch (_: Exception) {
            null
        }
    }

    fun parseGenerateContentBody(body: String): ReceiptDraft? {
        return try {
            val text = JSONObject(body)
                .optJSONArray("candidates")
                ?.optJSONObject(0)
                ?.optJSONObject("content")
                ?.optJSONArray("parts")
                ?.optJSONObject(0)
                ?.optString("text")
                ?.takeIf { it.isNotBlank() }
                ?: return null
            parseModelContent(text)
        } catch (_: Exception) {
            null
        }
    }

    private fun toDraft(json: JSONObject): ReceiptDraft {
        val items = mutableListOf<ReceiptItemDraft>()
        val array = json.optJSONArray("items")
        for (i in 0 until (array?.length() ?: 0)) {
            val item = array?.optJSONObject(i) ?: continue
            val name = readString(item, "name") ?: continue
            val price = readAmount(item, "price")?.takeIf { it.signum() > 0 } ?: continue
            val quantity = item.optInt("quantity", 1).takeIf { it > 0 } ?: 1
            items += ReceiptItemDraft(name, quantity, price)
        }
        return ReceiptDraft(
            merchant = readString(json, "merchant"),
            dateMillis = readString(json, "date")?.let(::parseDate),
            items = items,
            serviceCharge = readAmount(json, "serviceCharge") ?: ZERO,
            tax = readAmount(json, "tax") ?: ZERO,
            discount = (readAmount(json, "discount") ?: ZERO).abs(),
            rounding = readAmount(json, "rounding") ?: ZERO,
            printedTotal = readAmount(json, "total")
        )
    }

    private fun readString(json: JSONObject, key: String): String? {
        if (!json.has(key) || json.isNull(key)) return null
        return json.optString(key, "").trim()
            .takeIf { it.isNotEmpty() && !it.equals("null", ignoreCase = true) }
    }

    private fun readAmount(json: JSONObject, key: String): BigDecimal? {
        if (!json.has(key) || json.isNull(key)) return null
        val cleaned = json.get(key).toString()
            .replace(Regex("""RM|MYR""", RegexOption.IGNORE_CASE), "")
            .replace(",", "")
            .replace(" ", "")
        return NotificationParser.normalizeAmount(cleaned)
    }

    /** "YYYY-MM-DD" to local-midnight millis; anything else (or an impossible date) is null. */
    private fun parseDate(raw: String): Long? {
        val (y, m, d) = DATE_REGEX.matchEntire(raw)?.destructured ?: return null
        return try {
            Calendar.getInstance().apply {
                clear()
                isLenient = false
                set(y.toInt(), m.toInt() - 1, d.toInt(), 0, 0, 0)
            }.timeInMillis
        } catch (_: IllegalArgumentException) {
            null
        }
    }
}
