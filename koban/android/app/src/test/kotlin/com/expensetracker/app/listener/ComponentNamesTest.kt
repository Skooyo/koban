package com.expensetracker.app.listener

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Android stores notification access by component name. These names must not change. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ComponentNamesTest {
    private lateinit var pm: PackageManager
    private lateinit var pkg: String

    @Before fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        pm = context.packageManager
        pkg = context.packageName
    }

    @Test fun listenerKeepsTheComponentNameOfTheKotlinApp() {
        val info = pm.getServiceInfo(ComponentName(pkg, "com.expensetracker.app.listener.ExpenseNotificationListener"), 0)
        assertEquals("android.permission.BIND_NOTIFICATION_LISTENER_SERVICE", info.permission)
        assertTrue(info.exported)
    }

    @Test fun serviceAndReceiversKeepTheirNames() {
        assertFalse(pm.getServiceInfo(ComponentName(pkg, "com.expensetracker.app.listener.ListenerKeepAliveService"), 0).exported)
        assertTrue(pm.getReceiverInfo(ComponentName(pkg, "com.expensetracker.app.listener.BootCompletedReceiver"), 0).exported)
        assertFalse(pm.getReceiverInfo(ComponentName(pkg, "com.expensetracker.app.listener.ListenerWatchdogReceiver"), 0).exported)
    }

    @Test fun updateReceiverKeepsItsName() {
        assertFalse(pm.getReceiverInfo(ComponentName(pkg, "com.expensetracker.app.update.UpdateInstallReceiver"), 0).exported)
    }

    @Test fun bootReceiverGetsBootAndUpdate() {
        for (action in listOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED)) {
            val names = pm.queryBroadcastReceivers(Intent(action).setPackage(pkg), 0).map { it.activityInfo.name }
            assertEquals(action, listOf("com.expensetracker.app.listener.BootCompletedReceiver"), names)
        }
    }
}
