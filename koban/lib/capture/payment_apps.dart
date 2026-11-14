import 'package:shared_preferences/shared_preferences.dart';

import 'capture_host.dart';

/// The payment apps that the owner chose. Settings hold them.
/// The native listener keeps a copy, so it can filter when the app is closed.
class PaymentApps {
  PaymentApps(this._prefs, this._host);

  static const allowlistKey = 'payment_app_allowlist';
  static const chosenKey = 'payment_apps_chosen';

  final SharedPreferencesAsync _prefs;
  final CaptureHost? _host;

  /// The chosen apps. Empty when no key exists.
  Future<Set<String>> load() async =>
      (await _prefs.getStringList(allowlistKey))?.toSet() ?? <String>{};

  /// Write the apps to settings, then send them to the native listener.
  Future<void> save(Set<String> apps) async {
    await _prefs.setStringList(allowlistKey, apps.toList()..sort());
    await _prefs.setBool(chosenKey, true);
    await _host?.setPaymentApps(apps);
  }

  /// Send the saved apps to the native listener.
  Future<void> syncToNative() async => _host?.setPaymentApps(await load());
}
