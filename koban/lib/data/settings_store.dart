import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app settings. The keys and defaults equal `SettingsRepository.kt` of 0.1.1.
/// The 0.1.1 import copied the values into the same keys.
class KobanSettings {
  KobanSettings._(this._prefs);

  static const _darkModeKey = 'dark_mode';
  static const _onboardingDoneKey = 'onboarding_done';
  static const _chosenKey = 'payment_apps_chosen';
  static const _allowlistKey = 'payment_app_allowlist';
  static const _onlineFeaturesKey = 'online_features';
  static const _deviceTokenKey = 'device_token';

  final SharedPreferencesAsync _prefs;

  final _darkMode = ValueNotifier<bool>(true);
  final _onboardingDone = ValueNotifier<bool>(false);
  final _paymentAppsChosen = ValueNotifier<bool>(false);
  final _paymentApps = ValueNotifier<Set<String>>(const {});
  final _onlineFeatures = ValueNotifier<bool>(true);
  final _hasDeviceToken = ValueNotifier<bool>(false);

  static Future<KobanSettings> load(SharedPreferencesAsync prefs) async {
    final settings = KobanSettings._(prefs);
    await settings.reload();
    return settings;
  }

  /// Dark mode. On by default.
  ValueListenable<bool> get darkMode => _darkMode;
  ValueListenable<bool> get onboardingDone => _onboardingDone;

  /// True when the owner chose the payment apps.
  /// Unset means chosen when an older version stored a list.
  ValueListenable<bool> get paymentAppsChosen => _paymentAppsChosen;
  ValueListenable<Set<String>> get paymentApps => _paymentApps;

  /// The online features switch. On by default.
  ValueListenable<bool> get onlineFeatures => _onlineFeatures;
  ValueListenable<bool> get hasDeviceToken => _hasDeviceToken;

  Future<void> setDarkMode(bool on) async {
    await _prefs.setBool(_darkModeKey, on);
    _darkMode.value = on;
  }

  Future<void> setOnboardingDone() async {
    await _prefs.setBool(_onboardingDoneKey, true);
    _onboardingDone.value = true;
  }

  Future<void> setOnlineFeatures(bool on) async {
    await _prefs.setBool(_onlineFeaturesKey, on);
    _onlineFeatures.value = on;
  }

  Future<void> removeDeviceToken() async {
    await _prefs.remove(_deviceTokenKey);
    _hasDeviceToken.value = false;
  }

  /// Read every value again. Use it after another writer changed the settings.
  Future<void> reload() async {
    final list =
        (await _prefs.getStringList(_allowlistKey))?.toSet() ?? <String>{};
    _paymentApps.value = list;
    _paymentAppsChosen.value =
        await _prefs.getBool(_chosenKey) ?? list.isNotEmpty;
    _darkMode.value = await _prefs.getBool(_darkModeKey) ?? true;
    _onboardingDone.value = await _prefs.getBool(_onboardingDoneKey) ?? false;
    _onlineFeatures.value = await _prefs.getBool(_onlineFeaturesKey) ?? true;
    _hasDeviceToken.value =
        (await _prefs.getString(_deviceTokenKey) ?? '').isNotEmpty;
  }
}
