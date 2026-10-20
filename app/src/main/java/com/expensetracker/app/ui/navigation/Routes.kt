package com.expensetracker.app.ui.navigation

import android.net.Uri

object Routes {
    const val HOME = "home"
    const val ACTIVITY = "activity"
    const val SETTINGS = "settings"
    const val NOTIFICATION_DEBUG = "settings/notification_debug"

    const val PEOPLE = "people"
    const val PERSON = "people/{personId}"
    const val SPLIT_NEW = "split/new?expenseId={expenseId}"
    const val SPLIT_EDIT = "split/edit/{billId}"
    const val PAYMENT_NEW = "payment/new"
    const val PAYMENT_EDIT = "payment/edit/{expenseId}"

    fun paymentEdit(id: String) = "payment/edit/${Uri.encode(id)}"

    fun splitNew(expenseId: String?): String =
        if (expenseId == null) "split/new" else "split/new?expenseId=${Uri.encode(expenseId)}"

    fun person(id: String): String = "people/${Uri.encode(id)}"

    fun splitEdit(billId: String): String = "split/edit/${Uri.encode(billId)}"
}
