package com.expensetracker.app.parser

import java.math.BigDecimal
import java.security.MessageDigest

object DedupKeyGenerator {
    /** Same payment notifications often arrive twice within 30 minutes. */
    private const val DATE_BUCKET_MS = 30 * 60 * 1000L

    /**
     * Fingerprint for a payment: app + amount + time bucket (merchant excluded because
     * duplicate notifications often parse the merchant slightly differently).
     */
    fun generate(
        packageName: String,
        amount: BigDecimal,
        merchant: String?,
        postTime: Long
    ): String {
        val dateBucket = postTime / DATE_BUCKET_MS
        val normalizedAmount = AmountFormatter.toMoney(amount).toPlainString()
        val raw = "$packageName|$normalizedAmount|$dateBucket"
        return sha256(raw)
    }

    fun dedupLookbackMs(): Long = DATE_BUCKET_MS

    private fun sha256(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val hash = digest.digest(input.toByteArray(Charsets.UTF_8))
        return hash.joinToString("") { "%02x".format(it) }
    }
}
