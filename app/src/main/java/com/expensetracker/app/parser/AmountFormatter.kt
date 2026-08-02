package com.expensetracker.app.parser

import java.math.BigDecimal
import java.math.RoundingMode

object AmountFormatter {
    private const val SCALE = 2

    fun toMoney(value: BigDecimal): BigDecimal =
        value.setScale(SCALE, RoundingMode.HALF_UP)

    fun formatDisplay(value: BigDecimal): String = toMoney(value).toPlainString()

    fun parseInput(raw: String): BigDecimal? {
        return try {
            val cleaned = raw.replace(",", "").trim()
            if (cleaned.isEmpty()) return null
            toMoney(BigDecimal(cleaned))
        } catch (_: NumberFormatException) {
            null
        }
    }
}
