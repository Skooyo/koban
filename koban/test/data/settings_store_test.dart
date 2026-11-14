import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/settings_store.dart';
import 'package:koban/online/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late SharedPreferencesAsync prefs;

  void store(Map<String, Object> data) {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData(data);
    prefs = SharedPreferencesAsync();
  }

  /// Loads the settings of [prefs] with an empty secrets store.
  Future<KobanSettings> load() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
    return KobanSettings.load(
      prefs,
      secrets: SecretStore(SharedPreferencesAsync()),
    );
  }

  test('settings have the 0.1.1 defaults', () async {
    store({});

    final s = await load();

    expect(s.darkMode.value, isTrue);
    expect(s.onboardingDone.value, isFalse);
    expect(s.paymentAppsChosen.value, isFalse);
    expect(s.paymentApps.value, <String>{});
    expect(s.onlineFeatures.value, isTrue);
    expect(s.hasDeviceToken.value, isFalse);
  });

  test('an older stored app list counts as chosen', () async {
    store({
      'payment_app_allowlist': ['com.maybank2u.life'],
    });

    final s = await load();

    expect(s.paymentAppsChosen.value, isTrue);
    expect(s.paymentApps.value, {'com.maybank2u.life'});
  });

  test('a stored chosen flag wins over the list', () async {
    store({'payment_apps_chosen': false, 'onboarding_done': true});

    final s = await load();

    expect(s.paymentAppsChosen.value, isFalse);
    expect(s.onboardingDone.value, isTrue);
  });

  test('dark mode is stored under dark_mode', () async {
    store({});
    final s = await load();

    await s.setDarkMode(false);

    expect(await prefs.getBool('dark_mode'), isFalse);
    expect(s.darkMode.value, isFalse);
  });

  test('onboarding and online features are stored under their keys', () async {
    store({});
    final s = await load();

    await s.setOnboardingDone();
    await s.setOnlineFeatures(false);

    expect(await prefs.getBool('onboarding_done'), isTrue);
    expect(await prefs.getBool('online_features'), isFalse);
    expect((s.onboardingDone.value, s.onlineFeatures.value), (true, false));
  });

  test('reload reads values that another writer stored', () async {
    store({});
    final s = await load();

    await prefs.setStringList('payment_app_allowlist', [
      'my.com.tngdigital.ewallet',
    ]);
    await prefs.setBool('dark_mode', false);
    await s.reload();

    expect(s.paymentApps.value, {'my.com.tngdigital.ewallet'});
    expect(s.paymentAppsChosen.value, isTrue);
    expect(s.darkMode.value, isFalse);
  });
}
