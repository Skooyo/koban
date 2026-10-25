package com.expensetracker.app.parser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class MerchantNormalizerTest {

    @Test
    fun stripsMaybankDebitCardTail() {
        val cleaned = MerchantNormalizer.clean(
            "KK - SUPER MART - UMN with your Maybank Debit Card Visa ending with 3729"
        )
        assertEquals("KK - SUPER MART - UMN", cleaned)
    }

    @Test
    fun leavesCleanMerchantAlone() {
        assertEquals("Starbucks", MerchantNormalizer.clean("Starbucks"))
        assertEquals("AISYAH NUR RAHMAN", MerchantNormalizer.clean("AISYAH NUR RAHMAN"))
    }

    @Test
    fun blankBecomesNull() {
        assertNull(MerchantNormalizer.clean("  "))
        assertNull(MerchantNormalizer.clean(null))
    }

    @Test
    fun clean_stripsTrailingDate() {
        assertEquals("KEDAI CONTOH", MerchantNormalizer.clean("KEDAI CONTOH 20/10/2026"))
    }

    @Test
    fun clean_stripsDateAndTime() {
        assertEquals("KEDAI CONTOH", MerchantNormalizer.clean("KEDAI CONTOH on 20 Oct 2026, 12:45"))
    }

    @Test
    fun clean_keepsNumbersInName() {
        assertEquals("99 SPEEDMART 1234", MerchantNormalizer.clean("99 SPEEDMART 1234"))
    }
}
