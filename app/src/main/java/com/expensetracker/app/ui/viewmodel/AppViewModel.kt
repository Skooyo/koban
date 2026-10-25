package com.expensetracker.app.ui.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.PendingPaymentRepository
import com.expensetracker.app.data.PeopleRepository
import com.expensetracker.app.data.SettingsRepository
import com.expensetracker.app.listener.NotificationAccessHelper
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AppViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val settingsRepository: SettingsRepository,
    peopleRepository: PeopleRepository,
    private val pendingPaymentRepository: PendingPaymentRepository
) : ViewModel() {
    val darkModeEnabled: StateFlow<Boolean> = settingsRepository.darkModeEnabled
        .stateIn(viewModelScope, SharingStarted.Eagerly, true)

    /** People with an open balance; the People tab shows it as a badge. */
    val openPeopleCount: StateFlow<Int> = peopleRepository.observePeople()
        .map { list -> list.count { it.hasOpen } }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0)

    /** A fresh read, not a cached value: payments may arrive while the app is in the background. */
    suspend fun waitingCountNow(): Int = pendingPaymentRepository.observeCount().first()

    /** True when notification access is on but the user has not picked payment apps yet. */
    suspend fun paymentAppsDue(): Boolean =
        NotificationAccessHelper.isNotificationAccessGranted(context) && !settingsRepository.paymentAppsChosen.first()

    /** True after a stop for a rotation, so the next start does not open the swipe screen again. */
    private var skipNextStart = false

    fun onActivityStop(changingConfigurations: Boolean) {
        skipNextStart = changingConfigurations
    }

    /** True once per real start of the activity. */
    fun takeAutoOpenTurn(): Boolean = !skipNextStart.also { skipNextStart = false }

    fun setDarkMode(enabled: Boolean) {
        viewModelScope.launch {
            settingsRepository.setDarkMode(enabled)
        }
    }
}
