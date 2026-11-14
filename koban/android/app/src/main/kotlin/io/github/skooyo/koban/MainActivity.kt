package io.github.skooyo.koban

import android.content.Intent
import android.os.Bundle
import com.expensetracker.app.listener.CaptureSignal
import com.expensetracker.app.listener.ListenerDisconnectNotifier
import com.expensetracker.app.listener.NotificationAccessHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(KobanNativePlugin())
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        reconnectIfAsked(intent)
    }

    // The launch mode is singleTop: a tap on the disconnect alert arrives here.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        reconnectIfAsked(intent)
    }

    override fun onResume() {
        super.onResume()
        NotificationAccessHelper.ensureListenerActive(this)
        if (NotificationAccessHelper.isListenerConnected()) ListenerDisconnectNotifier.hide(this)
        CaptureSignal.wakeIfQueued(this)
    }

    private fun reconnectIfAsked(intent: Intent?) {
        if (intent?.getBooleanExtra(EXTRA_RECONNECT_LISTENER, false) == true) {
            NotificationAccessHelper.reconnectListener(this)
        }
    }

    companion object {
        const val EXTRA_RECONNECT_LISTENER = "reconnect_listener"
    }
}
