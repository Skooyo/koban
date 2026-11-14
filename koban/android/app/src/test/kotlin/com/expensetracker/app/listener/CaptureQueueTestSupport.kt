package com.expensetracker.app.listener

/** Closes the shared queue and clears the log, so each test starts with a new file. */
object CaptureQueueTestSupport {
    fun reset() {
        val field = CaptureQueue::class.java.getDeclaredField("instance")
        field.isAccessible = true
        (field.get(null) as CaptureQueue?)?.close()
        field.set(null, null)
        RecentNotificationsStore.clear()
    }
}
