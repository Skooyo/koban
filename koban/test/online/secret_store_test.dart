import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/settings_store.dart';
import 'package:koban/online/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Preferences on a new in-memory store with [data].
SharedPreferencesAsync memory(Map<String, Object> data) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(data);
  return SharedPreferencesAsync();
}

void main() {
  const session = '{"refresh_token":"r1","user_id":"user-1"}';
  late SharedPreferencesAsync secrets;
  late SecretStore store;

  void open(Map<String, Object> data) {
    secrets = memory(data);
    store = SecretStore(secrets);
  }

  test(
    'migrate moves the device token and the group session out of the settings',
    () async {
      final settings = memory({
        'device_token': 'test-device-token',
        'group_session': session,
        'dark_mode': false,
      });
      open({});

      await store.migrate(settings);

      expect(store.deviceToken.value, 'test-device-token');
      expect(await store.groupSession(), session);
      expect(await settings.getString('device_token'), isNull);
      expect(await settings.getString('group_session'), isNull);
      expect(await settings.getBool('dark_mode'), isFalse);
    },
  );

  test('migrate keeps a value that the store already has', () async {
    final settings = memory({'device_token': 'old', 'group_session': 'old'});
    open({'device_token': 'new', 'group_session': 'new'});

    await store.migrate(settings);

    expect(store.deviceToken.value, 'new');
    expect(await store.groupSession(), 'new');
    expect(await settings.getKeys(), <String>{});
  });

  test('migrate with no keys changes nothing', () async {
    final settings = memory({'dark_mode': true});
    open({});

    await store.migrate(settings);

    expect(store.deviceToken.value, '');
    expect(await store.groupSession(), isNull);
    expect(await secrets.getKeys(), <String>{});
    expect(await settings.getKeys(), {'dark_mode'});
  });

  test('a blank device token removes the key', () async {
    open({'device_token': 'test-device-token'});
    await store.load();
    expect(store.deviceToken.value, 'test-device-token');

    await store.setDeviceToken('  ');

    expect(store.deviceToken.value, '');
    expect(await secrets.containsKey('device_token'), isFalse);
  });

  test('a null group session removes the key', () async {
    open({'group_session': session});

    await store.setGroupSession(null);

    expect(await store.groupSession(), isNull);
    expect(await secrets.containsKey('group_session'), isFalse);
  });

  test('the settings see the device token of the store', () async {
    open({'device_token': 'test-device-token'});
    await store.load();
    final settings = await KobanSettings.load(memory({}), secrets: store);
    expect(settings.hasDeviceToken.value, isTrue);

    await settings.removeDeviceToken();

    expect(settings.hasDeviceToken.value, isFalse);
    expect(store.deviceToken.value, '');
    expect(await secrets.containsKey('device_token'), isFalse);

    await store.setDeviceToken('test-device-token');
    expect(settings.hasDeviceToken.value, isTrue);
  });
}
