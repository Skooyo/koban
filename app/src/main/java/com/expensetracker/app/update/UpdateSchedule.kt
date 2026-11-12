package com.expensetracker.app.update

object UpdateSchedule {
    const val CHECK_INTERVAL_MS = 86_400_000L

    fun shouldCheck(online: Boolean, lastCheckMs: Long, nowMs: Long, manual: Boolean): Boolean =
        online && (manual || nowMs < lastCheckMs || nowMs - lastCheckMs >= CHECK_INTERVAL_MS)
}
