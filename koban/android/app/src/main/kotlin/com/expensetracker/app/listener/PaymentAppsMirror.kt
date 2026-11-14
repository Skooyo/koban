package com.expensetracker.app.listener

import android.content.Context

/** A copy of the chosen payment apps in SharedPreferences. The listener reads it before Dart runs. */
object PaymentAppsMirror {
    private const val FILE = "koban_capture"
    private const val KEY = "payment_apps"

    /** Returns null when the copy was never written. */
    fun read(context: Context): Set<String>? =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getStringSet(KEY, null)?.toSet()

    fun write(context: Context, apps: Set<String>) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().putStringSet(KEY, apps).commit()
    }
}
