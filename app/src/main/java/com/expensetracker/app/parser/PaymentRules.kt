package com.expensetracker.app.parser

import com.expensetracker.app.data.ParseConfidence
import com.expensetracker.app.data.TransactionType

enum class CaptureFormat { KNOWN, UNKNOWN }

sealed interface RuleMatch {
    data class Matched(val expense: ParsedExpense, val format: CaptureFormat) : RuleMatch
    data object NoMatch : RuleMatch
}

/**
 * Strict per-app regex rules first, then the catch-all [NotificationParser] for any text with an
 * RM/MYR amount (format UNKNOWN). Only a text with no amount is [RuleMatch.NoMatch].
 */
object PaymentRules {
    private const val MAYBANK = "com.maybank2u.life"
    private const val TNG = "my.com.tngdigital.ewallet"
    private const val GOOGLE_WALLET = "com.google.android.apps.walletnfcrel"

    private class Rule(
        pattern: String,
        val type: TransactionType,
        val fixedMerchant: String? = null
    ) {
        val regex = Regex(pattern, RegexOption.IGNORE_CASE)
    }

    private const val AMOUNT = """RM\s*(?<amount>[\d,]+(?:\.\d{1,2})?)"""
    /** Merchant runs to a card tail, "REF"/"View" sentence or the end. Dots inside names (Sdn. Bhd.) stay. */
    private const val MERCHANT = """(?<merchant>.+?)(?=\s+with\s+your\b|\s+account\s+ending\b|\.+\s*(?:REF|View)\b|\.+\s+(?!(?i:sdn|bhd|ltd|co|inc)\b)(?-i:[A-Z][a-z])|\.*\s*$)"""

    /** Sender named before the verb, as in "ALI has transferred RM 10.00 to you". */
    private const val MERCHANT_FIRST = """(?<merchant>.+?)"""

    private val rules: Map<String, List<Rule>> = mapOf(
        MAYBANK to listOf(
            Rule("""\bspent\s+$AMOUNT\s+at\s+$MERCHANT""", TransactionType.WITHDRAW),
            Rule("""\bpayment\s+of\s+$AMOUNT\s+to\s+$MERCHANT""", TransactionType.WITHDRAW),
            Rule("""\bpaid\s+$AMOUNT\s+to\s+$MERCHANT""", TransactionType.WITHDRAW),
            Rule("""\btransferred\s+$AMOUNT\s+to\s+$MERCHANT""", TransactionType.WITHDRAW),
            Rule("""\bwithdrawn\s+$AMOUNT\b""", TransactionType.WITHDRAW, "ATM withdrawal"),
            Rule("""\breceived\s+$AMOUNT\s+from\s+$MERCHANT""", TransactionType.RECEIVE),
            Rule("""\breceived\s+$AMOUNT\s+in\s+your\s+account\b""", TransactionType.RECEIVE)
        ),
        TNG to listOf(
            Rule("""\bpaid\s+$AMOUNT\s+to\s+$MERCHANT""", TransactionType.WITHDRAW),
            Rule("""$AMOUNT\s+has\s+been\s+successfully\s+transferred\s+to\s+$MERCHANT""", TransactionType.WITHDRAW),
            Rule("""$AMOUNT\s+received\s+from\s+$MERCHANT""", TransactionType.RECEIVE),
            Rule("""^$MERCHANT_FIRST\s+has\s+transferred\s+$AMOUNT\s+to\s+you\b""", TransactionType.RECEIVE)
        ),
        // Card taps carry no merchant or direction, so they reach the catch-all as "direction unclear".
        GOOGLE_WALLET to emptyList()
    )

    val KNOWN_PACKAGES: Set<String> = rules.keys

    /** Apps whose matches start selected on the confirm screen. */
    val PRESELECT_PACKAGES: Set<String> = setOf(MAYBANK, TNG)

    fun match(packageName: String, text: String): RuleMatch {
        val appRules = rules[packageName] ?: return matchGeneric(text)
        for (rule in appRules) {
            val m = rule.regex.find(text) ?: continue
            val groups = m.groups as MatchNamedGroupCollection
            val amount = NotificationParser.normalizeAmount(groups["amount"]!!.value) ?: continue
            val merchant = rule.fixedMerchant
                ?: runCatching { groups["merchant"]?.value }.getOrNull()?.let(MerchantNormalizer::clean)
            return RuleMatch.Matched(
                ParsedExpense(amount, "MYR", merchant, ParseConfidence.HIGH, rule.type),
                CaptureFormat.KNOWN
            )
        }
        // Nothing with an amount is dropped; the owner swipes a promotion away on the card.
        return matchGeneric(text)
    }

    private fun matchGeneric(text: String): RuleMatch {
        val parsed = NotificationParser.parse(text) ?: return RuleMatch.NoMatch
        return RuleMatch.Matched(parsed, CaptureFormat.UNKNOWN)
    }
}
