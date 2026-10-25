package com.expensetracker.app.parser

import com.expensetracker.app.data.TransactionType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigDecimal

class PaymentRulesTest {
    private val MAYBANK = "com.maybank2u.life"
    private val TNG = "my.com.tngdigital.ewallet"
    private val WALLET = "com.google.android.apps.walletnfcrel"
    private val OTHER = "com.example.bank"

    private fun known(pkg: String, text: String, amount: String, merchant: String?, type: TransactionType) {
        val match = PaymentRules.match(pkg, text)
        assertTrue(match is RuleMatch.Matched)
        match as RuleMatch.Matched
        assertEquals(CaptureFormat.KNOWN, match.format)
        assertEquals(BigDecimal(amount), match.expense.amount)
        assertEquals(merchant, match.expense.merchant)
        assertEquals(type, match.expense.transactionType)
        assertEquals(true, match.expense.directionClear)
    }

    /** Catch-all: an amount with no strict shape becomes an UNKNOWN card. */
    private fun caught(pkg: String, text: String, amount: String, type: TransactionType, clear: Boolean) {
        val match = PaymentRules.match(pkg, text)
        assertTrue(match is RuleMatch.Matched)
        match as RuleMatch.Matched
        assertEquals(CaptureFormat.UNKNOWN, match.format)
        assertEquals(BigDecimal(amount), match.expense.amount)
        assertEquals(type, match.expense.transactionType)
        assertEquals(clear, match.expense.directionClear)
    }

    @Test
    fun maybank_cardSpend() = known(MAYBANK, "You've just spent RM 23.40 at KEDAI RUNCIT AMAN with your Maybank Debit Card Visa ending 1234. View your receipt now.", "23.40", "KEDAI RUNCIT AMAN", TransactionType.WITHDRAW)

    @Test
    fun maybank_qrPayment() = known(MAYBANK, "Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.", "15.00", "RESTORAN CONTOH", TransactionType.WITHDRAW)

    @Test
    fun maybank_qrPaymentRefSuffix() = known(MAYBANK, "Successful payment of RM 8.00 to KOPI CONTOH. REF: 123456Q.", "8.00", "KOPI CONTOH", TransactionType.WITHDRAW)

    @Test
    fun maybank_m2uPaid() = known(MAYBANK, "M2U: You have successfully paid RM12.00 to CONTOH SDN BHD.", "12.00", "CONTOH SDN BHD", TransactionType.WITHDRAW)

    @Test
    fun maybank_transfer() = known(MAYBANK, "You've transferred RM 50.00 to ALI BIN ABU. REF: 123456M", "50.00", "ALI BIN ABU", TransactionType.WITHDRAW)

    @Test
    fun maybank_withdrawal() = known(MAYBANK, "You've successfully withdrawn RM 100.00 from your account ending 1234.", "100.00", "ATM withdrawal", TransactionType.WITHDRAW)

    @Test
    fun maybank_received() = known(MAYBANK, "You've received RM 40.00 from SITI AMINAH. REF: 123456Q", "40.00", "SITI AMINAH", TransactionType.RECEIVE)

    @Test
    fun maybank_receivedToAccount() = known(MAYBANK, "You've just received RM 40.00 in your account ending ***1234. REF: 123ABC456", "40.00", null, TransactionType.RECEIVE)

    @Test
    fun tng_paid() = known(TNG, "You have paid RM12.50 to CONTOH CAFE.", "12.50", "CONTOH CAFE", TransactionType.WITHDRAW)

    @Test
    fun tng_transferred() = known(TNG, "RM 30.00 has been successfully transferred to ALI BIN ABU.", "30.00", "ALI BIN ABU", TransactionType.WITHDRAW)

    @Test
    fun tng_transferredWithPrefix() = known(TNG, "Transfer Successful. RM 30.00 has been successfully transferred to ALI BIN ABU.", "30.00", "ALI BIN ABU", TransactionType.WITHDRAW)

    @Test
    fun tng_received() = known(TNG, "RM 20.00 received from SITI AMINAH.", "20.00", "SITI AMINAH", TransactionType.RECEIVE)

    @Test
    fun maybank_transferLimit_caughtUnclear() = caught(MAYBANK, "Your new transfer limit of RM 5000.00 for Interbank Transfer will be reflected after 12 hour(s). Not you? Call Maybank now.", "5000.00", TransactionType.WITHDRAW, false)

    @Test
    fun maybank_rateOffer_noMatch() = assertEquals(RuleMatch.NoMatch, PaymentRules.match(MAYBANK, "Get eIFD-i rates up to 3.85% via FPX."))

