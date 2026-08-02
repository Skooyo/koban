package com.expensetracker.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import com.expensetracker.app.listener.ListenerDisconnectNotifier
import com.expensetracker.app.listener.NotificationAccessHelper
import com.expensetracker.app.ui.ExpenseTrackerApp
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        if (intent?.getBooleanExtra(EXTRA_RECONNECT_LISTENER, false) == true) {
            NotificationAccessHelper.reconnectListener(this)
        }
        setContent {
            ExpenseTrackerApp(modifier = Modifier.fillMaxSize())
        }
    }

    override fun onResume() {
        super.onResume()
        NotificationAccessHelper.ensureListenerActive(this)
        if (NotificationAccessHelper.isListenerConnected()) {
            ListenerDisconnectNotifier.hide(this)
        }
    }

    companion object {
        const val EXTRA_RECONNECT_LISTENER = "reconnect_listener"
    }
}
