package com.expensetracker.app.listener

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class CaptureQueueTest {
    private lateinit var context: Context
    private lateinit var q: CaptureQueue

    @Before fun open() {
        context = ApplicationProvider.getApplicationContext()
        q = CaptureQueue(context, "test_queue.db")
    }

    @After fun close() {
        q.close()
        context.deleteDatabase("test_queue.db")
    }

    private fun row(key: String? = null, postTime: Long = 1, text: String = "t", logId: String = "id") =
        QueuedNotification(logId = logId, packageName = "com.maybank2u.life", title = null, text = text, postTime = postTime, notificationKey = key)

    @Test fun rowsComeBackOldestFirstAfterTheGivenId() {
        q.add(row(key = "a", postTime = 1, logId = "a"))
        q.add(row(key = "b", postTime = 2, logId = "b"))
        q.add(row(key = "c", postTime = 3, logId = "c"))
        assertEquals(listOf("a", "b", "c"), q.take(afterId = 0, limit = 20).map { it.logId })
        val firstId = q.take(afterId = 0, limit = 20).first().id
        assertEquals(listOf("b", "c"), q.take(afterId = firstId, limit = 20).map { it.logId })
    }

    @Test fun theSamePostIsQueuedOnce() {
        assertTrue(q.add(row(key = "k1", postTime = 1000, text = "t")))
        assertFalse(q.add(row(key = "k1", postTime = 1000, text = "t")))
        assertEquals(1, q.size())
    }

    @Test fun theSameKeyWithAnotherPostTimeIsANewRow() {
        assertTrue(q.add(row(key = "k1", postTime = 1000, text = "t")))
        assertTrue(q.add(row(key = "k1", postTime = 2000, text = "t")))
        assertEquals(2, q.size())
    }

    @Test fun rowsStayAfterTheQueueOpensAgain() {
        q.add(row(key = "k1", postTime = 1000, text = "RM 15.00")); q.close()
        val again = CaptureQueue(context, "test_queue.db")
        assertEquals(listOf("RM 15.00"), again.take(0).map { it.text })
        again.close()
    }

    @Test fun takeCountsTriesAndGiveUpRemovesTheRowAfterFive() {
        q.add(row(key = "k1", postTime = 1000, text = "t"))
        repeat(4) { q.take(0) }
        assertEquals(emptyList<QueuedNotification>(), q.giveUp())
        q.take(0)
        assertEquals(listOf(5), q.giveUp().map { it.attempts })
        assertEquals(0, q.size())
    }

    @Test fun removeDeletesOneRow() {
        q.add(row(key = "a", postTime = 1, logId = "a"))
        q.add(row(key = "b", postTime = 2, logId = "b"))
        q.remove(q.take(0).first().id)
        assertEquals(listOf("b"), q.take(0).map { it.logId })
        assertEquals(1, q.size())
    }

    @Test fun aRowThatKeepsFailingDoesNotUseTheTriesOfOtherRows() {
        q.add(row(key = "a", postTime = 1, logId = "a"))
        q.add(row(key = "b", postTime = 2, logId = "b"))
        q.add(row(key = "c", postTime = 3, logId = "c"))
        repeat(5) { q.take(0) }
        assertEquals(listOf("a"), q.giveUp().map { it.logId })
        assertEquals(listOf(1, 1), q.take(0, limit = 20).map { it.attempts })
    }
}
