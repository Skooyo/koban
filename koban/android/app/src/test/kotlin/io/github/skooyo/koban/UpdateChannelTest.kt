package io.github.skooyo.koban

import android.app.Application
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import com.expensetracker.app.update.UpdateInstaller
import org.junit.After
import android.provider.Settings
import androidx.test.core.app.ApplicationProvider
import java.io.File
import java.util.concurrent.Executor
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
class UpdateChannelTest {
    private val update = "io.github.skooyo.koban/update"
    private lateinit var context: Application
    private lateinit var messenger: FakeMessenger

    private fun nextSessionId(): Int = context.packageManager.packageInstaller.let {
        val id = it.createSession(PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL))
        it.abandonSession(id)
        id
    }

    @After fun tearDown() {
        UpdateInstaller.onStatus = null
    }

    @Test @Config(sdk = [26]) fun versionCodeWorksOnTheOldestPhone() {
        @Suppress("DEPRECATION")
        val expected = context.packageManager.getPackageInfo(context.packageName, 0).versionCode.toLong()
        assertEquals(expected, (messenger.call(update, "versionCode") as Number).toLong())
    }

    @Before fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        messenger = FakeMessenger()
        KobanNativePlugin(Executor { it.run() }).register(context, messenger)
    }

    @Test fun aFileThatIsNotTheKobanApkIsRefusedWithoutASession() {
        val baseline = nextSessionId()
        val dir = File(context.cacheDir, "updates").also { it.mkdirs() }
        val f = File(dir, "koban-9.apk").also { it.writeText("not an apk") }
        val error = messenger.callForError(update, "install", mapOf("path" to f.path, "versionCode" to 9))
        assertEquals("NOT_KOBAN_APK", error.code)
        // Session ids count up: the next session must get the id after the baseline, so the call made none.
        assertEquals(baseline + 1, nextSessionId())
    }

    @Test fun canInstallFollowsThePhoneSetting() {
        shadowOf(context.packageManager).setCanRequestPackageInstalls(false)
        assertEquals(false, messenger.call(update, "canInstall"))
        shadowOf(context.packageManager).setCanRequestPackageInstalls(true)
        assertEquals(true, messenger.call(update, "canInstall"))
    }

    @Test fun openInstallSettingsOpensTheUnknownAppsPage() {
        messenger.call(update, "openInstallSettings")
        val started: Intent = shadowOf(context).nextStartedActivity
        assertEquals(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, started.action)
        assertEquals("package:${context.packageName}", started.dataString)
        assertTrue(started.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
    }

    @Test fun versionCodeIsTheInstalledVersion() {
        val expected = context.packageManager.getPackageInfo(context.packageName, 0).longVersionCode
        assertEquals(expected, (messenger.call(update, "versionCode") as Number).toLong())
    }
}
