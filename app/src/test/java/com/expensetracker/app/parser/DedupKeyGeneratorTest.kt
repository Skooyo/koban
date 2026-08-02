package com.expensetracker.app.parser

import org.junit.Assert.assertEquals
import org.junit.Test
import java.math.BigDecimal

class DedupKeyGeneratorTest {

    @Test
    fun sameInputs_sameBucket_produceSameKey() {
        val postTime = 1_700_000_000_000L
        val key1 = DedupKeyGenerator.generate("com.app", BigDecimal("14.23"), "Starbucks", postTime)
        val key2 = DedupKeyGenerator.generate("com.app", BigDecimal("14.23"), "Starbucks", postTime + 1000)
        assertEquals(key1, key2)
    }

    @Test
    fun differentAmounts_produceDifferentKeys() {
        val postTime = 1_700_000_000_000L
        val key1 = DedupKeyGenerator.generate("com.app", BigDecimal("14.23"), "Starbucks", postTime)
        val key2 = DedupKeyGenerator.generate("com.app", BigDecimal("15.00"), "Starbucks", postTime)
        assert(key1 != key2)
    }

    @Test
    fun differentMerchants_sameAmount_produceSameKey() {
        val postTime = 1_700_000_000_000L
        val key1 = DedupKeyGenerator.generate("com.app", BigDecimal("14.23"), "Starbucks", postTime)
        val key2 = DedupKeyGenerator.generate("com.app", BigDecimal("14.23"), "STARBUCKS SDN BHD", postTime)
        assertEquals(key1, key2)
    }
}