    @Test
    fun maybank_promotionWithPaymentWord_caughtUnclear() = caught(MAYBANK, "Pay RM1 and win a trip! Spend RM 50 at any partner to join.", "1.00", TransactionType.WITHDRAW, false)

    @Test
    fun tng_promoWithAmount_nowCaught() = caught(TNG, "Harga emas turun hari ini. Miliki emas mulai RM10 saja dengan TNG eWallet!", "10.00", TransactionType.WITHDRAW, false)

    @Test
    fun tng_discountPromo_caughtUnclear() = caught(TNG, "Kamu kebagian akses ke Payday Flash Deals! Klaim diskon RM50 buat tiket pesawat.", "50.00", TransactionType.WITHDRAW, false)

    @Test
    fun googleWallet_cardTap_caughtUnclear() = caught(WALLET, "MYR23.40 with Maybank Visa Platinum Debit ••1234", "23.40", TransactionType.WITHDRAW, false)

    @Test
    fun maybank_unknownShape_fallsBackToGeneric() = caught(MAYBANK, "Payment RM 12.30 to CONTOH MART is successful.", "12.30", TransactionType.WITHDRAW, true)

    @Test
    fun genericRule_creditWordOnly_receivedClear() = caught(OTHER, "RM 25.00 credited to your wallet.", "25.00", TransactionType.RECEIVE, true)

    @Test
    fun genericRule_bothWords_unclear() = caught(OTHER, "Refund for payment RM 9.90 is on the way.", "9.90", TransactionType.WITHDRAW, false)

    @Test
    fun knownApp_noAmount_noMatch() = assertEquals(RuleMatch.NoMatch, PaymentRules.match(MAYBANK, "Your statement is ready."))

    @Test
    fun unknownApp_noAmount_noMatch() = assertEquals(RuleMatch.NoMatch, PaymentRules.match(OTHER, "Your statement is ready"))

    @Test
    fun maybank_qrPaymentDottedName() = known(MAYBANK, "Successful payment of RM 9.80 to CONTOHKITCHENSDN.BHD.. REF: QR123456.", "9.80", "CONTOHKITCHENSDN.BHD", TransactionType.WITHDRAW)

    @Test
    fun maybank_m2uPaidSdnBhd() = known(MAYBANK, "M2U: You have successfully paid RM12.00 to CONTOH SDN. BHD.", "12.00", "CONTOH SDN. BHD", TransactionType.WITHDRAW)

    @Test
    fun tng_paidAbbreviations() = known(TNG, "You have paid RM7.50 to M.R. CONTOH (M) S/B.", "7.50", "M.R. CONTOH (M) S/B", TransactionType.WITHDRAW)

    @Test
    fun tng_paidThenBalanceSentence() = known(TNG, "You have paid RM7.50 to CAFE CONTOH. Balance RM20.00.", "7.50", "CAFE CONTOH", TransactionType.WITHDRAW)

    @Test
    fun maybank_qrPaymentThenTransactionId() = known(MAYBANK, "Successful payment of RM 9.80 to KEDAI CONTOH. Transaction ID 123456.", "9.80", "KEDAI CONTOH", TransactionType.WITHDRAW)

    @Test
    fun tng_receivedSenderFirst() = known(TNG, "ALI BIN ABU has transferred RM 10.00 to you. Tap here to check the transaction details.", "10.00", "ALI BIN ABU", TransactionType.RECEIVE)

    @Test
    fun maybank_transferToEwalletAccount() = known(MAYBANK, "You've transferred RM 10.00 to SITI AMINAH's TOUCH N GO eWALLET account ending ****1234. REF: 123456789M", "10.00", "SITI AMINAH's TOUCH N GO eWALLET", TransactionType.WITHDRAW)

    @Test
    fun unknownApp_genericMatch() {
        val match = PaymentRules.match(OTHER, "You spent RM 14.23 at Contoh Mart") as RuleMatch.Matched
        assertEquals(CaptureFormat.UNKNOWN, match.format)
        assertEquals(BigDecimal("14.23"), match.expense.amount)
        assertEquals("Contoh Mart", match.expense.merchant)
        assertEquals(TransactionType.WITHDRAW, match.expense.transactionType)
        assertEquals(true, match.expense.directionClear)
    }

    @Test
    fun preselectPackages_areMaybankAndTngOnly() {
        assertEquals(setOf(MAYBANK, TNG), PaymentRules.PRESELECT_PACKAGES)
        assertTrue(WALLET in PaymentRules.KNOWN_PACKAGES)
    }
}
