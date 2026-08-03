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
        assertEquals("VINCENT WESLEY LIEM", MerchantNormalizer.clean("VINCENT WESLEY LIEM"))
    }

    @Test
    fun blankBecomesNull() {
        assertNull(MerchantNormalizer.clean("  "))
        assertNull(MerchantNormalizer.clean(null))
    }
}
