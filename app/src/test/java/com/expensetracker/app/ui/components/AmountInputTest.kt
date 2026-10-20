package com.expensetracker.app.ui.components

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.math.BigDecimal

class AmountInputTest {

    @Test
    fun press_digitOnEmpty_startsNumber() {
        assertEquals("5", AmountInput.press("", '5'))
    }

    @Test
    fun press_dotOnEmpty_addsLeadingZero() {
        assertEquals("0.", AmountInput.press("", '.'))
    }

    @Test
    fun press_digitAfterZero_replacesZero() {
        assertEquals("7", AmountInput.press("0", '7'))
        assertEquals("0", AmountInput.press("0", '0'))
    }

    @Test
    fun press_secondDot_ignored() {
        assertEquals("12.", AmountInput.press("12.", '.'))
    }

    @Test
    fun press_thirdDecimal_ignored() {
        assertEquals("12.34", AmountInput.press("12.34", '5'))
    }

    @Test
    fun press_ninthWholeDigit_allowed_tenthIgnored() {
        assertEquals("123456789", AmountInput.press("123456789", '1'))
        assertEquals("123456789.", AmountInput.press("123456789", '.'))
    }

    @Test
    fun backspace_removesLastCharacter() {
        assertEquals("12.", AmountInput.backspace("12.5"))
        assertEquals("", AmountInput.backspace("1"))
        assertEquals("", AmountInput.backspace(""))
    }

    @Test
    fun toAmount_emptyOrZero_returnsNull() {
        assertNull(AmountInput.toAmount(""))
        assertNull(AmountInput.toAmount("0."))
        assertNull(AmountInput.toAmount("0.00"))
    }

    @Test
    fun toAmount_returnsTwoDecimals() {
        assertEquals(BigDecimal("12.50"), AmountInput.toAmount("12.5"))
    }

    @Test
    fun fromAmount_keepsTwoDecimals() {
        assertEquals("12.50", AmountInput.fromAmount(BigDecimal("12.50")))
    }

    @Test
    fun fromAmount_zeroIsEmpty() {
        assertEquals("", AmountInput.fromAmount(BigDecimal("0.00")))
    }
}
