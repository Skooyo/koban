package com.expensetracker.app.ui.viewmodel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OnboardingRulesTest {
    @Test fun shouldShow_newUser_isTrue() = assertTrue(OnboardingRules.shouldShow(done = false, accessGranted = false, paymentAppsChosen = false))
    @Test fun shouldShow_existingUserWithAccess_isFalse() = assertFalse(OnboardingRules.shouldShow(false, accessGranted = true, paymentAppsChosen = true))
    @Test fun shouldShow_appsChosenBefore_isFalse() = assertFalse(OnboardingRules.shouldShow(false, accessGranted = false, paymentAppsChosen = true))
    @Test fun shouldShow_doneFlagSet_isFalse() = assertFalse(OnboardingRules.shouldShow(done = true, accessGranted = false, paymentAppsChosen = false))
    @Test fun blockedHelp_android13_afterSettings_isTrue() = assertTrue(OnboardingRules.blockedHelp(33, openedSettings = true, accessGranted = false))
    @Test fun blockedHelp_android12_isFalse() = assertFalse(OnboardingRules.blockedHelp(32, openedSettings = true, accessGranted = false))
    @Test fun blockedHelp_beforeSettings_isFalse() = assertFalse(OnboardingRules.blockedHelp(35, openedSettings = false, accessGranted = false))
    @Test fun next_fromAccess_withAccess_goesToApps() = assertEquals(OnboardingStep.APPS, OnboardingRules.afterSettings(OnboardingStep.ACCESS, 35, accessGranted = true))
    @Test fun next_fromAccess_blockedOn14_goesToBlocked() = assertEquals(OnboardingStep.BLOCKED, OnboardingRules.afterSettings(OnboardingStep.ACCESS, 34, accessGranted = false))
    @Test fun next_fromAccess_noAccessOn12_staysOnAccess() = assertEquals(OnboardingStep.ACCESS, OnboardingRules.afterSettings(OnboardingStep.ACCESS, 31, accessGranted = false))
    @Test fun next_fromBlocked_withAccess_goesToApps() = assertEquals(OnboardingStep.APPS, OnboardingRules.afterSettings(OnboardingStep.BLOCKED, 34, accessGranted = true))
    @Test fun next_fromRunning_isUnchanged() = assertEquals(OnboardingStep.RUNNING, OnboardingRules.afterSettings(OnboardingStep.RUNNING, 34, accessGranted = true))
    @Test fun onResume_grantedWithoutFlag_fromBlocked_goesToApps() = assertEquals(OnboardingStep.APPS, OnboardingRules.onResume(OnboardingStep.BLOCKED, 34, true, false))
    @Test fun onResume_grantedWithoutFlag_fromAccess_goesToApps() = assertEquals(OnboardingStep.APPS, OnboardingRules.onResume(OnboardingStep.ACCESS, 34, true, false))
    @Test fun onResume_notGrantedWithoutFlag_staysOnAccess() = assertEquals(OnboardingStep.ACCESS, OnboardingRules.onResume(OnboardingStep.ACCESS, 34, false, false))
    @Test fun onResume_notGrantedWithFlagOn14_goesToBlocked() = assertEquals(OnboardingStep.BLOCKED, OnboardingRules.onResume(OnboardingStep.ACCESS, 34, false, true))
    @Test fun onResume_running_isUnchanged() = assertEquals(OnboardingStep.RUNNING, OnboardingRules.onResume(OnboardingStep.RUNNING, 34, true, true))
    @Test fun stepNumber_blockedSharesAccessStep() = assertEquals(1, OnboardingRules.stepNumber(OnboardingStep.BLOCKED))
    @Test fun stepNumber_welcomeHasNone() = assertNull(OnboardingRules.stepNumber(OnboardingStep.WELCOME))
}
