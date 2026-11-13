package com.expensetracker.app.ui.viewmodel

enum class OnboardingStep { WELCOME, ACCESS, BLOCKED, APPS, RUNNING, READY }

object OnboardingRules {
    /** Only a new user sees onboarding. Anyone with access or a saved app choice is an existing user. */
    fun shouldShow(done: Boolean, accessGranted: Boolean, paymentAppsChosen: Boolean): Boolean =
        !done && !accessGranted && !paymentAppsChosen

    /** Android 13 and later can block notification access for a sideloaded app until the user allows it. */
    fun blockedHelp(sdkInt: Int, openedSettings: Boolean, accessGranted: Boolean): Boolean =
        sdkInt >= 33 && openedSettings && !accessGranted

    fun afterSettings(step: OnboardingStep, sdkInt: Int, accessGranted: Boolean): OnboardingStep = when {
        step != OnboardingStep.ACCESS && step != OnboardingStep.BLOCKED -> step
        accessGranted -> OnboardingStep.APPS
        blockedHelp(sdkInt, true, false) -> OnboardingStep.BLOCKED
        else -> step
    }

    /** Back in the app: granted access moves on even when the user did not use our button. */
    fun onResume(step: OnboardingStep, sdkInt: Int, accessGranted: Boolean, openedSettings: Boolean): OnboardingStep = when {
        accessGranted && (step == OnboardingStep.ACCESS || step == OnboardingStep.BLOCKED) -> OnboardingStep.APPS
        openedSettings -> afterSettings(step, sdkInt, accessGranted)
        else -> step
    }

    fun stepNumber(step: OnboardingStep): Int? = when (step) {
        OnboardingStep.WELCOME -> null
        OnboardingStep.ACCESS, OnboardingStep.BLOCKED -> 1
        OnboardingStep.APPS -> 2
        OnboardingStep.RUNNING -> 3
        OnboardingStep.READY -> 4
    }
}
