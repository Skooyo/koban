package io.github.skooyo.koban

import android.app.Activity
import android.app.Application
import android.content.pm.PackageManager
import android.os.Looper
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import java.lang.reflect.Proxy
import org.junit.Assert.assertFalse
import org.robolectric.Robolectric
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.ResolveInfo
import androidx.test.core.app.ApplicationProvider
import io.flutter.plugin.common.FlutterException
import java.io.File
import java.util.concurrent.Executor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class DeviceChannelTest {
    private val device = "io.github.skooyo.koban/device"
    private val direct = Executor { it.run() }
    private lateinit var context: Context
    private lateinit var messenger: FakeMessenger
    private lateinit var plugin: KobanNativePlugin

    @Before fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        messenger = FakeMessenger()
        plugin = KobanNativePlugin(direct)
        plugin.register(context, messenger)
    }

    /** An activity binding that only knows its activity. */
    private fun binding(): ActivityPluginBinding {
        val activity = Robolectric.buildActivity(Activity::class.java).create().get()
        return Proxy.newProxyInstance(javaClass.classLoader, arrayOf(ActivityPluginBinding::class.java)) { _, method, _ ->
            if (method.name == "getActivity") activity else null
        } as ActivityPluginBinding
    }

    /** Sends a call and keeps every reply it gets, so a test can count them. */
    private fun callAndCollect(method: String): MutableList<Any?> {
        val replies = mutableListOf<Any?>()
        val message = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, null)).also { it.rewind() }
        messenger.handlers.getValue(device).onMessage(message) {
            replies.add(StandardMethodCodec.INSTANCE.decodeEnvelope(it!!.also { b -> b.rewind() }))
        }
        shadowOf(Looper.getMainLooper()).idle()
        return replies
    }

    private fun answerDialog(code: Int, grants: IntArray): Boolean {
        val handled = plugin.onRequestPermissionsResult(code, arrayOf(), grants)
        shadowOf(Looper.getMainLooper()).idle()
        return handled
    }

    @Test fun aGrantAnswersTrueExactlyOnce() {
        plugin.onAttachedToActivity(binding())
        val replies = callAndCollect("requestNotificationPermission")
        assertEquals(0, replies.size)
        assertTrue(answerDialog(4201, intArrayOf(PackageManager.PERMISSION_GRANTED)))
        assertEquals(listOf<Any?>(true), replies)
        // A repeated result finds nothing pending and sends no second reply.
        assertTrue(answerDialog(4201, intArrayOf(PackageManager.PERMISSION_GRANTED)))
        assertEquals(1, replies.size)
    }

    @Test fun emptyGrantResultsAnswerFalse() {
        plugin.onAttachedToActivity(binding())
        val replies = callAndCollect("requestStoragePermission")
        // Storage needs no dialog from Android 10, so use the alerts request for the dialog path.
        assertEquals(listOf<Any?>(true), replies)
        val alerts = callAndCollect("requestNotificationPermission")
        assertTrue(answerDialog(4201, intArrayOf()))
        assertEquals(listOf<Any?>(false), alerts)
    }

    @Test fun aSecondRequestWhilePendingAnswersAtOnceAndTheFirstAnswersOnceLater() {
        plugin.onAttachedToActivity(binding())
        val first = callAndCollect("requestNotificationPermission")
        val second = callAndCollect("requestNotificationPermission")
        assertEquals(0, first.size)
        assertEquals(listOf<Any?>(false), second)
        answerDialog(4201, intArrayOf(PackageManager.PERMISSION_GRANTED))
        assertEquals(listOf<Any?>(true), first)
        assertEquals(1, second.size)
    }

    @Test fun anUnknownRequestCodeIsNotHandled() {
        plugin.onAttachedToActivity(binding())
        val replies = callAndCollect("requestNotificationPermission")
        assertFalse(answerDialog(9999, intArrayOf(PackageManager.PERMISSION_GRANTED)))
        assertEquals(0, replies.size)
    }

    @Test fun aRealDetachAnswersThePendingCallAndLaterRequestsAskAgain() {
        plugin.onAttachedToActivity(binding())
        val replies = callAndCollect("requestNotificationPermission")
        plugin.onDetachedFromActivity()
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf<Any?>(false), replies)
        val shadow = binding().let { b ->
            plugin.onAttachedToActivity(b)
            shadowOf(b.activity)
        }
        val again = callAndCollect("requestNotificationPermission")
        assertEquals(0, again.size)
        assertEquals("android.permission.POST_NOTIFICATIONS", shadow.lastRequestedPermission.requestedPermissions.single())
    }

    @Test fun anEngineDetachAnswersThePendingCall() {
        plugin.onAttachedToActivity(binding())
        val replies = callAndCollect("requestNotificationPermission")
        plugin.detach()
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf<Any?>(false), replies)
    }

    @Test fun aConfigChangeDetachKeepsThePendingCallForTheDialogResult() {
        val b = binding()
        plugin.onAttachedToActivity(b)
        val replies = callAndCollect("requestNotificationPermission")
        plugin.onDetachedFromActivityForConfigChanges()
        assertEquals(0, replies.size)
        plugin.onReattachedToActivityForConfigChanges(b)
        assertTrue(answerDialog(4201, intArrayOf(PackageManager.PERMISSION_GRANTED)))
        assertEquals(listOf<Any?>(true), replies)
    }

    private fun installLauncherApp(pkg: String, label: String) {
        val app = ApplicationInfo().apply {
            packageName = pkg
            nonLocalizedLabel = label
        }
        val pm = shadowOf(context.packageManager)
        pm.installPackage(PackageInfo().apply { packageName = pkg; applicationInfo = app })
        val info = ResolveInfo().apply {
            activityInfo = android.content.pm.ActivityInfo().apply { packageName = pkg; applicationInfo = app; name = "$pkg.Main" }
        }
        pm.addResolveInfoForIntent(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), info)
    }

    @Test fun installedAppsListsLauncherAppsWithLabelsAndLeavesOutKoban() {
        installLauncherApp("com.maybank2u.life", "MAE")
        installLauncherApp(context.packageName, "Koban")
        @Suppress("UNCHECKED_CAST")
        val apps = messenger.call(device, "installedApps", null) as List<Map<String, Any?>>
        assertEquals(listOf("com.maybank2u.life"), apps.map { it["packageName"] })
        assertEquals("MAE", apps.single()["label"])
        val icon = apps.single()["icon"] as ByteArray
        assertEquals(listOf(0x89, 'P'.code, 'N'.code, 'G'.code), icon.take(4).map { it.toInt() and 0xFF })
        val px = (40 * context.resources.displayMetrics.density).toInt()
        val decoded = android.graphics.BitmapFactory.decodeByteArray(icon, 0, icon.size)
        assertEquals(px to px, decoded.width to decoded.height)
    }

    @Test fun appLabelsGiveThePackageNameForAnAppThatIsNotVisible() {
        installLauncherApp("com.maybank2u.life", "MAE")
        assertEquals(
            mapOf("x.y" to "x.y", "com.maybank2u.life" to "MAE"),
            messenger.call(device, "appLabels", mapOf("packages" to listOf("x.y", "com.maybank2u.life"))),
        )
    }

    @Test fun sdkIntGivesTheAndroidVersion() {
        assertEquals(35, messenger.call(device, "sdkInt"))
    }

    @Test @Config(sdk = [32]) fun notificationPermissionIsGrantedBeforeAndroid13WithNoDialog() {
        assertEquals(true, messenger.call(device, "notificationsAllowed"))
        assertEquals(true, messenger.call(device, "requestNotificationPermission"))
        assertEquals(false, messenger.call(device, "shouldShowNotificationRationale"))
    }

    @Test fun aPermissionRequestWithNoActivityAnswersTheCurrentState() {
        assertEquals(false, messenger.call(device, "requestNotificationPermission"))
        assertEquals(false, messenger.call(device, "shouldShowNotificationRationale"))
    }

    @Test fun storageIsAllowedFromAndroid10() {
        assertEquals(true, messenger.call(device, "storageAllowed"))
    }

    @Test fun saveImageToGalleryRefusesAFileThatIsNotAnImage() {
        val file = File(context.filesDir, "note.img").also { it.writeText("not a picture") }
        try {
            messenger.call(device, "saveImageToGallery", mapOf("path" to file.absolutePath, "displayName" to "qr.jpg"))
            fail("expected an error reply")
        } catch (e: FlutterException) {
            assertEquals("GALLERY", e.code)
            assertEquals("That file isn't an image.", e.message)
        }
    }

    @Test fun shareTextStartsAChooserWithTheText() {
        // An executor that never runs: the chooser must start on the main thread.
        val idle = FakeMessenger()
        KobanNativePlugin(Executor { }).register(context, idle)
        assertNull(idle.call(device, "shareText", mapOf("text" to "Kedai Contoh, 13 Nov 2026", "chooserTitle" to "Share summary")))
        val started = shadowOf(context as Application).nextStartedActivity
        assertEquals(Intent.ACTION_CHOOSER, started.action)
        assertEquals("Share summary", started.getCharSequenceExtra(Intent.EXTRA_TITLE).toString())
        assertTrue(started.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
        @Suppress("DEPRECATION")
        val inner = started.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)!!
        assertEquals(Intent.ACTION_SEND, inner.action)
        assertEquals("text/plain", inner.type)
        assertEquals("Kedai Contoh, 13 Nov 2026", inner.getStringExtra(Intent.EXTRA_TEXT))
    }
}
