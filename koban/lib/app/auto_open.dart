import '../screens/onboarding/onboarding_rules.dart';
import 'app_services.dart';

/// The page that the app opens by itself when it comes to the front.
enum AutoOpenTarget { onboarding, paymentApps, checkPayments }

/// The auto-open rule of 0.1.1 (`ExpenseTrackerNavHost.kt` and `AppViewModel.kt`):
/// onboarding comes first, then the payment apps picker, then Check payments.
class AutoOpen {
  AutoOpen(this._s);

  final AppServices _s;

  /// The page to open now, or null for none.
  Future<AutoOpenTarget?> decide() async {
    final settings = _s.settings;
    final chosen = settings.paymentAppsChosen.value;
    final granted = await _s.listener.isAccessGranted();
    final done = settings.onboardingDone.value;
    // A stored step: Android stopped the app during onboarding (0.1.1 restores its back stack).
    if ((!done && settings.onboardingStep != null) ||
        OnboardingRules.shouldShow(
          done: done,
          accessGranted: granted,
          paymentAppsChosen: chosen,
        )) {
      return AutoOpenTarget.onboarding;
    }
    if (granted && !chosen) return AutoOpenTarget.paymentApps;
    // A fresh read: payments can arrive while the app is in the background.
    final waiting = await _s.paymentChecks.visibleCount();
    return waiting > 0 ? AutoOpenTarget.checkPayments : null;
  }
}
