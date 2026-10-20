package com.expensetracker.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.PeopleRepository
import com.expensetracker.app.data.SettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AppViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository,
    peopleRepository: PeopleRepository
) : ViewModel() {
    val darkModeEnabled: StateFlow<Boolean> = settingsRepository.darkModeEnabled
        .stateIn(viewModelScope, SharingStarted.Eagerly, true)

    /** People with an open balance; the People tab shows it as a badge. */
    val openPeopleCount: StateFlow<Int> = peopleRepository.observePeople()
        .map { list -> list.count { it.hasOpen } }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0)

    fun setDarkMode(enabled: Boolean) {
        viewModelScope.launch {
            settingsRepository.setDarkMode(enabled)
        }
    }
}
