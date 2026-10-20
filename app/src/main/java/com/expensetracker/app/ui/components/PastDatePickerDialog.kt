package com.expensetracker.app.ui.components

import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import java.util.Calendar
import java.util.TimeZone

/** Date picker up to today. [onPicked] gets [time] moved to the picked date, keeping its time of day. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PastDatePickerDialog(time: Long, onDismiss: () -> Unit, onPicked: (Long) -> Unit) {
    val pickerState = rememberDatePickerState(
        initialSelectedDateMillis = localDateAsUtcMillis(time),
        selectableDates = object : SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long) =
                utcTimeMillis <= localDateAsUtcMillis(System.currentTimeMillis())
        }
    )
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = {
                val picked = pickerState.selectedDateMillis
                if (picked != null) onPicked(withDate(time, picked)) else onDismiss()
            }) { Text("OK") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    ) {
        DatePicker(state = pickerState)
    }
}

/** The DatePicker works in UTC midnights; this is the local date of [time] as one. */
internal fun localDateAsUtcMillis(time: Long): Long {
    val local = Calendar.getInstance().apply { timeInMillis = time }
    return Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
        clear()
        set(local.get(Calendar.YEAR), local.get(Calendar.MONTH), local.get(Calendar.DAY_OF_MONTH))
    }.timeInMillis
}

/** [time] moved to the picked date, keeping its local time of day. */
internal fun withDate(time: Long, utcDateMillis: Long): Long {
    val picked = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { timeInMillis = utcDateMillis }
    return Calendar.getInstance().apply {
        timeInMillis = time
        set(picked.get(Calendar.YEAR), picked.get(Calendar.MONTH), picked.get(Calendar.DAY_OF_MONTH))
    }.timeInMillis
}
