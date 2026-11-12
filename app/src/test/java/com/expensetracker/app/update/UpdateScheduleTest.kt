package com.expensetracker.app.update

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UpdateScheduleTest {
    @Test fun offline_neverChecks() = assertFalse(UpdateSchedule.shouldCheck(false, 0, 100_000_000, manual = true))

    @Test fun manual_checksAtOnce() = assertTrue(UpdateSchedule.shouldCheck(true, 99_999_999, 100_000_000, manual = true))

    @Test fun auto_waitsOneDay() = assertFalse(UpdateSchedule.shouldCheck(true, 100_000_000, 100_000_000 + 86_399_999, false))

    @Test fun auto_afterOneDay() = assertTrue(UpdateSchedule.shouldCheck(true, 100_000_000, 100_000_000 + 86_400_000, false))
}
