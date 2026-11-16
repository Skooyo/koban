package io.github.skooyo.koban

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.expensetracker.app.listener.CaptureQueue
import com.expensetracker.app.listener.CapturedNotification
import com.expensetracker.app.listener.NotificationAccessHelper
import com.expensetracker.app.listener.NotificationDisposition
import com.expensetracker.app.listener.NotificationListenerBridge
import com.expensetracker.app.listener.OemBatteryHelper
import com.expensetracker.app.listener.PaymentAppsMirror
import com.expensetracker.app.listener.QueuedNotification
import com.expensetracker.app.listener.RecentNotificationsStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.util.concurrent.Executor
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/**
 * The native channels for one Flutter engine. The app engine and the capture engine both add it.
 * Disk work runs on [executor]. Each reply goes back on the main thread.
 */
class KobanNativePlugin(private val executor: Executor = Executors.newSingleThreadExecutor()) : FlutterPlugin, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
    private val main = Handler(Looper.getMainLooper())
    private var capture: MethodChannel? = null
    private var device: DeviceChannel? = null
    private var update: UpdateChannel? = null
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = unlinkActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        unlinkActivity()
        // A real detach: the dialog result will not come, so answer the open calls.
        device?.cancelPending()
    }

    private fun unlinkActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean =
        device?.onPermissionResult(requestCode, grantResults) ?: false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) =
        register(binding.applicationContext, binding.binaryMessenger)

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) = detach()

    /** Frees the gate and stops the executor. Work in flight still ends. A later call gets an error reply. */
    internal fun detach() {
        ImportGate.forget(this)
        capture = null
        device?.cancelPending()
        device = null
        update?.release()
        update = null
        (executor as? ExecutorService)?.shutdown()
    }

    /** Adds the five channels. [onAttachedToEngine] calls it. Tests call it with a fake messenger. */
    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, LEGACY).setMethodCallHandler { call, result ->
            when (call.method) {
                "databasePath" -> work(result) { app.getDatabasePath("expense_tracker.db").absolutePath }
                "readSettings" -> work(result, "LEGACY_SETTINGS") {
                    LegacySettingsReader.read(File(app.filesDir, "datastore"))
                }
                else -> result.notImplemented()
            }
        }
        capture = MethodChannel(messenger, CAPTURE).also { channel ->
            channel.setMethodCallHandler { call, result -> onCapture(app, call, result) }
        }
        MethodChannel(messenger, LISTENER).setMethodCallHandler { call, result -> onListener(app, call, result) }
        val deviceChannel = DeviceChannel(app, { result, code, block -> work(result, code, block) }) { activityBinding?.activity }
        device = deviceChannel
        MethodChannel(messenger, DEVICE).setMethodCallHandler { call, result -> deviceChannel.onCall(call, result) }
        val updateMethods = MethodChannel(messenger, UPDATE)
        val updateChannel = UpdateChannel(app, { result, code, block -> work(result, code, block) }, updateMethods)
        update = updateChannel
        updateMethods.setMethodCallHandler { call, result -> updateChannel.onCall(call, result) }
    }

    /** Tells the Dart side to read the queue. Call it on the main thread. */
    fun requestDrain() {
        capture?.invokeMethod("drain", null)
    }

    private fun onCapture(app: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "takeQueue" -> work(result) {
                val queue = CaptureQueue.get(app)
                for (row in queue.giveUp()) {
                    RecentNotificationsStore.update(row.logId, NotificationDisposition.SKIPPED_ERROR, "Gave up after 5 tries")
                }
                queue.take(call.argument<Number>("afterId")!!.toLong()).map { it.toMap() }
            }
            "finish" -> work(result) {
                val id = call.argument<Number>("id")!!.toLong()
                val logId = call.argument<String>("logId")!!
                val disposition = NotificationDisposition.valueOf(call.argument<String>("disposition")!!)
                // All arguments are valid here, so a bad call keeps the row.
                CaptureQueue.get(app).remove(id)
                RecentNotificationsStore.update(logId, disposition, call.argument<String>("detail"))
            }
            "updateLog" -> work(result) { updateLog(call) }
            "appendLog" -> work(result) {
                RecentNotificationsStore.add(
                    CapturedNotification(
                        packageName = app.packageName,
                        title = call.argument<String>("title"),
                        body = call.argument<String>("body")!!,
                        postTime = System.currentTimeMillis(),
                        disposition = NotificationDisposition.valueOf(call.argument<String>("disposition")!!),
                        detail = call.argument<String>("detail"),
                    ),
                )
            }
            "setPaymentApps" -> work(result) {
                PaymentAppsMirror.write(app, call.argument<List<String>>("apps")!!.toSet())
            }
            "acquireImportGate" -> ImportGate.acquire(this) { main.post { result.success(null) } }
            "releaseImportGate" -> work(result) { ImportGate.release(this) }
            else -> result.notImplemented()
        }
    }

    private fun updateLog(call: MethodCall) =
        RecentNotificationsStore.update(
            call.argument<String>("logId")!!,
            NotificationDisposition.valueOf(call.argument<String>("disposition")!!),
            call.argument<String>("detail"),
        )

    private fun onListener(app: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAccessGranted" -> work(result) { NotificationAccessHelper.isNotificationAccessGranted(app) }
            "isConnected" -> work(result) { NotificationAccessHelper.isListenerConnected() }
            "ensureActive" -> work(result) { NotificationAccessHelper.ensureListenerActive(app) }
            "reconnect" -> work(result) { NotificationAccessHelper.reconnectListener(app).name }
            "openAccessSettings" -> work(result) { NotificationAccessHelper.openNotificationAccessSettings(app) }
            "isBatteryOptimizationIgnored" -> work(result) { NotificationAccessHelper.isBatteryOptimizationIgnored(app) }
            "openBatteryOptimizationSettings" -> work(result) { NotificationAccessHelper.openBatteryOptimizationSettings(app) }
            "isXiaomiFamily" -> work(result) { OemBatteryHelper.isXiaomiFamily() }
            "openBackgroundSettings" -> work(result) { OemBatteryHelper.openManufacturerBackgroundSettings(app).name }
            "recentNotifications" -> work(result) {
                RecentNotificationsStore.snapshot().map {
                    mapOf(
                        "id" to it.id,
                        "packageName" to it.packageName,
                        "title" to it.title,
                        "body" to it.body,
                        "postTime" to it.postTime,
                        "capturedAt" to it.capturedAt,
                        "event" to it.event.name,
                        "disposition" to it.disposition.name,
                        "detail" to it.detail,
                    )
                }
            }
            "listenerState" -> work(result) {
                val s = RecentNotificationsStore.listenerState.value
                mapOf(
                    "isConnected" to s.isConnected,
                    "lastConnectedAt" to s.lastConnectedAt,
                    "lastDisconnectedAt" to s.lastDisconnectedAt,
                    "totalCaptured" to s.totalCaptured,
                )
            }
            "clearLog" -> work(result) {
                val ids = call.argument<List<String>>("ids")
                if (ids == null) RecentNotificationsStore.clear() else RecentNotificationsStore.clear(ids.toSet())
            }
            "snapshotActive" -> work(result) { NotificationListenerBridge.refreshActiveNotifications() }
            else -> result.notImplemented()
        }
    }

    /** Runs [block] on the executor. A thrown error (also an Error) becomes an error reply, so no Dart future hangs. */
    private fun work(result: MethodChannel.Result, code: String = "NATIVE_ERROR", block: () -> Any?) {
        try {
            executor.execute {
                try {
                    val value = block()
                    main.post { result.success(if (value is Unit) null else value) }
                } catch (e: Throwable) {
                    // Also an Error: an uncaught one on this thread stops the app,
                    // and every start runs the import again.
                    main.post { result.error((e as? CodedError)?.code ?: code, e.message, null) }
                }
            }
        } catch (e: RejectedExecutionException) {
            // The engine detached and the executor stopped.
            result.error(code, "Plugin detached", null)
        }
    }

    private fun QueuedNotification.toMap() = mapOf(
        "id" to id,
        "logId" to logId,
        "packageName" to packageName,
        "title" to title,
        "text" to text,
        "postTime" to postTime,
        "notificationKey" to notificationKey,
    )

    companion object {
        const val LEGACY = "io.github.skooyo.koban/legacy"
        const val CAPTURE = "io.github.skooyo.koban/capture"
        const val LISTENER = "io.github.skooyo.koban/listener"
        const val DEVICE = "io.github.skooyo.koban/device"
        const val UPDATE = "io.github.skooyo.koban/update"
    }
}
