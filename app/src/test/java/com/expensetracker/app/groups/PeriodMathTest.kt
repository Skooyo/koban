package com.expensetracker.app.groups

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

class PeriodMathTest {
    @Test
    fun weekStartsOnMonday() {
        // Thu 12 Nov 2026 -> Mon 9 Nov; a Monday is its own start; Sun 15 Nov still belongs to Mon 9.
        assertEquals(LocalDate.of(2026, 11, 9), GroupRepository.periodStart(LocalDate.of(2026, 11, 12), Period.WEEK))
        assertEquals(LocalDate.of(2026, 11, 9), GroupRepository.periodStart(LocalDate.of(2026, 11, 9), Period.WEEK))
        assertEquals(LocalDate.of(2026, 11, 9), GroupRepository.periodStart(LocalDate.of(2026, 11, 15), Period.WEEK))
        // A week across a month end starts in the earlier month.
        assertEquals(LocalDate.of(2026, 11, 30), GroupRepository.periodStart(LocalDate.of(2026, 12, 2), Period.WEEK))
    }

    @Test
    fun monthStartsOnTheFirst() {
        assertEquals(LocalDate.of(2026, 11, 1), GroupRepository.periodStart(LocalDate.of(2026, 11, 30), Period.MONTH))
    }

    @Test
    fun daysLeftCountsToTheNextStart() {
        assertEquals(4, GroupRepository.daysLeft(Period.WEEK, LocalDate.of(2026, 11, 12)))   // Thu -> next Mon
        assertEquals(1, GroupRepository.daysLeft(Period.WEEK, LocalDate.of(2026, 11, 15)))   // Sun
        assertEquals(19, GroupRepository.daysLeft(Period.MONTH, LocalDate.of(2026, 11, 12))) // -> 1 Dec
        assertEquals(1, GroupRepository.daysLeft(Period.MONTH, LocalDate.of(2027, 2, 28)))
    }
}
