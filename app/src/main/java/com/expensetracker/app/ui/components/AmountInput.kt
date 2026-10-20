package com.expensetracker.app.ui.components

import com.expensetracker.app.parser.AmountFormatter
import java.math.BigDecimal

/** Number-pad rules for the payment amount. `text` is the raw typed string: no "RM", no grouping. */
object AmountInput {
    const val MAX_WHOLE_DIGITS = 9

    fun press(text: String, key: Char): String {
        if (key == '.') {
            return when {
                text.contains('.') -> text
                text.isEmpty() -> "0."
                else -> "$text."
            }
        }
        if (key !in '0'..'9') return text
        if (text == "0") return key.toString()
        if (text.contains('.')) {
            return if (text.substringAfter('.').length >= 2) text else text + key
        }
        return if (text.length >= MAX_WHOLE_DIGITS) text else text + key
    }

    fun backspace(text: String): String = text.dropLast(1)

    fun toAmount(text: String): BigDecimal? =
        AmountFormatter.parseInput(text)?.takeIf { it.signum() != 0 }

    fun fromAmount(amount: BigDecimal): String =
        if (amount.signum() == 0) "" else AmountFormatter.formatDisplay(amount)
}
