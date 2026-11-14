import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

/// The device token and the group session. Never log a value.
/// On Android they are in `shared_prefs/koban_secrets.xml`, which the backup rules leave out,
/// as 0.1.1 left out its `secrets` DataStore. The keys are the 0.1.1 keys.
class SecretStore {
  SecretStore(this._prefs);

  /// The store of the phone: the not-backed-up secrets file on Android.
  static SecretStore forPhone() => SecretStore(
    SharedPreferencesAsync(
      options: Platform.isAndroid
          ? const SharedPreferencesAsyncAndroidOptions(
              backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
              originalSharedPreferencesOptions:
                  AndroidSharedPreferencesStoreOptions(
                    fileName: 'koban_secrets',
                  ),
            )
          : const SharedPreferencesOptions(),
    ),
  );

  static const _deviceTokenKey = 'device_token';
  static const _groupSessionKey = 'group_session';

  final SharedPreferencesAsync _prefs;
  final _deviceToken = ValueNotifier<String>('');

  /// Given by Koban's server for a good invite code. Empty means no online access.
  ValueListenable<String> get deviceToken => _deviceToken;

  /// Reads the device token again.
  Future<void> load() async {
    _deviceToken.value = await _prefs.getString(_deviceTokenKey) ?? '';
  }

  /// Moves the two secrets out of the main [settings], where the 0.1.1 import put them.
  /// A value that the store already has stays. The copy comes before the removal,
  /// so a stop between the two steps loses no value.
  Future<void> migrate(SharedPreferencesAsync settings) async {
    for (final key in const [_deviceTokenKey, _groupSessionKey]) {
      final old = await settings.getString(key);
      if (old == null) continue;
      final current = await _prefs.getString(key) ?? '';
      if (current.trim().isEmpty && old.trim().isNotEmpty) {
        await _prefs.setString(key, old);
      }
      await settings.remove(key);
    }
    await load();
  }

  /// Stores the device token. A blank token removes the key, as 0.1.1 did.
  Future<void> setDeviceToken(String token) async {
    if (token.trim().isEmpty) {
      await _prefs.remove(_deviceTokenKey);
      _deviceToken.value = '';
    } else {
      await _prefs.setString(_deviceTokenKey, token);
      _deviceToken.value = token;
    }
  }

  /// The group session JSON, or null when signed out.
  Future<String?> groupSession() async {
    final json = await _prefs.getString(_groupSessionKey);
    return json == null || json.trim().isEmpty ? null : json;
  }

  /// Stores the group session JSON. Null or blank removes the key, as 0.1.1 did.
  Future<void> setGroupSession(String? json) async {
    if (json == null || json.trim().isEmpty) {
      await _prefs.remove(_groupSessionKey);
    } else {
      await _prefs.setString(_groupSessionKey, json);
    }
  }
}
