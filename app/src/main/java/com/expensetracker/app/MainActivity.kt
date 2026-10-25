package com.expensetracker.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import com.expensetracker.app.data.PendingPaymentRepository
import com.expensetracker.app.listener.ListenerDisconnectNotifier
import com.expensetracker.app.listener.NotificationAccessHelper
import com.expensetracker.app.ui.ExpenseTrackerApp
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject lateinit var pendingPaymentRepository: PendingPaymentRepository

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

    /** Closing the app inside the Undo window still saves or drops the held card. */
    override fun onStop() {
        super.onStop()
        // Rotation and similar recreation keep the Undo window open.
        if (!isChangingConfigurations) pendingPaymentRepository.flushHold()
    }

    companion object {
        const val EXTRA_RECONNECT_LISTENER = "reconnect_listener"
    }
}
