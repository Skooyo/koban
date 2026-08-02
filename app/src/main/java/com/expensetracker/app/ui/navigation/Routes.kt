package com.expensetracker.app.ui.navigation

import android.net.Uri

object Routes {
    const val HOME = "home"
    const val EXPENSES = "expenses"
    const val HISTORY = "history"
    const val SETTINGS = "settings"
    const val NOTIFICATION_DEBUG = "settings/notification_debug"
    const val EXPENSES_FILTER = "expenses/filter/{start}/{end}/{title}"
    const val HISTORY_MONTH = "history/{yearMonth}"

    fun expensesFilter(start: Long, end: Long, title: String): String {
        return "expenses/filter/$start/$end/${Uri.encode(title)}"
    }

    fun historyMonth(yearMonth: Int): String = "history/$yearMonth"
}
