package com.expensetracker.app.update

import android.app.Application
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class UpdateInstallReceiverTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val context: Context = app
    private val seen = mutableListOf<Pair<Int, String?>>()

    @Before fun setUp() {
        UpdateInstaller.onStatus = { status, message -> seen.add(status to message) }
    }

    @After fun tearDown() {
        UpdateInstaller.onStatus = null
    }

    @Test fun successGoesToTheHandler() {
        UpdateInstallReceiver().onReceive(context, Intent().putExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_SUCCESS))
        assertEquals(listOf<Pair<Int, String?>>(PackageInstaller.STATUS_SUCCESS to null), seen)
    }

    @Test fun pendingUserActionOpensTheConfirmScreen() {
        val confirm = Intent("android.content.pm.action.CONFIRM_INSTALL")
        UpdateInstallReceiver().onReceive(
            context,
            Intent().putExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_PENDING_USER_ACTION).putExtra(Intent.EXTRA_INTENT, confirm),
        )
        val started = shadowOf(app).nextStartedActivity
        assertEquals("android.content.pm.action.CONFIRM_INSTALL", started.action)
        assertTrue(started.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
        assertEquals(listOf<Pair<Int, String?>>(PackageInstaller.STATUS_PENDING_USER_ACTION to null), seen)
    }

    @Test fun pendingUserActionWithoutAnIntentFails() {
        UpdateInstallReceiver().onReceive(context, Intent().putExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_PENDING_USER_ACTION))
        assertEquals(listOf<Pair<Int, String?>>(PackageInstaller.STATUS_FAILURE to "No confirm intent"), seen)
    }
}
