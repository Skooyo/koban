import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../online/secret_store.dart';

/// The app settings. The keys and defaults equal `SettingsRepository.kt` of 0.1.1,
/// except dark mode, which is off by default since the Mon's desk redesign.
/// The 0.1.1 import copied the values into the same keys.
/// The device token is in the [SecretStore], as 0.1.1 kept it in its secrets store.
class KobanSettings {
  KobanSettings._(this._prefs, this._secrets);

  static const _darkModeKey = 'dark_mode';
  static const _onboardingDoneKey = 'onboarding_done';
  static const _chosenKey = 'payment_apps_chosen';
  static const _allowlistKey = 'payment_app_allowlist';
  static const _onlineFeaturesKey = 'online_features';
  static const _lastUpdateCheckKey = 'last_update_check';

  // Flutter only: 0.1.1 kept these two values in a SavedStateHandle.
  static const _onboardingStepKey = 'flutter_onboarding_step';
  static const _onboardingOpenedKey = 'flutter_onboarding_opened_settings';

  final SharedPreferencesAsync _prefs;
  final SecretStore _secrets;

  final _darkMode = ValueNotifier<bool>(false);
  final _onboardingDone = ValueNotifier<bool>(false);
  final _paymentAppsChosen = ValueNotifier<bool>(false);
  final _paymentApps = ValueNotifier<Set<String>>(const {});
  final _onlineFeatures = ValueNotifier<bool>(true);
  final _hasDeviceToken = ValueNotifier<bool>(false);
  String? _onboardingStep;
  var _onboardingOpenedSettings = false;

  /// Loads the settings. [hasDeviceToken] follows the device token of [secrets].
  static Future<KobanSettings> load(
    SharedPreferencesAsync prefs, {
    required SecretStore secrets,
  }) async {
    final settings = KobanSettings._(prefs, secrets);
    secrets.deviceToken.addListener(settings._readDeviceToken);
    await settings.reload();
    return settings;
  }

  void _readDeviceToken() =>
      _hasDeviceToken.value = _secrets.deviceToken.value.isNotEmpty;

  /// Dark mode. Off by default. A stored choice wins.
  ValueListenable<bool> get darkMode => _darkMode;
  ValueListenable<bool> get onboardingDone => _onboardingDone;

  /// True when the owner chose the payment apps.
  /// Unset means chosen when an older version stored a list.
  ValueListenable<bool> get paymentAppsChosen => _paymentAppsChosen;
  ValueListenable<Set<String>> get paymentApps => _paymentApps;

  /// The online features switch. On by default.
  ValueListenable<bool> get onlineFeatures => _onlineFeatures;
  ValueListenable<bool> get hasDeviceToken => _hasDeviceToken;

  /// The name of the onboarding step that showed last. Null before the first step change
  /// and after onboarding is done. It brings onboarding back after Android stops the app.
  String? get onboardingStep => _onboardingStep;

  /// True when the friend opened the access settings from onboarding and did not come back yet.
  bool get onboardingOpenedSettings => _onboardingOpenedSettings;

  Future<void> setDarkMode(bool on) async {
    await _prefs.setBool(_darkModeKey, on);
    _darkMode.value = on;
  }

  /// Stores the onboarding step and the access settings flag.
  Future<void> setOnboardingProgress(
    String step, {
    required bool openedSettings,
  }) async {
    _onboardingStep = step;
    _onboardingOpenedSettings = openedSettings;
    await _prefs.setString(_onboardingStepKey, step);
    await _prefs.setBool(_onboardingOpenedKey, openedSettings);
  }

  /// Stores onboarding as done and removes the stored step.
  Future<void> setOnboardingDone() async {
    await _prefs.setBool(_onboardingDoneKey, true);
    _onboardingDone.value = true;
    _onboardingStep = null;
    _onboardingOpenedSettings = false;
    await _prefs.remove(_onboardingStepKey);
    await _prefs.remove(_onboardingOpenedKey);
  }

  Future<void> setOnlineFeatures(bool on) async {
    await _prefs.setBool(_onlineFeaturesKey, on);
    _onlineFeatures.value = on;
  }

  /// The time of the last update check in ms. 0 when there was none.
  Future<int> lastUpdateCheck() async =>
      await _prefs.getInt(_lastUpdateCheckKey) ?? 0;

  Future<void> setLastUpdateCheck(int ms) =>
      _prefs.setInt(_lastUpdateCheckKey, ms);

  Future<void> removeDeviceToken() => _secrets.setDeviceToken('');

  /// Read every value again, the device token of the secrets store too.
  /// Use it after another writer changed the settings.
  Future<void> reload() async {
    final list =
        (await _prefs.getStringList(_allowlistKey))?.toSet() ?? <String>{};
    _paymentApps.value = list;
    _paymentAppsChosen.value =
        await _prefs.getBool(_chosenKey) ?? list.isNotEmpty;
    _darkMode.value = await _prefs.getBool(_darkModeKey) ?? false;
    _onboardingDone.value = await _prefs.getBool(_onboardingDoneKey) ?? false;
    _onboardingStep = await _prefs.getString(_onboardingStepKey);
    _onboardingOpenedSettings =
        await _prefs.getBool(_onboardingOpenedKey) ?? false;
    _onlineFeatures.value = await _prefs.getBool(_onlineFeaturesKey) ?? true;
    await _secrets.load();
    _readDeviceToken();
  }
}
