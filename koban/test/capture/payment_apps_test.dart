import 'package:flutter_test/flutter_test.dart';
import 'package:koban/capture/payment_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fake_capture_host.dart';

void main() {
  late SharedPreferencesAsync prefs;
  late FakeCaptureHost host;
  late PaymentApps apps;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
    host = FakeCaptureHost();
    apps = PaymentApps(prefs, host);
  });

  test('saving payment apps writes the settings and the native copy', () async {
    await apps.save({'my.com.tngdigital.ewallet', 'com.maybank2u.life'});
    expect(await prefs.getStringList('payment_app_allowlist'), [
      'com.maybank2u.life',
      'my.com.tngdigital.ewallet',
    ]);
    expect(await prefs.getBool('payment_apps_chosen'), true);
    expect(host.paymentApps, {
      'com.maybank2u.life',
      'my.com.tngdigital.ewallet',
    });
  });

  test('sync sends an empty set when no apps are chosen', () async {
    await apps.syncToNative();
    expect(host.paymentApps, <String>{});
  });

  test('sync sends the saved apps', () async {
    await prefs.setStringList('payment_app_allowlist', ['com.maybank2u.life']);
    await apps.syncToNative();
    expect(host.paymentApps, {'com.maybank2u.life'});
  });
}
