package com.expensetracker.app.ui.viewmodel

import android.content.Context
import android.os.Build
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.SettingsRepository
import com.expensetracker.app.listener.NotificationAccessHelper
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val settingsRepository: SettingsRepository,
    private val savedState: SavedStateHandle
) : ViewModel() {
    val step: StateFlow<OnboardingStep> = savedState.getStateFlow(KEY_STEP, OnboardingStep.WELCOME)

    private fun go(to: OnboardingStep) {
        savedState[KEY_STEP] = to
    }

    fun next() = when (step.value) {
        OnboardingStep.WELCOME -> go(OnboardingStep.ACCESS)
        OnboardingStep.APPS -> go(OnboardingStep.RUNNING)
        OnboardingStep.RUNNING -> go(OnboardingStep.READY)
        else -> Unit
    }

    /** Save can be tapped twice. Only the first tap leaves APPS. */
    fun appsSaved() {
        if (step.value == OnboardingStep.APPS) go(OnboardingStep.RUNNING)
    }

    fun back() = when (step.value) {
        OnboardingStep.ACCESS, OnboardingStep.BLOCKED -> go(OnboardingStep.WELCOME)
        OnboardingStep.APPS -> go(OnboardingStep.ACCESS)
        OnboardingStep.RUNNING -> go(OnboardingStep.APPS)
        OnboardingStep.READY -> go(OnboardingStep.RUNNING)
        OnboardingStep.WELCOME -> Unit
    }

    fun openedSettings() {
        savedState[KEY_OPENED] = true
    }

    /** Back from the system settings page: moves on if access is on, or shows the blocked help. */
    fun onResume() {
        val opened = savedState.get<Boolean>(KEY_OPENED) == true
        val granted = NotificationAccessHelper.isNotificationAccessGranted(context)
        go(OnboardingRules.onResume(step.value, Build.VERSION.SDK_INT, granted, opened))
        if (opened) savedState[KEY_OPENED] = false
    }

    /** Saves the done flag, then calls [onDone]. Leaving first could cancel the write. */
    fun finish(onDone: () -> Unit) {
        viewModelScope.launch {
            settingsRepository.setOnboardingDone()
            onDone()
        }
    }

    private companion object {
        const val KEY_STEP = "step"
        const val KEY_OPENED = "openedSettings"
    }
}
