package com.expensetracker.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.CategoryEntity
import com.expensetracker.app.data.ExpenseRepository
import com.expensetracker.app.data.PeriodSummary
import com.expensetracker.app.data.SpendingPeriod
import com.expensetracker.app.listener.NotificationAccessHelper
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

data class HomeUiState(
    val isAccessGranted: Boolean = false,
    val today: PeriodSummary = PeriodSummary("", "", java.math.BigDecimal.ZERO, emptyList(), emptyList()),
    val week: PeriodSummary = PeriodSummary("", "", java.math.BigDecimal.ZERO, emptyList(), emptyList()),
    val month: PeriodSummary = PeriodSummary("", "", java.math.BigDecimal.ZERO, emptyList(), emptyList()),
    val categoryNames: Map<String, String> = emptyMap()
)

@HiltViewModel
class HomeViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val expenseRepository: ExpenseRepository,
    private val categoryRepository: com.expensetracker.app.data.CategoryRepository
) : ViewModel() {

    private val accessGranted = MutableStateFlow(false)

    /** The current date. A new value rebuilds the period ranges, so Today and This month move on at midnight. */
    private val currentDay = MutableStateFlow(dayStamp())

    @OptIn(ExperimentalCoroutinesApi::class)
    val uiState: StateFlow<HomeUiState> = currentDay.flatMapLatest {
        combine(
            accessGranted,
            expenseRepository.observeCurrentPeriodSummary(SpendingPeriod.DAY),
            expenseRepository.observeCurrentPeriodSummary(SpendingPeriod.WEEK),
            expenseRepository.observeCurrentPeriodSummary(SpendingPeriod.MONTH),
            categoryRepository.observeAll()
        ) { granted, today, week, month, categories ->
            HomeUiState(
                isAccessGranted = granted,
                today = today,
                week = week,
                month = month,
                categoryNames = categories.associate { it.id to it.name }
            )
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), HomeUiState())

    /** Called on every resume. */
    fun refreshAccessStatus() {
        accessGranted.value = NotificationAccessHelper.isNotificationAccessGranted(context)
        currentDay.value = dayStamp()
    }

    private fun dayStamp() = SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())

    fun openNotificationSettings() {
        NotificationAccessHelper.openNotificationAccessSettings(context)
    }
}
