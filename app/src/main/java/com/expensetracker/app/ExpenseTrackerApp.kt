package com.expensetracker.app

import android.app.Application
import com.expensetracker.app.listener.NotificationAccessHelper
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class ExpenseTrackerApp : Application() {
    override fun onCreate() {
        super.onCreate()
        NotificationAccessHelper.ensureListenerActive(this)
    }
}
