package com.expensetracker.app.listener

import android.content.Context
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint
import io.github.skooyo.koban.KobanNativePlugin

/** The Dart engine that runs without a screen. It parses queued notifications and saves them. */
object CaptureEngine {
    // The engine lives as long as the process, so these two fields keep it from garbage collection.
    private var engine: FlutterEngine? = null
    private var plugin: KobanNativePlugin? = null

    /** Makes and starts an engine. A failure destroys the half-made engine and throws. Tests replace it. */
    internal var startEngine: (Context, KobanNativePlugin) -> FlutterEngine = { app, newPlugin ->
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(app)
        loader.ensureInitializationComplete(app, null)
        val newEngine = FlutterEngine(app)
        try {
            newEngine.plugins.add(newPlugin)
            newEngine.dartExecutor.executeDartEntrypoint(DartEntrypoint(loader.findAppBundlePath(), "captureMain"))
            newEngine
        } catch (e: Throwable) {
            newEngine.destroy()
            throw e
        }
    }

    /** True when an engine is stored. */
    internal val isRunning: Boolean get() = plugin != null

    /**
     * Starts the engine at the first call. Later calls ask it to read the queue. Call it on the main thread.
     * A failure keeps no engine and logs, so the next call tries again.
     */
    fun wake(context: Context) {
        val app = context.applicationContext
        val running = plugin
        if (running != null) {
            try {
                running.requestDrain()
            } catch (e: Throwable) {
                Log.w(TAG, "Drain request failed: ${e.javaClass.simpleName}")
            }
            return
        }
        val newPlugin = KobanNativePlugin()
        try {
            engine = startEngine(app, newPlugin)
            plugin = newPlugin
        } catch (e: Throwable) {
            engine = null
            plugin = null
            Log.w(TAG, "Engine start failed: ${e.javaClass.simpleName}")
        }
    }

    private const val TAG = "CaptureEngine"
}
