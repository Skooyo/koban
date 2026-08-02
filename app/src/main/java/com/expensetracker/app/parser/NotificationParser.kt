package com.expensetracker.app.parser

import com.expensetracker.app.data.ParseConfidence
import com.expensetracker.app.data.TransactionType
import java.math.BigDecimal

object NotificationParser {
    private val rmPattern = Regex("""RM\s*([\d,]+(?:\.\d{1,2})?)""", RegexOption.IGNORE_CASE)
    private val genericPattern = Regex("""(?:MYR|RM)\s*([\d,]+(?:\.\d{1,2})?)""", RegexOption.IGNORE_CASE)
    private val debitKeywords = Regex(
        """\b(spent|paid|debited|payment|purchase|charged|withdrawn|withdrawal|transferred)\b""",
        RegexOption.IGNORE_CASE
    )
    private val creditKeywords = Regex(
        """\b(received|credited|refund|refunded|incoming|transfer\s+from|money\s+in)\b""",
        RegexOption.IGNORE_CASE
    )
    private val merchantPatterns = listOf(
        Regex("""\bto\s+"([^"]+)""", RegexOption.IGNORE_CASE),
        Regex("""\bto\s+'([^']+)'""", RegexOption.IGNORE_CASE),
        Regex("""\btransferred\s+to\s+(.+?)(?:\.|$)""", RegexOption.IGNORE_CASE),
        Regex("""\bpaid\s+to\s+(.+?)(?:\.|$)""", RegexOption.IGNORE_CASE),
        Regex("""\bpayment\s+to\s+(.+?)(?:\.|$)""", RegexOption.IGNORE_CASE),
        Regex("""\bto\s+(.+?)(?:\.|$)""", RegexOption.IGNORE_CASE),
        Regex("""\bat\s+(.+?)(?:\.|$)""", RegexOption.IGNORE_CASE)
    )

    fun parse(notificationBody: String): ParsedExpense? {
        val body = notificationBody.trim()
        if (body.isBlank()) return null

        val amounts = findAllAmounts(body)
        if (amounts.isEmpty()) return null

        val amount = amounts.first()
        val transactionType = detectTransactionType(body)
        val confidence = determineConfidence(body, amounts, transactionType)
        val merchant = extractMerchantFromBody(body, amount)

        return ParsedExpense(
            amount = amount,
            currency = "MYR",
            merchant = merchant,
            confidence = confidence,
            transactionType = transactionType
        )
    }

    fun detectTransactionType(text: String): TransactionType {
        val credit = creditKeywords.containsMatchIn(text)
        val debit = debitKeywords.containsMatchIn(text)
        return when {
            credit && !debit -> TransactionType.RECEIVE
            else -> TransactionType.WITHDRAW
        }
    }

    fun findAllAmounts(text: String): List<BigDecimal> {
        val matches = mutableListOf<BigDecimal>()
        val seen = mutableSetOf<String>()

        for (pattern in listOf(rmPattern, genericPattern)) {
            pattern.findAll(text).forEach { match ->
                val raw = match.groupValues[1]
                val normalized = normalizeAmount(raw) ?: return@forEach
                val key = normalized.toPlainString()
                if (seen.add(key)) {
                    matches.add(normalized)
                }
            }
        }
        return matches
    }

    fun normalizeAmount(raw: String): BigDecimal? {
        return try {
            val cleaned = raw.replace(",", "").trim()
            if (cleaned.isEmpty()) return null
            AmountFormatter.toMoney(BigDecimal(cleaned))
        } catch (_: NumberFormatException) {
            null
        }
    }

    fun extractMerchantFromBody(body: String, amount: BigDecimal): String? {
        for (pattern in merchantPatterns) {
            val match = pattern.find(body) ?: continue
            val candidate = match.groupValues[1]
                .replace(Regex("""RM\s*[\d,]+(?:\.\d{1,2})?""", RegexOption.IGNORE_CASE), "")
                .replace(Regex("""(?:MYR|RM)\s*[\d,]+(?:\.\d{1,2})?""", RegexOption.IGNORE_CASE), "")
                .replace(amount.toPlainString(), "")
                .trim()
                .trim('-', ':', '·', '•', '"', '\'')
            if (candidate.length >= 2) return candidate
        }
        return fallbackMerchantFromBody(body, amount)
    }

    private fun fallbackMerchantFromBody(body: String, amount: BigDecimal): String? {
        val amountStr = amount.toPlainString()
        return body.lines()
            .map { line ->
                line.replace(Regex("""RM\s*[\d,]+(?:\.\d{1,2})?""", RegexOption.IGNORE_CASE), "")
                    .replace(Regex("""(?:MYR|RM)\s*[\d,]+(?:\.\d{1,2})?""", RegexOption.IGNORE_CASE), "")
                    .replace(amountStr, "")
                    .trim()
                    .trim('-', ':', '·', '•', '"', '\'')
            }
            .firstOrNull { it.length >= 2 }
    }

    private fun determineConfidence(
        text: String,
        amounts: List<BigDecimal>,
        transactionType: TransactionType
    ): ParseConfidence {
        val hasMerchantPattern = merchantPatterns.any { it.containsMatchIn(text) }
        return when {
            amounts.size > 1 -> ParseConfidence.LOW
            hasMerchantPattern && (debitKeywords.containsMatchIn(text) || creditKeywords.containsMatchIn(text)) ->
                ParseConfidence.HIGH
            debitKeywords.containsMatchIn(text) || creditKeywords.containsMatchIn(text) -> ParseConfidence.HIGH
            transactionType == TransactionType.WITHDRAW && text.contains("-") && rmPattern.containsMatchIn(text) ->
                ParseConfidence.HIGH
            else -> ParseConfidence.MEDIUM
        }
    }
}
