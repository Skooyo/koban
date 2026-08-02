package com.expensetracker.app.data

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Calendar
import java.util.concurrent.TimeUnit

class PeriodCalculatorTest {

    @Test
    fun weekRange_isMondayToSunday() {
        val anchor = Calendar.getInstance().apply {
            set(2026, Calendar.JUNE, 24, 15, 30, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val (start, end) = PeriodCalculator.range(SpendingPeriod.WEEK, anchor)

        val startCal = Calendar.getInstance().apply { timeInMillis = start }
        val endCal = Calendar.getInstance().apply { timeInMillis = end }

        assertEquals(Calendar.MONDAY, startCal.get(Calendar.DAY_OF_WEEK))
        assertEquals(Calendar.MONDAY, endCal.get(Calendar.DAY_OF_WEEK))
        assertEquals(7, TimeUnit.MILLISECONDS.toDays(end - start))
        assert(start <= anchor.timeInMillis && anchor.timeInMillis < end)
    }

    @Test
    fun monthRange_isCalendarMonth() {
        val midMonth = Calendar.getInstance().apply {
            set(2026, Calendar.JUNE, 15, 12, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val (start, end) = PeriodCalculator.range(SpendingPeriod.MONTH, midMonth)

        val startCal = Calendar.getInstance().apply { timeInMillis = start }
        val endCal = Calendar.getInstance().apply { timeInMillis = end }

        assertEquals(1, startCal.get(Calendar.DAY_OF_MONTH))
        assertEquals(Calendar.JUNE, startCal.get(Calendar.MONTH))
        assertEquals(1, endCal.get(Calendar.DAY_OF_MONTH))
        assertEquals(Calendar.JULY, endCal.get(Calendar.MONTH))
    }
}
