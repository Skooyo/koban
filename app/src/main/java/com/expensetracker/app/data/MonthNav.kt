package com.expensetracker.app.data

import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Month stepping for the Activity month bar. › stops at the current month. */
object MonthNav {
    private val labelFormat = DateTimeFormatter.ofPattern("MMMM yyyy", Locale.ENGLISH)

    fun previous(m: YearMonth): YearMonth = m.minusMonths(1)

    fun next(m: YearMonth, current: YearMonth): YearMonth? =
        if (m >= current) null else m.plusMonths(1)

    fun label(m: YearMonth): String = m.format(labelFormat)
}
