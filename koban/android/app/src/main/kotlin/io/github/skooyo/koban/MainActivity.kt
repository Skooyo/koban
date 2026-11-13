package io.github.skooyo.koban

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.github.skooyo.koban/legacy")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "databasePath" -> result.success(getDatabasePath("expense_tracker.db").absolutePath)
                    "readSettings" -> worker.execute {
                        try {
                            val settings = LegacySettingsReader.read(File(filesDir, "datastore"))
                            runOnUiThread { result.success(settings) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("LEGACY_SETTINGS", e.message, null) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }
}
