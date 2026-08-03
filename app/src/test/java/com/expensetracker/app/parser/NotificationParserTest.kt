package com.expensetracker.app.parser

import com.expensetracker.app.data.ParseConfidence
import com.expensetracker.app.data.TransactionType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import java.math.BigDecimal

class NotificationParserTest {

    @Test
    fun parse_standardRmWithSpace() {
        val result = NotificationParser.parse("You spent RM 14.23 at Starbucks")
        assertNotNull(result)
        assertEquals(BigDecimal("14.23"), result!!.amount)
        assertEquals("Starbucks", result.merchant)
        assertEquals("MYR", result.currency)
        assertEquals(ParseConfidence.HIGH, result.confidence)
    }

    @Test
    fun parse_rmWithoutSpace() {
        val result = NotificationParser.parse("Payment of RM14.23 successful")
        assertNotNull(result)
        assertEquals(BigDecimal("14.23"), result!!.amount)
    }

    @Test
    fun parse_myrCurrency() {
        val result = NotificationParser.parse("Debited MYR 1,234.56 from account")
        assertNotNull(result)
        assertEquals(BigDecimal("1234.56"), result!!.amount)
        assertEquals(ParseConfidence.HIGH, result.confidence)
    }

    @Test
    fun parse_negativeIndicator() {
        val result = NotificationParser.parse("Transaction: - RM 50.00")
        assertNotNull(result)
        assertEquals(BigDecimal("50.00"), result!!.amount)
        assertEquals(ParseConfidence.HIGH, result.confidence)
    }

    @Test
    fun parse_multipleAmounts_lowConfidence() {
        val result = NotificationParser.parse("RM 10.00 spent. Balance RM 500.00")
        assertNotNull(result)
        assertEquals(BigDecimal("10.00"), result!!.amount)
        assertEquals(ParseConfidence.LOW, result.confidence)
    }

    @Test
    fun parse_noAmount_returnsNull() {
        assertNull(NotificationParser.parse("Your payment was successful"))
    }

    @Test
    fun parse_grabPayStyle_merchantFromBody() {
        val result = NotificationParser.parse("RM 8.50 paid to ABC Mart")
        assertNotNull(result)
        assertEquals(BigDecimal("8.50"), result!!.amount)
        assertEquals("ABC Mart", result.merchant)
    }

    @Test
    fun parse_quotedMerchantToPattern() {
        val result = NotificationParser.parse("""Payment successful. To "ABC Mart" RM 12.34""")
        assertNotNull(result)
        assertEquals(BigDecimal("12.34"), result!!.amount)
        assertEquals("ABC Mart", result.merchant)
        assertEquals(ParseConfidence.HIGH, result.confidence)
    }

    @Test
    fun parse_tngStyle_merchantFromBody() {
        val result = NotificationParser.parse("You have paid RM 25.00 to Merchant XYZ")
        assertNotNull(result)
        assertEquals(BigDecimal("25.00"), result!!.amount)
        assertEquals("Merchant XYZ", result.merchant)
        assertEquals(ParseConfidence.HIGH, result.confidence)
    }

    @Test
    fun normalizeAmount_stripsCommasAndScales() {
        assertEquals(BigDecimal("1234.56"), NotificationParser.normalizeAmount("1,234.56"))
        assertEquals(BigDecimal("10.00"), NotificationParser.normalizeAmount("10"))
    }

    @Test
    fun parse_received_detectsReceiveType() {
        val result = NotificationParser.parse("You received RM 100.00 in your wallet")
        assertNotNull(result)
        assertEquals(TransactionType.RECEIVE, result!!.transactionType)
    }

    @Test
    fun parse_paid_detectsWithdrawType() {
        val result = NotificationParser.parse("You paid RM 25.00 to Merchant")
        assertNotNull(result)
        assertEquals(TransactionType.WITHDRAW, result!!.transactionType)
    }

    @Test
    fun parse_transferSuccessfulStyle() {
        val result = NotificationParser.parse(
            "RM 1.00 has been successfully transferred to VINCENT WESLEY LIEM"
        )
        assertNotNull(result)
        assertEquals(BigDecimal("1.00"), result!!.amount)
        assertEquals("VINCENT WESLEY LIEM", result.merchant)
        assertEquals(TransactionType.WITHDRAW, result.transactionType)
        assertEquals(ParseConfidence.HIGH, result.confidence)
    }

    @Test
    fun parse_maybankTransferStyle() {
        val result = NotificationParser.parse(
            "You've transferred RM 2.00 to VINCENT WESLEY LIEM"
        )
        assertNotNull(result)
        assertEquals(BigDecimal("2.00"), result!!.amount)
        assertEquals("VINCENT WESLEY LIEM", result.merchant)
        assertEquals(TransactionType.WITHDRAW, result.transactionType)
        assertEquals(ParseConfidence.HIGH, result.confidence)
    }

    @Test
    fun parse_maybankSpendAt_stripsCardTail() {
        val result = NotificationParser.parse(
            "RM 12.50 spent at KK - SUPER MART - UMN with your Maybank Debit Card Visa ending with 3729"
        )
        assertNotNull(result)
        assertEquals(BigDecimal("12.50"), result!!.amount)
        assertEquals("KK - SUPER MART - UMN", result.merchant)
    }

    @Test
    fun findAllAmounts_deduplicates() {
        val amounts = NotificationParser.findAllAmounts("RM 10.00 and RM 10.00 again")
        assertEquals(1, amounts.size)
        assertEquals(BigDecimal("10.00"), amounts.first())
    }
}
