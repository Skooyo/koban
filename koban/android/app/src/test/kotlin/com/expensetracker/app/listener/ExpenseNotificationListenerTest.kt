package com.expensetracker.app.listener

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Process
import android.os.UserHandle
import android.service.notification.StatusBarNotification
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ExpenseNotificationListenerTest {
    private lateinit var context: Context
    private lateinit var listener: ExpenseNotificationListener
    private lateinit var queue: CaptureQueue
    private var wakes = 0

    private val bank = "com.maybank2u.life"
    private val payment = "Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456."

    @Before fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        CaptureQueueTestSupport.reset()
        wakes = 0
        CaptureSignal.wake = { wakes++ }
        queue = CaptureQueue.get(context)
        context.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(NotificationChannel("test", "test", NotificationManager.IMPORTANCE_DEFAULT))
        listener = Robolectric.buildService(ExpenseNotificationListener::class.java).create().get()
    }

    @After fun tearDown() {
        CaptureSignal.wake = {}
        CaptureQueueTestSupport.reset()
    }

    private fun sbn(
        pkg: String,
        key: String,
        postTime: Long,
        text: String,
        groupSummary: Boolean = false,
    ): StatusBarNotification {
        val notification = Notification.Builder(context, "test")
            .setContentTitle("Maybank")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setGroupSummary(groupSummary)
            .build()
        // The constructor of StatusBarNotification is hidden, so use reflection.
        val ctor = StatusBarNotification::class.java.getConstructor(
            String::class.java, String::class.java, Int::class.javaPrimitiveType, String::class.java,
            Int::class.javaPrimitiveType, Int::class.javaPrimitiveType, Notification::class.java,
            UserHandle::class.java, String::class.java, Long::class.javaPrimitiveType,
        )
        return ctor.newInstance(pkg, pkg, 1, key, 1000, 1, notification, Process.myUserHandle(), null, postTime)
    }

    @Test fun paymentFromAChosenAppIsQueuedLoggedAndWakesDart() {
        PaymentAppsMirror.write(context, setOf(bank))
        listener.onNotificationPosted(sbn(bank, key = "k1", postTime = 1000, text = payment))
        val row = queue.take(0).single()
        assertEquals(payment, row.text)
        assertEquals(1000L, row.postTime)
        assertEquals(NotificationDisposition.PENDING, RecentNotificationsStore.snapshot().single().disposition)
        assertEquals(row.logId, RecentNotificationsStore.snapshot().single().id)
        assertEquals(1, wakes)
    }

    @Test fun anAppThatIsNotChosenIsNotQueuedOrLogged() {
        PaymentAppsMirror.write(context, setOf(bank))
        listener.onNotificationPosted(sbn("com.example.chat", key = "k1", postTime = 1000, text = payment))
        assertEquals(0, queue.size())
        assertEquals(0, RecentNotificationsStore.snapshot().size)
        assertEquals(0, wakes)
    }

    // Review Focus 3
    @Test fun beforeTheFirstCopyEveryAppIsQueuedAndLogged() {
        listener.onNotificationPosted(sbn("com.example.bank", key = "k1", postTime = 1000, text = payment))
        assertEquals(1, queue.size())
        assertEquals(1, RecentNotificationsStore.snapshot().size)
        assertEquals(1, wakes)
    }

    @Test fun theSamePostTwiceIsQueuedOnce() {
        PaymentAppsMirror.write(context, setOf(bank))
        val post = sbn(bank, key = "k1", postTime = 1000, text = payment)
        listener.onNotificationPosted(post)
        listener.onNotificationPosted(post)
        assertEquals(1, queue.size())
        assertEquals(
            listOf(NotificationDisposition.SKIPPED_DUPLICATE, NotificationDisposition.PENDING),
            RecentNotificationsStore.snapshot().map { it.disposition },
        )
        assertEquals("Already processing this notification", RecentNotificationsStore.snapshot().first().detail)
        assertEquals(1, wakes)
    }

    // Review Focus 2
    @Test fun theSameKeyWithANewPostTimeIsQueuedAgain() {
        PaymentAppsMirror.write(context, setOf(bank))
        listener.onNotificationPosted(sbn(bank, key = "k1", postTime = 1000, text = payment))
        listener.onNotificationPosted(sbn(bank, key = "k1", postTime = 2000, text = payment))
        assertEquals(2, queue.size())
        assertEquals(2, wakes)
    }

    @Test fun groupSummaryAndRemovedAreLoggedOnly() {
        PaymentAppsMirror.write(context, setOf(bank))
        listener.onNotificationPosted(sbn(bank, key = "k1", postTime = 1000, text = payment, groupSummary = true))
        listener.onNotificationRemoved(sbn(bank, key = "k2", postTime = 1000, text = payment))
        val log = RecentNotificationsStore.snapshot()
        assertEquals(
            listOf(NotificationDisposition.INFO_ONLY, NotificationDisposition.SKIPPED_GROUP_SUMMARY),
            log.map { it.disposition },
        )
        assertEquals(listOf("Removed from status bar", "Group summary notification"), log.map { it.detail })
        assertEquals(0, queue.size())
        assertEquals(0, wakes)
    }
}
