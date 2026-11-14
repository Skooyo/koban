package io.github.skooyo.koban

import android.app.Application
import com.expensetracker.app.listener.NotificationAccessHelper

class KobanApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        NotificationAccessHelper.ensureListenerActive(this)
    }
}
