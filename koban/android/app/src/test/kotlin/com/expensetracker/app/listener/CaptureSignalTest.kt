package com.expensetracker.app.listener

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import io.flutter.embedding.engine.FlutterEngine
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class CaptureSignalTest {
    private lateinit var context: Context
    private val originalStart = CaptureEngine.startEngine

    @Before fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        CaptureQueueTestSupport.reset()
    }

    @After fun tearDown() {
        CaptureSignal.wake = {}
        CaptureEngine.startEngine = originalStart
        CaptureQueueTestSupport.reset()
    }

    private fun queueOneRow() {
        CaptureQueue.get(context).add(
            QueuedNotification(logId = "L", packageName = "com.maybank2u.life", title = null, text = "t", postTime = 1, notificationKey = "k"),
        )
    }

    @Test fun aWakeThatThrowsDoesNotReachTheCaller() {
        queueOneRow()
        var calls = 0
        CaptureSignal.wake = { calls++; throw IllegalStateException("boom") }
        CaptureSignal.wakeIfQueued(context)
        assertEquals(1, calls)
    }

    @Test fun aQueueThatThrowsDoesNotReachTheCaller() {
        queueOneRow()
        CaptureQueue.get(context).close()
        // A folder in place of the file makes every open fail.
        context.getDatabasePath("capture_queue.db").let { it.delete(); it.mkdirs() }
        try {
            CaptureQueue.get(context).size()
            fail("the corrupt queue must throw")
        } catch (e: Exception) {
        }
        var calls = 0
        CaptureSignal.wake = { calls++ }
        CaptureSignal.wakeIfQueued(context)
        assertEquals(0, calls)
    }

    @Test fun anEngineThatFailsToStartKeepsNothingAndTheNextWakeTriesAgain() {
        var starts = 0
        CaptureEngine.startEngine = { _, _ -> starts++; throw IllegalStateException("no engine") }
        CaptureEngine.wake(context)
        assertFalse(CaptureEngine.isRunning)
        CaptureEngine.wake(context)
        assertFalse(CaptureEngine.isRunning)
        assertEquals(2, starts)
    }
}
