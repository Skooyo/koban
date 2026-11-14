package com.expensetracker.app.listener

import android.content.Context
import android.util.Log

/** The link from the native listener to the Dart engine. */
object CaptureSignal {
    /** Starts the Dart engine so it reads the queue. Tests replace it. */
    @Volatile
    var wake: (Context) -> Unit = CaptureEngine::wake

    /** Calls [wake] when rows wait in the queue. */
    fun wakeIfQueued(context: Context) {
        try {
            if (CaptureQueue.get(context).size() > 0) wake(context)
        } catch (e: Throwable) {
            // The callers run on the main thread. An error here must not stop the app or the listener.
            Log.w("CaptureSignal", "Wake failed: ${e.javaClass.simpleName}")
        }
    }
}
