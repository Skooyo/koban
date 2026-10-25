package com.expensetracker.app.parser

/**
 * Cleans merchant / counterparty strings from Malaysian bank and wallet notifications.
 * Card/account tails like "with your Maybank Debit Card ending with 3729" are not part of the merchant.
 */
object MerchantNormalizer {
    private val trailingJunk = listOf(
        Regex("""\s+with\s+your\b.*$""", RegexOption.IGNORE_CASE),
        Regex("""\s+using\s+your\b.*$""", RegexOption.IGNORE_CASE),
        Regex("""\s+via\s+your\b.*$""", RegexOption.IGNORE_CASE),
        Regex("""\s+from\s+your\s+(?:maybank|cimb|rhb|hlb|public|bank|debit|credit|visa|mastercard|card|account)\b.*$""", RegexOption.IGNORE_CASE),
        Regex("""\s+ending\s+with\s+\d+.*$""", RegexOption.IGNORE_CASE),
        Regex("""\s+ending\s+\*+\d+.*$""", RegexOption.IGNORE_CASE),
        Regex("""\s+\(\s*(?:ref|txn|transaction|auth).*$""", RegexOption.IGNORE_CASE),
        Regex("""\s+ref(?:erence)?[\s.:#].*$""", RegexOption.IGNORE_CASE)
    )

    private val months = "jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec"
    /** Dates and times that banks append to the merchant. Digits inside a name stay. */
    private val dateTime = listOf(
        Regex("""[\s,]*\b\d{1,2}:\d{2}(?::\d{2})?(?:\s*[ap]m)?\b""", RegexOption.IGNORE_CASE),
        Regex("""(?:\s+on)?\s+\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b""", RegexOption.IGNORE_CASE),
        Regex("""(?:\s+on)?\s+\d{1,2}\s+(?:$months)[a-z]*\.?,?\s+\d{2,4}\b""", RegexOption.IGNORE_CASE)
    )

    fun clean(raw: String?): String? {
        if (raw.isNullOrBlank()) return null
        var value = raw.trim()
            .trim('"', '\'', '“', '”', '‘', '’')
            .trim()

        for (pattern in dateTime) {
            value = value.replace(pattern, "").trim()
        }
        for (pattern in trailingJunk) {
            value = value.replace(pattern, "").trim()
        }

        value = value
            .trim('-', ':', '·', '•', ',', ';', '|')
            .replace(Regex("""\s{2,}"""), " ")
            .trim()

        return value.takeIf { it.length >= 2 }
    }
}
