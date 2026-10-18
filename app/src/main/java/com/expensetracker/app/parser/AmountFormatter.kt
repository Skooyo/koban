package com.expensetracker.app.parser

import java.math.BigDecimal
import java.math.RoundingMode
import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.util.Locale

object AmountFormatter {
    private const val SCALE = 2

    fun toMoney(value: BigDecimal): BigDecimal =
        value.setScale(SCALE, RoundingMode.HALF_UP)

    fun formatDisplay(value: BigDecimal): String = toMoney(value).toPlainString()

    /** "1,284.10" for screens. Edit fields keep [formatDisplay] so the text parses back. */
    fun formatGrouped(value: BigDecimal): String =
        DecimalFormat("#,##0.00", DecimalFormatSymbols(Locale.US)).format(toMoney(value))

    /** "RM" for ringgit, otherwise the currency code. */
    fun currencySymbol(currency: String): String = if (currency == "MYR") "RM" else currency

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
