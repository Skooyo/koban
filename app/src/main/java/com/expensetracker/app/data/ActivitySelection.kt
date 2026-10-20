package com.expensetracker.app.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.YearMonth
import javax.inject.Inject
import javax.inject.Singleton

/** The month (optional week and category filter) the Activity tab shows. Home sets it; the Activity tab keeps it. */
@Singleton
class ActivitySelection @Inject constructor() {

    data class Selection(val month: YearMonth, val weekStart: Long?, val categoryFilter: String? = null)

    private val _state = MutableStateFlow(Selection(YearMonth.now(), null))
    val state: StateFlow<Selection> = _state.asStateFlow()

    /** Shows [month] (and [weekStart]); clears the category filter unless one is given. */
    fun show(month: YearMonth, weekStart: Long? = null, categoryFilter: String? = null) {
        _state.value = Selection(month, weekStart, categoryFilter)
    }

    fun setCategoryFilter(filter: String?) {
        _state.value = _state.value.copy(categoryFilter = filter)
    }
}
