/// The steps of onboarding, in order. The blocked help replaces the access step.
enum OnboardingStep { welcome, access, blocked, apps, running, ready }

/// The onboarding rules of 0.1.1 (`OnboardingRules.kt`).
abstract final class OnboardingRules {
  /// Only a new user sees onboarding. Anyone with access or a saved app choice is an existing user.
  static bool shouldShow({
    required bool done,
    required bool accessGranted,
    required bool paymentAppsChosen,
  }) => !done && !accessGranted && !paymentAppsChosen;

  /// Android 13 and later can block notification access for a sideloaded app until the user allows it.
  static bool blockedHelp(
    int sdkInt, {
    required bool openedSettings,
    required bool accessGranted,
  }) => sdkInt >= 33 && openedSettings && !accessGranted;

  /// The step after the friend comes back from the access settings.
  static OnboardingStep afterSettings(
    OnboardingStep step,
    int sdkInt, {
    required bool accessGranted,
  }) {
    if (step != OnboardingStep.access && step != OnboardingStep.blocked) {
      return step;
    }
    if (accessGranted) return OnboardingStep.apps;
    if (blockedHelp(sdkInt, openedSettings: true, accessGranted: false)) {
      return OnboardingStep.blocked;
    }
    return step;
  }

  /// Back in the app: granted access moves on even when the user did not use our button.
  static OnboardingStep onResume(
    OnboardingStep step,
    int sdkInt, {
    required bool accessGranted,
    required bool openedSettings,
  }) {
    if (accessGranted &&
        (step == OnboardingStep.access || step == OnboardingStep.blocked)) {
      return OnboardingStep.apps;
    }
    if (openedSettings) {
      return afterSettings(step, sdkInt, accessGranted: accessGranted);
    }
    return step;
  }

  /// The number of the step in "Step n of 4". Welcome has none.
  static int? stepNumber(OnboardingStep step) => switch (step) {
    OnboardingStep.welcome => null,
    OnboardingStep.access || OnboardingStep.blocked => 1,
    OnboardingStep.apps => 2,
    OnboardingStep.running => 3,
    OnboardingStep.ready => 4,
  };
}
