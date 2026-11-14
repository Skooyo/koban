package io.github.skooyo.koban

import android.content.Context
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import com.expensetracker.app.listener.CaptureQueue
import com.expensetracker.app.listener.CaptureQueueTestSupport
import com.expensetracker.app.listener.CapturedNotification
import com.expensetracker.app.listener.NotificationDisposition
import com.expensetracker.app.listener.PaymentAppsMirror
import com.expensetracker.app.listener.QueuedNotification
import com.expensetracker.app.listener.RecentNotificationsStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.FlutterException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executor
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/** Keeps the handlers by channel name and sends standard method calls to them. */
class FakeMessenger : BinaryMessenger {
    val handlers = mutableMapOf<String, BinaryMessenger.BinaryMessageHandler>()

    override fun send(channel: String, message: ByteBuffer?) = Unit
    override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) = Unit
    override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
        if (handler == null) handlers.remove(channel) else handlers[channel] = handler
    }

    /** Sends a call and returns the raw reply, or null when no reply came yet. */
    fun send(channel: String, method: String, args: Any? = null): ByteBuffer? {
        val message = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, args)).also { it.rewind() }
        var reply: ByteBuffer? = null
        handlers.getValue(channel).onMessage(message) { reply = it }
        shadowOf(Looper.getMainLooper()).idle()
        return reply
    }

    /** Returns the success value. Throws [FlutterException] for an error reply. */
    fun call(channel: String, method: String, args: Any? = null): Any? {
        val reply = send(channel, method, args)
        assertNotNull("no reply to $method", reply)
        return StandardMethodCodec.INSTANCE.decodeEnvelope(reply!!.also { it.rewind() })
    }
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class KobanNativePluginTest {
    private val capture = "io.github.skooyo.koban/capture"
    private val legacy = "io.github.skooyo.koban/legacy"
    private val text = "Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456."
    private val direct = Executor { it.run() }
    private lateinit var context: Context
    private lateinit var messenger: FakeMessenger
    private lateinit var queue: CaptureQueue

    @Before fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        CaptureQueueTestSupport.reset()
        queue = CaptureQueue.get(context)
        messenger = FakeMessenger()
        KobanNativePlugin(direct).register(context, messenger)
    }

    @After fun tearDown() = CaptureQueueTestSupport.reset()

    private fun queueMaybankRow() {
        RecentNotificationsStore.add(
            CapturedNotification(id = "L", packageName = "com.maybank2u.life", title = "Maybank", body = text, postTime = 1000L),
        )
        queue.add(
            QueuedNotification(
                logId = "L",
                packageName = "com.maybank2u.life",
                title = "Maybank",
                text = text,
                postTime = 1000L,
                notificationKey = "0|com.maybank2u.life|1|null|10001",
            ),
        )
    }

    @Test fun registersTheThreeChannelsOnAnyEngine() {
        assertEquals(
            setOf("io.github.skooyo.koban/legacy", capture, "io.github.skooyo.koban/listener"),
            messenger.handlers.keys,
        )
    }

    @Test fun takeQueueGivesRowsAndFinishRemovesThem() {
        queueMaybankRow()
        @Suppress("UNCHECKED_CAST")
        val rows = messenger.call(capture, "takeQueue", mapOf("afterId" to 0L)) as List<Map<String, Any?>>
        val row = rows.single()
        assertEquals("com.maybank2u.life", row["packageName"])
        assertEquals("L", row["logId"])
        assertEquals(text, row["text"])
        messenger.call(
            capture,
            "finish",
            mapOf("id" to row["id"], "logId" to "L", "disposition" to "WAITING", "detail" to "RESTORAN CONTOH - RM 15.00"),
        )
        assertEquals(0, queue.size())
        val log = RecentNotificationsStore.snapshot().single()
        assertEquals(NotificationDisposition.WAITING, log.disposition)
        assertEquals("RESTORAN CONTOH - RM 15.00", log.detail)
    }

    @Test fun takeQueueGivesUpARowAfterFiveTries() {
        queueMaybankRow()
        repeat(CaptureQueue.MAX_ATTEMPTS) {
            assertEquals(1, (messenger.call(capture, "takeQueue", mapOf("afterId" to 0L)) as List<*>).size)
        }
        assertEquals(emptyList<Any>(), messenger.call(capture, "takeQueue", mapOf("afterId" to 0L)))
        assertEquals(0, queue.size())
        val log = RecentNotificationsStore.snapshot().single()
        assertEquals(NotificationDisposition.SKIPPED_ERROR, log.disposition)
        assertEquals("Gave up after 5 tries", log.detail)
    }

    @Test fun appendLogAddsARowForTheAppItself() {
        messenger.call(capture, "appendLog", mapOf("title" to "T", "body" to "B", "disposition" to "INFO_ONLY", "detail" to "D"))
        val log = RecentNotificationsStore.snapshot().single()
        assertEquals(context.packageName, log.packageName)
        assertEquals("B", log.body)
        assertEquals(NotificationDisposition.INFO_ONLY, log.disposition)
        assertEquals("D", log.detail)
    }

    @Test fun setPaymentAppsWritesTheNativeCopy() {
        messenger.call(capture, "setPaymentApps", mapOf("apps" to listOf("a", "b")))
        assertEquals(setOf("a", "b"), PaymentAppsMirror.read(context))
    }

    @Test fun readSettingsAnswersWithTheErrorCodeWhenAFileIsCorrupt() {
        val dir = File(context.filesDir, "datastore").also { it.mkdirs() }
        File(dir, "settings.preferences_pb").writeBytes(ByteArray(40) { 0x7F })
        try {
            messenger.call(legacy, "readSettings")
            fail("expected an error reply")
        } catch (e: FlutterException) {
            assertEquals("LEGACY_SETTINGS", e.code)
        }
    }

    @Test fun databasePathPointsToTheLegacyFile() {
        val path = messenger.call(legacy, "databasePath") as String
        assertTrue(path.endsWith("expense_tracker.db"))
    }

    @Test fun aGateWaiterGetsItsReplyAfterTheFirstOwnerReleases() {
        val other = Any()
        ImportGate.acquire(other) {}
        try {
            var reply: ByteBuffer? = null
            val message = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall("acquireImportGate", null)).also { it.rewind() }
            messenger.handlers.getValue(capture).onMessage(message) { reply = it }
            shadowOf(Looper.getMainLooper()).idle()
            assertNull(reply)
            ImportGate.release(other)
            shadowOf(Looper.getMainLooper()).idle()
            assertNull(StandardMethodCodec.INSTANCE.decodeEnvelope(reply!!.also { it.rewind() }))
            // The plugin holds the gate now. Release it so the next test starts free.
            assertNull(messenger.call(capture, "releaseImportGate"))
        } finally {
            ImportGate.forget(other)
        }
    }

    @Test fun finishWithABadDispositionKeepsTheRow() {
        queueMaybankRow()
        val id = (messenger.call(capture, "takeQueue", mapOf("afterId" to 0L)) as List<*>).let { (it.single() as Map<*, *>)["id"] }
        try {
            messenger.call(capture, "finish", mapOf("id" to id, "logId" to "L", "disposition" to "BAD", "detail" to null))
            fail("expected an error reply")
        } catch (e: FlutterException) {
            assertEquals("NATIVE_ERROR", e.code)
        }
        assertEquals(1, queue.size())
        assertEquals(NotificationDisposition.PENDING, RecentNotificationsStore.snapshot().single().disposition)
    }

    @Test fun aCallAfterDetachGetsAnErrorReply() {
        val pool = java.util.concurrent.Executors.newSingleThreadExecutor()
        val plugin = KobanNativePlugin(pool)
        val m = FakeMessenger()
        plugin.register(context, m)
        plugin.detach()
        try {
            m.call(capture, "updateLog", mapOf("logId" to "L", "disposition" to "WAITING"))
            fail("expected an error reply")
        } catch (e: FlutterException) {
            assertEquals("NATIVE_ERROR", e.code)
        }
    }
}
