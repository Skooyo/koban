package com.expensetracker.app.listener

import android.app.AlarmManager
import android.app.Application
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class BootCompletedReceiverTest {
    private lateinit var context: Context
    private lateinit var app: Application
    private lateinit var alarmManager: AlarmManager
    private var wakes = 0

    @Before fun setUp() {
        app = ApplicationProvider.getApplicationContext()
        context = app
        alarmManager = context.getSystemService(AlarmManager::class.java)
        CaptureQueueTestSupport.reset()
        wakes = 0
        CaptureSignal.wake = { wakes++ }
    }

    @After fun tearDown() {
        CaptureSignal.wake = {}
        CaptureQueueTestSupport.reset()
    }

    private fun grantAccess() {
        val name = ComponentName(context.packageName, "com.expensetracker.app.listener.ExpenseNotificationListener")
        Settings.Secure.putString(context.contentResolver, "enabled_notification_listeners", name.flattenToString())
    }

    @Test fun bootWithAccessStartsKeepAliveAndTheWatchdog() {
        grantAccess()
        BootCompletedReceiver().onReceive(context, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertEquals("com.expensetracker.app.listener.ListenerKeepAliveService", shadowOf(app).nextStartedService.component!!.className)
        val alarm = shadowOf(alarmManager).nextScheduledAlarm!!
        assertEquals(15 * 60 * 1000.0, (alarm.triggerAtTime - System.currentTimeMillis()).toDouble(), 1000.0)
    }

    @Test fun bootWithoutAccessStartsNothing() {
        BootCompletedReceiver().onReceive(context, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertNull(shadowOf(app).nextStartedService)
        assertNull(shadowOf(alarmManager).nextScheduledAlarm)
    }

    @Test fun bootWakesDartOnlyWhenRowsWait() {
        BootCompletedReceiver().onReceive(context, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertEquals(0, wakes)
        CaptureQueue.get(context).add(
            QueuedNotification(logId = "l1", packageName = "com.maybank2u.life", title = null, text = "t", postTime = 1, notificationKey = "k1"),
        )
        BootCompletedReceiver().onReceive(context, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertEquals(1, wakes)
    }
}
