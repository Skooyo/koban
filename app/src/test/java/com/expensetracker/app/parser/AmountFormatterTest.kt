package com.expensetracker.app.parser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.math.BigDecimal

class AmountFormatterTest {

    @Test
    fun toMoney_roundsToTwoDecimals() {
        assertEquals(BigDecimal("14.23"), AmountFormatter.toMoney(BigDecimal("14.234")))
        assertEquals(BigDecimal("14.24"), AmountFormatter.toMoney(BigDecimal("14.235")))
    }

    @Test
    fun formatDisplay_alwaysShowsTwoDecimals() {
        assertEquals("10.00", AmountFormatter.formatDisplay(BigDecimal("10")))
        assertEquals("14.50", AmountFormatter.formatDisplay(BigDecimal("14.5")))
    }

    @Test
    fun formatGrouped_usesThousandsSeparatorWhateverTheDeviceLocale() {
        val original = java.util.Locale.getDefault()
        try {
            java.util.Locale.setDefault(java.util.Locale.GERMANY)
            assertEquals("1,284.10", AmountFormatter.formatGrouped(BigDecimal("1284.1")))
            assertEquals("0.50", AmountFormatter.formatGrouped(BigDecimal("0.499")))
        } finally {
            java.util.Locale.setDefault(original)
        }
    }

    @Test
    fun parseInput_normalizesInput() {
        assertEquals(BigDecimal("1.23"), AmountFormatter.parseInput("1.234"))
        assertEquals(BigDecimal("1234.56"), AmountFormatter.parseInput("1,234.56"))
    }

    @Test
    fun parseInput_invalidReturnsNull() {
        assertNull(AmountFormatter.parseInput(""))
        assertNull(AmountFormatter.parseInput("abc"))
    }
}
