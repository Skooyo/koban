package com.expensetracker.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.YearMonth

class MonthNavTest {

    private val current = YearMonth.of(2026, 10)

    @Test
    fun previousCrossesYearBoundary() {
        assertEquals(YearMonth.of(2025, 12), MonthNav.previous(YearMonth.of(2026, 1)))
    }

    @Test
    fun nextCrossesYearBoundary() {
        assertEquals(YearMonth.of(2026, 1), MonthNav.next(YearMonth.of(2025, 12), current))
    }

    @Test
    fun nextIsNullOnCurrentMonth() {
        assertNull(MonthNav.next(current, current))
    }

    @Test
    fun nextIsNullAfterCurrentMonth() {
        assertNull(MonthNav.next(YearMonth.of(2026, 11), current))
    }

    @Test
    fun labelIsFullMonthNameAndYear() {
        assertEquals("October 2026", MonthNav.label(current))
    }
}
