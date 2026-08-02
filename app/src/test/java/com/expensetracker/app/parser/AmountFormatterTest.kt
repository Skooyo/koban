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
