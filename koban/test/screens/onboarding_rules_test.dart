import 'package:flutter_test/flutter_test.dart';
import 'package:koban/screens/onboarding/onboarding_rules.dart';

// One test for each case of `OnboardingRulesTest.kt` of 0.1.1.
void main() {
  test('a new user sees onboarding', () {
    expect(
      OnboardingRules.shouldShow(
        done: false,
        accessGranted: false,
        paymentAppsChosen: false,
      ),
      true,
    );
  });

  test('an existing user with access does not see onboarding', () {
    expect(
      OnboardingRules.shouldShow(
        done: false,
        accessGranted: true,
        paymentAppsChosen: true,
      ),
      false,
    );
  });

  test('a user who chose the apps before does not see onboarding', () {
    expect(
      OnboardingRules.shouldShow(
        done: false,
        accessGranted: false,
        paymentAppsChosen: true,
      ),
      false,
    );
  });

  test('a user with the done flag does not see onboarding', () {
    expect(
      OnboardingRules.shouldShow(
        done: true,
        accessGranted: false,
        paymentAppsChosen: false,
      ),
      false,
    );
  });

  test('Android 13 after the settings shows the blocked help', () {
    expect(
      OnboardingRules.blockedHelp(
        33,
        openedSettings: true,
        accessGranted: false,
      ),
      true,
    );
  });

  test('Android 12 does not show the blocked help', () {
    expect(
      OnboardingRules.blockedHelp(
        32,
        openedSettings: true,
        accessGranted: false,
      ),
      false,
    );
  });

  test('the blocked help does not show before the settings open', () {
    expect(
      OnboardingRules.blockedHelp(
        35,
        openedSettings: false,
        accessGranted: false,
      ),
      false,
    );
  });

  test('access after the settings goes to the payment apps step', () {
    expect(
      OnboardingRules.afterSettings(
        OnboardingStep.access,
        35,
        accessGranted: true,
      ),
      OnboardingStep.apps,
    );
  });

  test(
    'no access after the settings on Android 14 goes to the blocked help',
    () {
      expect(
        OnboardingRules.afterSettings(
          OnboardingStep.access,
          34,
          accessGranted: false,
        ),
        OnboardingStep.blocked,
      );
    },
  );

  test('no access after the settings on Android 12 stays on access', () {
    expect(
      OnboardingRules.afterSettings(
        OnboardingStep.access,
        31,
        accessGranted: false,
      ),
      OnboardingStep.access,
    );
  });

  test('access after the blocked help goes to the payment apps step', () {
    expect(
      OnboardingRules.afterSettings(
        OnboardingStep.blocked,
        34,
        accessGranted: true,
      ),
      OnboardingStep.apps,
    );
  });

  test('the settings do not change the running step', () {
    expect(
      OnboardingRules.afterSettings(
        OnboardingStep.running,
        34,
        accessGranted: true,
      ),
      OnboardingStep.running,
    );
  });

  test(
    'a resume with access on the blocked help goes to the payment apps step',
    () {
      expect(
        OnboardingRules.onResume(
          OnboardingStep.blocked,
          34,
          accessGranted: true,
          openedSettings: false,
        ),
        OnboardingStep.apps,
      );
    },
  );

  test(
    'a resume with access on the access step goes to the payment apps step',
    () {
      expect(
        OnboardingRules.onResume(
          OnboardingStep.access,
          34,
          accessGranted: true,
          openedSettings: false,
        ),
        OnboardingStep.apps,
      );
    },
  );

  test('a resume without access and without the settings stays on access', () {
    expect(
      OnboardingRules.onResume(
        OnboardingStep.access,
        34,
        accessGranted: false,
        openedSettings: false,
      ),
      OnboardingStep.access,
    );
  });

  test('a resume without access after the settings on Android 14 goes to the blocked help', () {
    expect(
      OnboardingRules.onResume(
        OnboardingStep.access,
        34,
        accessGranted: false,
        openedSettings: true,
      ),
      OnboardingStep.blocked,
    );
  });

  test('a resume does not change the running step', () {
    expect(
      OnboardingRules.onResume(
        OnboardingStep.running,
        34,
        accessGranted: true,
        openedSettings: true,
      ),
      OnboardingStep.running,
    );
  });

  test('the blocked help has the step number of access', () {
    expect(OnboardingRules.stepNumber(OnboardingStep.blocked), 1);
  });

  test('the welcome step has no step number', () {
    expect(OnboardingRules.stepNumber(OnboardingStep.welcome), null);
  });
}
