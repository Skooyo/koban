import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../app/app_services.dart';
import 'onboarding_rules.dart';

/// The state of onboarding (`OnboardingViewModel.kt` of 0.1.1): the step,
/// the access settings flag and the rows of Keep Koban running.
/// The step and the flag are stored, so onboarding comes back at the same step
/// after Android stops the app (0.1.1 keeps them in a `SavedStateHandle`).
class OnboardingViewModel extends ChangeNotifier {
  OnboardingViewModel(this._s) {
    final stored = _s.settings.onboardingStep;
    if (stored == null) return;
    _step = OnboardingStep.values.asNameMap()[stored] ?? OnboardingStep.welcome;
    _openedSettings = _s.settings.onboardingOpenedSettings;
    // As the first resume of 0.1.1 after a restart: access can be on now.
    unawaited(onResume());
  }

  final AppServices _s;
  var _disposed = false;
  var _step = OnboardingStep.welcome;
  var _openedSettings = false;
  int? _sdkInt;
  var _autostartOpened = false;

  OnboardingStep get step => _step;

  /// The rows of Keep Koban running. Null until the first read of the phone state.
  RunningRows? _running;
  RunningRows? get running => _running;

  /// True after the first tap on Allow in this visit of the running step.
  var _askedForAlerts = false;
  var _alertsBusy = false;

  Future<int> _sdk() async => _sdkInt ??= await _s.device.sdkInt();

  void _go(OnboardingStep to) {
    if (to == _step) return;
    if (to == OnboardingStep.running) {
      _askedForAlerts = false;
      unawaited(refreshRunning());
    }
    _step = to;
    unawaited(_save());
    notifyListeners();
  }

  /// Stores the step and the flag. A failed write is logged and onboarding goes on.
  Future<void> _save() async {
    try {
      await _s.settings.setOnboardingProgress(
        _step.name,
        openedSettings: _openedSettings,
      );
    } catch (e, s) {
      _log('Onboarding step not stored', e, s);
    }
  }

  static void _log(String message, Object e, StackTrace s) =>
      developer.log(message, name: 'Onboarding', error: e, stackTrace: s);

  void next() => switch (_step) {
    OnboardingStep.welcome => _go(OnboardingStep.access),
    OnboardingStep.apps => _go(OnboardingStep.running),
    OnboardingStep.running => _go(OnboardingStep.ready),
    _ => null,
  };

  /// Save can be tapped twice. Only the first tap leaves the apps step.
  void appsSaved() {
    if (_step == OnboardingStep.apps) _go(OnboardingStep.running);
  }

  /// True when the owner chose the payment apps and chose none.
  bool get listensToNoApp =>
      _s.settings.paymentAppsChosen.value &&
      _s.settings.paymentApps.value.isEmpty;

  /// The Choose apps button of the Ready step with no app.
  void chooseApps() => _go(OnboardingStep.apps);

  void back() => switch (_step) {
    OnboardingStep.access ||
    OnboardingStep.blocked => _go(OnboardingStep.welcome),
    OnboardingStep.apps => _go(OnboardingStep.access),
    OnboardingStep.running => _go(OnboardingStep.apps),
    OnboardingStep.ready => _go(OnboardingStep.running),
    OnboardingStep.welcome => null,
  };

  /// True after the friend came back from the Autostart settings.
  bool get autostartChecked => _s.settings.onboardingAutostartChecked;

  /// The Autostart row. The phone cannot tell its state, so a return counts as checked.
  void openAutostart() {
    _autostartOpened = true;
    unawaited(_s.listener.openBackgroundSettings());
  }

  /// Call it just before the screen opens the access settings.
  void openedSettings() {
    _openedSettings = true;
    unawaited(_save());
  }

  /// Back from the system settings page: moves on if access is on, or shows the blocked help.
  /// On the running step it reads the rows again.
  Future<void> onResume() async {
    try {
      final opened = _openedSettings;
      final granted = await _s.listener.isAccessGranted();
      final sdk = await _sdk();
      if (_disposed) return;
      _go(
        OnboardingRules.onResume(
          _step,
          sdk,
          accessGranted: granted,
          openedSettings: opened,
        ),
      );
      if (opened) {
        _openedSettings = false;
        unawaited(_save());
      }
      if (_autostartOpened && _step == OnboardingStep.running) {
        _autostartOpened = false;
        await _s.settings.setOnboardingAutostartChecked();
      }
      if (_step == OnboardingStep.running) await refreshRunning();
    } catch (e, s) {
      _log('Resume check failed', e, s);
    }
  }

  /// Reads the phone state of the running rows again.
  Future<void> refreshRunning() async {
    try {
      final sdk = await _sdk();
      final rows = RunningRows(
        showAlerts: sdk >= 33,
        alertsAllowed: sdk >= 33 && await _s.device.notificationsAllowed(),
        batteryIgnored: await _s.listener.isBatteryOptimizationIgnored(),
        xiaomi: await _s.listener.isXiaomiFamily(),
      );
      if (_disposed) return;
      _running = rows;
      notifyListeners();
    } catch (e, s) {
      _log('Running rows not read', e, s);
    }
  }

  /// The Allow button of the Alerts row. After two denials Android shows no dialog,
  /// so after one request it opens the settings page when Android gives no rationale.
  Future<void> allowAlerts() async {
    if (_alertsBusy) return;
    _alertsBusy = true;
    try {
      final d = _s.device;
      if (_askedForAlerts && !await d.shouldShowNotificationRationale()) {
        await d.openAppNotificationSettings();
      } else {
        _askedForAlerts = true;
        await d.requestNotificationPermission();
        await refreshRunning();
      }
    } finally {
      _alertsBusy = false;
    }
  }

  /// Saves the done flag and removes the stored step. The screen closes after it.
  Future<void> finish() => _s.settings.setOnboardingDone();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The phone state that Keep Koban running shows.
class RunningRows {
  const RunningRows({
    required this.showAlerts,
    required this.alertsAllowed,
    required this.batteryIgnored,
    required this.xiaomi,
  });

  /// True from Android 13: the alerts permission exists.
  final bool showAlerts;
  final bool alertsAllowed;
  final bool batteryIgnored;
  final bool xiaomi;
}
