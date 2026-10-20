package com.expensetracker.app.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.YearMonth
import javax.inject.Inject
import javax.inject.Singleton

/** The month (and optional week) the Activity tab shows. Home sets it; the Activity tab keeps it. */
@Singleton
class ActivitySelection @Inject constructor() {

    data class Selection(val month: YearMonth, val weekStart: Long?)

    private val _state = MutableStateFlow(Selection(YearMonth.now(), null))
    val state: StateFlow<Selection> = _state.asStateFlow()

    fun show(month: YearMonth, weekStart: Long? = null) {
        _state.value = Selection(month, weekStart)
    }
}
