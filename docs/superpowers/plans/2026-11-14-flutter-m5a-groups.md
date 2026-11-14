# Flutter milestone 5a: online base, invite code, Google sign-in and groups — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Flutter app the 0.1.1 online parts for groups: the build-time online settings, a secrets store, the invite code check, the group sign-in restored from the 0.1.1 session (or Google sign-in again), the groups list, the group page, the shared totals sync and delete account.

**Architecture:** One `OnlineServices` object in `AppServices` holds the online settings (read once from native `BuildConfig`), one shared `http.Client`, the `SecretStore` (a separate, not-backed-up preferences file for the device token and the group session), a `SupabaseClient` with automatic token refresh off, and the repositories. Every network call goes through a class that first reads the `online_features` setting. The group session keeps the 0.1.1 JSON format in the secrets store; at each app start (Online features on) the stored refresh token goes to `auth.setSession(refreshToken)`, which gives a new session or a refusal. `GroupRepository` ports the 0.1.1 `GroupRepository.kt` (reads, RPC actions with the same status words and messages, the shared totals sync). The screens port `GroupsScreen.kt` and `GroupsViewModel.kt` with the milestone 4 pattern (one `ChangeNotifier` per screen, `KobanPageRoute`).

**Tech Stack:** Flutter 3.50.0 / Dart 3.14.0; milestones 1 to 4. New pub packages: `supabase` 2.16.x (pure Dart client that `supabase_flutter` wraps; 2.16.5 is the newest stable on 14 Nov 2026, verify at Task 1), `http` 1.x (already in `pubspec.lock` through other packages; becomes direct; `package:http/testing.dart` `MockClient` for tests), `google_sign_in` 7.2.x (`google_sign_in_android` uses Android Credential Manager with `GetSignInWithGoogleOption` for `authenticate()`, the same button flow as 0.1.1; verify version at Task 1). No new Kotlin library.

**Spec:** `docs/superpowers/specs/2026-11-13-flutter-migration-design.md` (6.2 "Online", 6.4 step 3, 6.7 item 5). Reference: `app/src/main/java/com/expensetracker/app/groups/` (`SupabaseClient.kt`, `GroupRepository.kt`), `ui/screens/GroupsScreen.kt`, `ui/viewmodel/GroupsViewModel.kt`, `ui/viewmodel/SettingsViewModel.kt` (`enterInviteCode`), `parser/ReceiptCloudClient.kt` (`register`), `data/SettingsRepository.kt`, `data/ExpenseDao.kt` (`groupTotals`), `supabase/functions/` and `supabase/migrations/20261112020000_groups.sql`. Contract: Interfaces blocks of the milestone 3 plan and plans 4a, 4b, 4c.

**Order:** milestone 5 has 3 plans, executed and merged in this order: **5a (this plan)**, `2026-11-14-flutter-m5b-receipts.md`, `2026-11-14-flutter-m5c-updater.md`. Start 5a on branch `feature/flutter-m5a` from `main` after plan 4c is merged.

**Decisions (the spec leaves these to the builder):**
1. **`supabase` (pure Dart) with `SupabaseClient(...)` and `AuthClientOptions(autoRefreshToken: false)`, not `Supabase.initialize`.** Facts from the `supabase-v2.16.5` source: `GoTrueClient` with `autoRefreshToken` true starts a refresh timer in its constructor, and `recoverSession` signs out an expired session when auto refresh is off. A timer would make network calls with Online features off. With auto refresh off, `GoTrueClient.getSession()` (which every PostgREST and Functions call uses through `_getAccessToken`) still refreshes an expired session at the moment of a call, and every call is already behind the Online switch. `supabase_flutter` adds `app_links`, `url_launcher` and a lifecycle observer that Koban does not need; spec section 8 leaves the plugin to the builder.
2. **Session storage: the 0.1.1 format and key.** The secrets store keeps `group_session` as `{"access_token", "refresh_token", "expires_at", "user_id"}`, the same JSON that 0.1.1 wrote and milestone 2 imported. `GroupSession` writes it on each `signedIn` and `tokenRefreshed` auth event and removes it on `signedOut`. Restore at each start is `auth.setSession(refresh_token)` (one refresh call). So the first start after the update and every later start run the same code path.
3. **What the friend sees when the restore fails.** Refused (HTTP 4xx from `/auth/v1/token`): the session is removed, the Groups tab shows the sign-in page, and the snackbar shows the 0.1.1 text `Sign in again.` one time. The device token stays, so `link_account` answers `ok` for the existing profile after Google sign-in; no invite code again. No connection: the stored session stays, the Groups tab shows the groups page with `Could not reach Koban's server. Check the internet connection.`, and the next refresh (pull down, app start, Online on) tries again.
4. **Google sign-in: `google_sign_in` 7.2, not a native channel.** `authenticate()` on Android uses `GetSignInWithGoogleOption` (the 0.1.1 button flow, chosen because the bottom-sheet chooser is killed on the owner's MIUI phone) and passes the nonce. The plugin also covers iPhone in milestone 7. Limit: `initialize(nonce:)` runs once per process, so all sign-in tries in one app run share one nonce (0.1.1 made one per try). The alias comes from the `given_name` claim of the ID token, else `displayName`, else `Friend` (0.1.1 order).
5. **Build-time online settings from native `BuildConfig`, read over the `device` channel.** `koban/android/app/build.gradle.kts` reads the repository root `.env` (git-ignored, key `SUPABASE_KEY`) with the 0.1.1 `loadDotEnv` function and copies `SUPABASE_URL` and `GOOGLE_WEB_CLIENT_ID` from `app/build.gradle.kts` (public values; never write them in a plan, a test or a log). Rejected: `--dart-define-from-file` (every `flutter run`, `build` and IDE launch needs the flag; a build without it has no key and fails only at run time). Milestone 7 needs an iPhone source for the same 3 values.
6. **Secrets file not in backups.** `SecretStore` uses `SharedPreferencesAsync` with `SharedPreferencesAsyncAndroidOptions(backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences, originalSharedPreferencesOptions: AndroidSharedPreferencesStoreOptions(fileName: 'koban_secrets'))` (file `shared_prefs/koban_secrets.xml`), and the backup rules exclude that file, as 0.1.1 excluded `datastore/secrets.preferences_pb`. At each UI start, `SecretStore.migrate` moves `device_token` and `group_session` out of the main settings, where the milestone 2 import put them.
7. **Relative times ("Updated 3 hours ago") from Android `DateUtils`** over the `device` channel (`relativeTime`), so the text is the same as 0.1.1. A Dart port would guess the Android ICU texts.
8. **Call timeouts as 0.1.1:** one `TimeoutClient` (20 s for the whole call, as 0.1.1 OkHttp `callTimeout`) wraps the shared client for Supabase; the invite call uses 90 s.

**Not in this plan:** receipt reading (plan 5b). The updater (plan 5c). iPhone hiding and the iPhone source of the online settings (milestone 7). Personal budgets (`budget_limits`, map #33).

## Global Constraints

- `flutter` means `D:/flutter/bin/flutter`, `dart` means `D:/flutter/bin/dart`; run them from `koban/`. Gradle: `cd koban/android && JAVA_HOME=D:/jdk-17 ./gradlew.bat --max-workers=2 :app:testDebugUnitTest`.
- Commit steps: the controller runs them. The implementer stops after the last verification step and reports the changed files.
- Run at most one Gradle or Flutter build or test run at a time.
- Each task ends with `flutter analyze` → "No issues found!" and `flutter test` → "All tests passed!"; when Kotlin changed, also the Gradle command → BUILD SUCCESSFUL.
- `git diff main -- app/ gradle/ supabase/` stays empty. The Kotlin app and the backend do not change in this milestone.
- No test calls the real Supabase, Google or any server. Dart tests use `MockClient` and fakes; Kotlin tests use Robolectric.
- No secret value in the repository, a fixture, a test or a log: no real device token, refresh token, access token, invite code, publishable key or user id. Test values are synthetic (`test-device-token`, `r1`, `user-1`, `K7QX-M2PA`). Never print or `debugPrint` a token, a session or a request body.
- The `online_features` setting (`KobanSettings.onlineFeatures`, default true) gates every network call, as in 0.1.1. With it off, no class in this plan sends a request.
- UI text is copied byte for byte from the 0.1.1 file named in each task (`…`, `·`, `'` and `"` as in the Kotlin source). No new UI text.
- Supabase names stay: RPCs `link_account(p_device_token, p_alias)`, `make_group(p_name)` → JSON `{status}`, `ask_to_join(p_code)`, `answer_request(p_group, p_user, p_approve)`, `leave_group(p_group)`, `remove_member(p_group, p_user)`, `hand_over(p_group, p_user)`, `rename_group(p_group, p_name)`, `new_group_code(p_group)`; tables `profiles`, `groups`, `group_members`, `join_requests`, `shared_totals`, `removed_notices`; functions `register` and `delete-account`.
- Group periods use Malaysia time (fixed UTC+8), as 0.1.1 `GroupRepository.ZONE`. Every time comes from `AppServices.now`.
- Doc comments and test names in ASD-STE100 Simplified Technical English.

## Review Focus

1. A friend updates with a 0.1.1 `group_session` whose access token expired weeks ago. The Groups tab must show their groups after one refresh call, with no sign-in. A refused refresh must show the sign-in page and `Sign in again.`, and keep the device token. No connection must keep the session for the next try. Pinned in Task 3.
2. With Online features off, no request leaves the app: not the restore, the reads, the actions, the totals sync, the invite check or delete account. Pinned in Tasks 2, 3 and 4 with a `MockClient` that fails the test on any request.
3. Shared totals are exact to the cent and leave out received money, dismissed payments and payments marked private: `0.10 + 0.20` is sent as `"0.30"`. The `HAVING` test must use the number, not the text cast (SQLite orders any TEXT above any number). Pinned in Task 4.
4. A payment at Sunday 23:30 Malaysia time counts in that week, and a payment at Monday 00:00 counts in the next week, whatever the phone's time zone. Pinned in Task 4.
5. Two fast taps on `Sign in with Google`, `Make group` or `Delete account` start one call. Pinned in Task 5.

---

### Task 1: Online base: settings, secrets store, HTTP client, permissions

**Files:**
- Modify: `koban/pubspec.yaml` (`flutter pub add supabase http google_sign_in`), `koban/android/app/build.gradle.kts`, `koban/android/app/src/main/AndroidManifest.xml`, `koban/android/app/src/main/kotlin/io/github/skooyo/koban/DeviceChannel.kt`, `koban/lib/device/device_control.dart`, `koban/lib/data/koban_settings.dart`, `koban/lib/app/app_services.dart`, `koban/test/support/harness.dart`. (`.gitignore` already ignores the root `.env`.)
- Create: `koban/android/app/src/main/res/xml/backup_rules.xml`, `koban/android/app/src/main/res/xml/data_extraction_rules.xml`, `koban/lib/online/online_config.dart`, `koban/lib/online/secret_store.dart`, `koban/lib/online/online_http.dart`, `koban/lib/online/online_services.dart`
- Test: `koban/android/app/src/test/kotlin/io/github/skooyo/koban/DeviceChannelTest.kt` (add 3 tests), `koban/test/online/secret_store_test.dart`, `koban/test/online/online_http_test.dart`, `koban/test/device/device_control_test.dart` (add 2 tests)

**Interfaces:**
- Consumes: `KobanSettings` (plan 4a Task 3), `DeviceControl` and the `device` channel (plan 4b Task 1), `AppServices`, `testServices` (plan 4a Task 5).
- Produces:
  - Gradle: `fun loadDotEnv(file: File): Map<String, String>` and `escapeBuildConfig` copied from `app/build.gradle.kts`; `buildConfigField` `SUPABASE_URL`, `SUPABASE_KEY` (from `rootProject.file("../../.env")`, key `SUPABASE_KEY`, empty when missing, with `logger.warn("SUPABASE_KEY is missing in .env: groups and receipt reading will not work.")`), `GOOGLE_WEB_CLIENT_ID`.
  - Manifest: `<uses-permission android:name="android.permission.INTERNET" />` in the main manifest (the Flutter template has it only in the debug and profile manifests); `android:fullBackupContent="@xml/backup_rules"` and `android:dataExtractionRules="@xml/data_extraction_rules"` on `<application>`; both files exclude `<exclude domain="sharedpref" path="koban_secrets.xml" />` (cloud backup and device transfer).
  - Channel `io.github.skooyo.koban/device` adds: `onlineConfig` → `Map` with keys `supabaseUrl`, `supabaseKey`, `googleWebClientId` (the `BuildConfig` values); `relativeTime {time: long, now: long}` → `String` = `DateUtils.getRelativeTimeSpanString(time, now, DateUtils.MINUTE_IN_MILLIS).toString()`.
  - `device_control.dart`: `Future<OnlineConfig> onlineConfig()`, `Future<String> relativeTime(int time, int now)`.
  - `online_config.dart`: `class OnlineConfig { const OnlineConfig({required this.supabaseUrl, required this.supabaseKey, required this.googleWebClientId}); final String supabaseUrl, supabaseKey, googleWebClientId; Uri function(String name); /* $supabaseUrl/functions/v1/$name */ static const test = OnlineConfig(supabaseUrl: 'https://test.supabase.co', supabaseKey: 'test-key', googleWebClientId: 'test-client'); }`
  - `secret_store.dart`: `class SecretStore { SecretStore(SharedPreferencesAsync prefs); static SecretStore forPhone(); /* Decision 6 options on Android, plain SharedPreferencesAsync elsewhere */ Future<void> migrate(SharedPreferencesAsync settings); ValueListenable<String> deviceToken; Future<void> setDeviceToken(String token); /* blank removes */ Future<String?> groupSession(); Future<void> setGroupSession(String? json); /* null removes */ Future<void> load(); }` — key names `device_token`, `group_session` (0.1.1). `migrate`: for each key present in `settings`, copy to the store when the store has no value, then remove it from `settings`.
  - `online_http.dart`: `class TimeoutClient extends http.BaseClient { TimeoutClient(http.Client inner, {Duration timeout = const Duration(seconds: 20)}); }` (`send` throws `TimeoutException` when the response headers do not arrive in time); `bool isNoConnection(Object e)` — true for `SocketException`, `http.ClientException`, `TimeoutException`, `AuthRetryableFetchException`.
  - `online_services.dart`: `class OnlineServices { OnlineServices({required OnlineConfig config, required http.Client http, required SecretStore secrets, required KobanSettings settings}); final config, http, secrets, settings; late final SupabaseClient supabase; /* SupabaseClient(config.supabaseUrl, config.supabaseKey, httpClient: TimeoutClient(http), authOptions: const AuthClientOptions(autoRefreshToken: false)) */ bool get allowed; /* settings.onlineFeatures.value */ }`. Tasks 2 to 4 add `receiptCloud`, `session`, `groups`.
  - `KobanSettings.load(SharedPreferencesAsync prefs, {required SecretStore secrets})`: `hasDeviceToken` follows `secrets.deviceToken`; `removeDeviceToken()` calls `secrets.setDeviceToken('')`.
  - `AppServices`: new field `online` (`OnlineServices`); `start` runs `SecretStore.forPhone()`, `secrets.migrate(prefs)` after `openKobanDatabase` (the import may have just written the keys), `secrets.load()`, `device.onlineConfig()`, `http.Client()`.
  - `testServices(..., {http.Client? http, Map<String, Object> secrets = const {}})`: secrets in a second `InMemorySharedPreferencesAsync`; `http` default `MockClient((r) async => fail('unexpected request ${r.method} ${r.url.path}'))`; config `OnlineConfig.test`.

- [ ] **Step 1: Write the failing tests.**

```kotlin
// DeviceChannelTest — FakeMessenger and the direct executor of milestone 3
@Test fun onlineConfigGivesTheThreeBuildValues() {
    val m = messenger.call(DEVICE, "onlineConfig", null) as Map<String, Any?>
    assertEquals(setOf("supabaseUrl", "supabaseKey", "googleWebClientId"), m.keys)
    assertEquals(BuildConfig.SUPABASE_URL, m["supabaseUrl"])
    assertTrue((m["supabaseUrl"] as String).startsWith("https://"))
    assertTrue((m["googleWebClientId"] as String).endsWith(".apps.googleusercontent.com"))
}
@Test fun relativeTimeIsTheAndroidText() {
    val now = 1_762_000_000_000L
    val t = now - 3 * 3_600_000L
    assertEquals(DateUtils.getRelativeTimeSpanString(t, now, DateUtils.MINUTE_IN_MILLIS).toString(),
        messenger.call(DEVICE, "relativeTime", mapOf("time" to t, "now" to now)))
}
@Test fun backupLeavesOutTheSecretsFile() {
    // parse res/xml/backup_rules.xml and data_extraction_rules.xml with context.resources.getXml(...)
    // → every <exclude> has domain "sharedpref" and path "koban_secrets.xml"; cloud-backup and device-transfer each have one
}
```

```dart
// secret_store_test.dart — settings = InMemorySharedPreferencesAsync.withData({...}), store on a second in-memory instance
test('migrate moves the device token and the group session out of the settings', () async {
  // settings: device_token 'test-device-token', group_session '{"refresh_token":"r1","user_id":"user-1"}'
  await store.migrate(settings);
  expect(store.deviceToken.value, 'test-device-token');
  expect(await store.groupSession(), '{"refresh_token":"r1","user_id":"user-1"}');
  expect(await settings.getString('device_token'), isNull);
  expect(await settings.getString('group_session'), isNull);
});
test('migrate keeps a value that the store already has', ...); // store 'new', settings 'old' → 'new'; settings key removed
test('migrate with no keys changes nothing', ...);
test('a blank device token removes the key', ...);
test('the settings see the device token of the store', ...); // KobanSettings.hasDeviceToken true → removeDeviceToken → false and store value ''

// online_http_test.dart
test('a call with no answer in time fails with a timeout', ...); // inner MockClient waits 50 ms; TimeoutClient(timeout: 10 ms) → throwsA(isA<TimeoutException>())
test('connection errors count as no connection, other errors do not', ...);
  // isNoConnection: ClientException true, SocketException true, TimeoutException true, AuthRetryableFetchException() true, FormatException false

// device_control_test.dart
test('online config comes back typed', ...); // map → OnlineConfig with the same 3 values; function('register') == Uri.parse('https://test.supabase.co/functions/v1/register')
test('relative time sends the time and now', ...); // call args {time: 1, now: 2}
```

- [ ] **Step 2: Run.** `flutter test test/online/ test/device/` → FAIL; Gradle test → FAIL.
- [ ] **Step 3: Implement.** Add the packages with `flutter pub add supabase http google_sign_in`; check that `supabase` resolves to 2.16.x and `google_sign_in` to 7.2.x or newer 7.x; record the versions in the task report. Write the Gradle, manifest and XML changes, the channel methods, and the Dart files. Update every `testServices` caller that passes settings (only the harness).
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (11 new tests). Gradle test → BUILD SUCCESSFUL (3 new tests).
- [ ] **Step 5: Commit.** "Add the online settings, the secrets store and the shared HTTP client".

### Task 2: Invite code

**Files:**
- Create: `koban/lib/online/receipt_cloud_client.dart`
- Modify: `koban/lib/online/online_services.dart` (add `receiptCloud`), `koban/lib/screens/settings/settings_view_model.dart`, `koban/lib/screens/settings/settings_screen.dart`
- Test: `koban/test/online/receipt_cloud_client_test.dart`, `koban/test/screens/settings_test.dart` (replace the `Use code` placeholder test)

**Interfaces:**
- Consumes: `OnlineServices` (Task 1), `SecretStore.setDeviceToken`, `SettingsViewModel` (plan 4b Task 5).
- Produces:
  - `sealed class Registration`, `final class RegistrationOk extends Registration { final String deviceToken; }`, `final class RegistrationFailed extends Registration { final String message; }`.
  - `class ReceiptCloudClient { ReceiptCloudClient(OnlineServices online); Future<Registration> register(String inviteCode); static const onlineOff = 'Turn on online features in Settings to read with Claude.'; }` — port of `ReceiptCloudClient.register`: `POST ${config.function('register')}`, header `Content-Type: application/json`, body `{"inviteCode": code.trim().toUpperCase()}`, no `Authorization` and no `apikey` header (as 0.1.1), timeout 90 s. 200 → `deviceToken` of the JSON; 400 `The invite code looks like XXXX-XXXX.`; 429 `Too many tries. Try again in an hour.`; 403 `Invite code not accepted.`; other `Koban's server had a problem. Try again later.`; no connection (`isNoConnection`) `Could not reach Koban's server. Check the internet connection.`. Plan 5b adds `read`.
  - `SettingsViewModel`: `bool get inviteBusy`, `String? get inviteMessage`, `Future<void> enterInviteCode(String code)` — returns at once while busy; stores only the token (`secrets.setDeviceToken`), never the code.
  - `SettingsScreen`: `Use code` calls `enterInviteCode`; the button text is `Checking…` while busy and off while busy or the field is blank; `inviteMessage` shows as the field's error text. The `openOnlinePlaceholder(context, OnlineFeature.inviteCode)` call is deleted.

- [ ] **Step 1: Write the failing tests.**

```dart
// receipt_cloud_client_test.dart — online = OnlineServices(config: OnlineConfig.test, http: mock, ...)
test('a good code gives the device token', () async {
  // mock: expect POST https://test.supabase.co/functions/v1/register, body jsonDecode == {'inviteCode': 'K7QX-M2PA'},
  //       headers['authorization'] == null; reply 200 '{"deviceToken":"test-device-token"}'
  final r = await client.register(' k7qx-m2pa ');
  expect((r as RegistrationOk).deviceToken, 'test-device-token');
});
test('each refusal gives the 0.1.1 message', () async {
  for (final (status, text) in [(400, 'The invite code looks like XXXX-XXXX.'), (429, 'Too many tries. Try again in an hour.'),
      (403, 'Invite code not accepted.'), (500, "Koban's server had a problem. Try again later.")]) { ... }
});
test('no connection says so', ...); // mock throws ClientException → "Could not reach Koban's server. Check the internet connection."
// Review Focus 2
test('with Online features off no request is sent', ...); // prefs online_features false; mock fails on any call → RegistrationFailed(onlineOff)

// settings_test.dart
testWidgets('Use code checks the code and then shows Accepted', ...);
  // http mock 200 → type 'k7qx-m2pa', tap 'Use code' → 'Checking…' (button off) → 'Accepted. Receipts are read by Claude on Koban's server.'; secrets device_token 'test-device-token'
testWidgets('a refused code shows the message under the field', ...); // 403 → 'Invite code not accepted.'
```

- [ ] **Step 2: Run.** `flutter test test/online/receipt_cloud_client_test.dart test/screens/settings_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (6 new tests, 1 replaced).
- [ ] **Step 5: Commit.** "Check the invite code on Koban's server".

### Task 3: Group session and Google sign-in

**Files:**
- Create: `koban/lib/online/google_accounts.dart`, `koban/lib/online/group_session.dart`
- Modify: `koban/lib/online/online_services.dart` (add `session`, `google`)
- Test: `koban/test/support/fake_backend.dart`, `koban/test/fixtures/online/token_response.json`, `koban/test/online/group_session_test.dart`

**Interfaces:**
- Consumes: `OnlineServices`, `SecretStore.groupSession` / `setGroupSession`, `isNoConnection` (Task 1).
- Produces:
  - `google_accounts.dart`: `class GoogleIdentity { final String idToken; final String rawNonce; final String alias; }`; `class GoogleSignInError implements Exception { final String message; }`; `abstract interface class GoogleAccounts { Future<GoogleIdentity?> signIn(); /* null when the person cancels */ }`; `class PhoneGoogleAccounts implements GoogleAccounts { PhoneGoogleAccounts(String serverClientId); }` — at the first call: `rawNonce` = a random version 4 UUID (`newId()`), `GoogleSignIn.instance.initialize(serverClientId:, nonce: sha256Hex(rawNonce))`; then `authenticate()`. `GoogleSignInExceptionCode.canceled` → null; other codes → `GoogleSignInError('Google sign-in failed. Add a Google account to this phone and try again.')`; a null `idToken` → `GoogleSignInError('Google sign-in did not return an account.')`. `String aliasOf(String idToken, String? displayName)` — `given_name` of the JWT payload (base64url, no signature check), else `displayName`, else `Friend`.
  - `group_session.dart`: `enum RestoreResult { none, restored, refused, noConnection }`; `class GroupSession { GroupSession(OnlineServices online); String? get userId; /* the live session's user id, else the user_id of the stored JSON */ bool get hasStoredSession; Future<RestoreResult> restore(); Future<String> signInWithIdToken(GoogleIdentity g); Future<void> signOut(); /* local only */ void dispose(); }`.
  - `restore` rules: Online off or nothing stored → `none` (no request); a live, not expired `currentSession` → `restored` (no request); else `auth.setSession(storedRefreshToken)`: success → `restored`; `AuthException` with a 4xx `statusCode` → `setGroupSession(null)`, `refused`; `isNoConnection` → `noConnection`, the stored JSON stays.
  - Persistence: `GroupSession` listens to `supabase.auth.onAuthStateChange`; on `signedIn` and `tokenRefreshed` it writes `{"access_token", "refresh_token", "expires_at" (seconds), "user_id"}`; on `signedOut` it removes `group_session`. The listener has an `onError` handler that ignores the error: GoTrue puts a failed refresh on this stream (`notifyException`), and without a handler the error is unhandled. GoTrue itself sends `signedOut` after a refused refresh token, so the refused path removes the stored session once through the listener and once in `restore`.
  - Fact from the `supabase-v2.16.5` source: `_refreshAccessToken` tries again after `AuthRetryableFetchException` with a back-off of 200, 400, 800 ms and more, up to the next auto-refresh tick. So the no-connection test can take some seconds; give it `timeout: const Timeout(Duration(seconds: 30))` and count only that at least one request was sent.
  - `signInWithIdToken`: `auth.signInWithIdToken(provider: OAuthProvider.google, idToken: g.idToken, nonce: g.rawNonce)` → user id.
  - `test/support/fake_backend.dart`: `class FakeBackend { FakeBackend(); late final MockClient client; final List<http.Request> requests; void on(String method, String path, http.Response Function(http.Request r) reply); /* path without query; a call with no route fails the test */ }` and `String fakeJwt({required String sub, required int exp, String? givenName})` (an unsigned 3-part JWT for tests only).
  - `token_response.json`: a synthetic GoTrue token reply (`access_token` = placeholder replaced by `fakeJwt` in the helper, `token_type` `bearer`, `expires_in` 3600, `expires_at`, `refresh_token` `r2`, `user` with `id` `user-1`, `aud` `authenticated`, `created_at`, empty `app_metadata` and `user_metadata`).

- [ ] **Step 1: Write the failing tests.** `now` = `T` = `DateTime.utc(2026, 11, 13, 4)`; stored 0.1.1 JSON `S = {"access_token":"old","refresh_token":"r1","expires_at":1762000000,"user_id":"user-1"}` (expired).

```dart
// Review Focus 1
test('a stored 0.1.1 session with an old access token comes back after one refresh', () async {
  // backend.on('POST', '/auth/v1/token', → token_response with refresh_token r2); secrets group_session = S
  expect(await session.restore(), RestoreResult.restored);
  expect(backend.requests.single.url.queryParameters['grant_type'], 'refresh_token');
  expect(jsonDecode(backend.requests.single.body), {'refresh_token': 'r1'});
  expect(session.userId, 'user-1');
  final stored = jsonDecode((await secrets.groupSession())!);
  expect((stored['refresh_token'], stored['user_id']), ('r2', 'user-1'));
});
test('a refused refresh token removes the session and keeps the device token', () async {
  // reply 400 '{"code":"refresh_token_not_found","msg":"Invalid Refresh Token: Refresh Token Not Found"}'
  expect(await session.restore(), RestoreResult.refused);
  expect(await secrets.groupSession(), isNull);
  expect(secrets.deviceToken.value, 'test-device-token');
  expect(session.userId, isNull);
});
test('no connection keeps the stored session for the next try', () async {
  // the route throws http.ClientException('no connection')
  expect(await session.restore(), RestoreResult.noConnection);
  expect(await secrets.groupSession(), S);
  expect(session.userId, 'user-1');
});
// Review Focus 2
test('with Online features off restore sends nothing', ...); // backend has no routes → RestoreResult.none
test('nothing stored sends nothing', ...);
test('Google sign-in sends the raw nonce and stores the new session', () async {
  // backend.on('POST', '/auth/v1/token', ...) ; signInWithIdToken(GoogleIdentity('id-token', 'nonce-1', 'Ali'))
  expect(backend.requests.single.url.queryParameters['grant_type'], 'id_token');
  expect(jsonDecode(backend.requests.single.body), containsPair('nonce', 'nonce-1'));
  expect(jsonDecode(backend.requests.single.body), containsPair('provider', 'google'));
  expect(jsonDecode((await secrets.groupSession())!)['refresh_token'], 'r2');
});
test('sign out removes the stored session', ...);
test('the alias is the given name of the token, else the display name, else Friend', () {
  expect(aliasOf(fakeJwt(sub: 'u', exp: 1, givenName: 'Ali'), 'Ali Bin Abu'), 'Ali');
  expect(aliasOf(fakeJwt(sub: 'u', exp: 1), 'Ali Bin Abu'), 'Ali Bin Abu');
  expect(aliasOf(fakeJwt(sub: 'u', exp: 1), null), 'Friend');
});
```

- [ ] **Step 2: Run.** `flutter test test/online/group_session_test.dart` → FAIL.
- [ ] **Step 3: Implement.** If `signOut()` of `GoTrueClient` sends a request, call it with `scope: SignOutScope.local` (0.1.1 only removed the local session).
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (8 new tests).
- [ ] **Step 5: Commit.** "Restore the group session from 0.1.1 and sign in with Google".

### Task 4: Group repository and the shared totals

**Files:**
- Create: `koban/lib/online/group_repository.dart`, `koban/lib/data/group_queries.drift`
- Modify: `koban/lib/data/database.dart` (add `'group_queries.drift'` to `include`), `koban/lib/data/database.g.dart` (generated), `koban/lib/rules/periods.dart` (add 2 functions), `koban/lib/online/online_services.dart` (add `groups`)
- Test: `koban/test/online/group_repository_test.dart`, `koban/test/rules/periods_test.dart` (add 1 test), `koban/test/fixtures/online/groups_select.json`, `koban/test/fixtures/online/group_members_select.json`

**Interfaces:**
- Consumes: `GroupSession`, `GoogleAccounts` (Task 3), `OnlineServices`, `isNoConnection` (Task 1), `GroupPeriodMath.start`, `Period` (milestone 1), `KobanDatabase`, `MoneyConverter`, `watchTables` (plan 4a).
- Produces:
  - `periods.dart`: `static DateTime malaysiaDay(DateTime instant)` (the date in UTC+8 as a UTC midnight) and `static int malaysiaDayStartMs(DateTime day)` (`day` 00:00 in UTC+8, as epoch ms), both on `GroupPeriodMath`.
  - `group_queries.drift`: `groupTotals(:start AS INT, :end AS INT, :currency AS TEXT, :uncategorized AS TEXT)` — the Room SQL of `ExpenseDao.groupTotals` with `CAST(SUM(COALESCE(e.countedAmount, e.amount)) AS TEXT) AS total` mapped by `MoneyConverter`, and `HAVING SUM(COALESCE(e.countedAmount, e.amount)) > 0`.
  - `group_repository.dart`: the 0.1.1 types `GroupSummary(id, name, code, ownerId, members, requests)`, `JoinRequest(groupId, userId, alias)`, `Member(userId, alias, joinedAt, updatedAt, categories /* List<(String, Decimal)>, largest first */)` with `Decimal get total`, `GroupDetail(group, members, requests)`, `GroupsState(online = true, userId, alias = '', groups = const [], requests = const [], removedFrom = const [] /* List<(int, String)> */, loading = false, message)` with `copyWith`.
  - `class GroupRepository { GroupRepository({required OnlineServices online, required GroupSession session, required GoogleAccounts google, required KobanDatabase db, required DateTime Function() now, Duration syncDelay = const Duration(seconds: 5)}); ValueListenable<GroupsState> get state; ValueListenable<bool> get inGroups; void start(); Future<String?> signIn(); Future<void> signOut(); Future<String?> deleteAccount(); Future<void> refresh(); Future<GroupDetail?> loadGroup(String groupId, Period period, String currency); Future<String?> makeGroup(String name); Future<String?> askToJoin(String code); Future<String?> answer(JoinRequest r, bool approve); Future<String?> leave(String groupId); Future<String?> remove(String groupId, String userId); Future<String?> handOver(String groupId, String userId); Future<String?> rename(String groupId, String name); Future<String?> newCode(String groupId); Future<String?> setAlias(String alias); Future<void> dismissRemoved(int id); Future<void> syncTotals(); void dispose(); }` — a line-for-line port of `GroupRepository.kt`. Each action returns the 0.1.1 message or null, through the `act` rule (Online off → `Turn on online features first.`; then refresh and sync; errors → `errorText`).
  - Rules that change from Kotlin: `start()` listens to `settings.onlineFeatures` (on: `session.restore()`, then `refresh`, then `syncTotals`) and to `db.tableUpdates(TableUpdateQuery.onTable(db.expenses))` (sync after `syncDelay` of quiet, a `Timer` reset on each update; ponytail comment from Kotlin kept). The timer starts only while `session.userId` is not null and Online features are on, and `dispose()` cancels it and both listeners, so widget tests that save payments while signed out leave no pending timer. A `refused` restore puts `message: 'Sign in again.'` in the state (Decision 3). `refresh()` calls `session.restore()` first when no live session exists. `signIn()` uses `google.signIn()` (null → return null), `session.signInWithIdToken`, then `link_account` with `secrets.deviceToken.value` and the alias; any status but `ok` → `session.signOut()` and `Groups need online access. Enter your invite code in Settings first.`; `GoogleSignInError` → its message; `AuthException` → `signOut`, then `isNoConnection` → `Could not reach Koban's server. Check the internet connection.`, else `Sign-in failed. Try again.`.
  - `errorText(Object e)`: `isNoConnection` → `Could not reach Koban's server. Check the internet connection.`; signed out (`AuthException` with 4xx status, `PostgrestException` with `code` in `{'PGRST301', 'PGRST302', 'PGRST303', '401'}`, `FunctionException` status 401) → `Sign in again.` and the session is removed; else `Koban's server had a problem. Try again later.`
  - Reads, as Kotlin: `profiles?user_id=eq.$uid&select=alias`; `join_requests?select=group_id,user_id,profiles(alias)` (own rows left out); `groups?select=id,name,code,owner_id,group_members(user_id)&order=created_at`; `removed_notices?select=id,group_name`; `loadGroup`: `group_members?group_id=eq.$id&select=user_id,joined_at,profiles(alias,totals_updated_at)` and `shared_totals?user_id=in.($ids)&currency=eq.$c&period=eq.${period.key}&period_start=eq.$start&select=user_id,category,amount`, members sorted by total, largest first; `period_start` from `GroupPeriodMath.malaysiaDay(now())` as `yyyy-MM-dd`.
  - `syncTotals`: earliest `joined_at` of `group_members?user_id=eq.$uid&select=joined_at` (none → return); for currency `MYR` then `IDR`, for `week` then `month`, from the period of that day to today (Malaysia days): rows `{user_id, currency, period, period_start, category (first 40 characters), amount (2 decimals, HALF_UP)}`; then `DELETE shared_totals?user_id=eq.$uid`, `POST shared_totals` (only when rows exist), `PATCH profiles?user_id=eq.$uid` `{totals_updated_at: now().toUtc().toIso8601String()}`. Errors are ignored, as Kotlin.
  - `deleteAccount`: `supabase.functions.invoke('delete-account', body: {})`, then `session.signOut()`; through `act`.
  - `inGroups` is true when `state.groups` is not empty (0.1.1 `PaymentViewModel.inGroups`).

- [ ] **Step 1: Write the failing tests.** `FakeBackend`; a signed-in session made with the token route; `db` in memory; `now` = `DateTime.utc(2026, 11, 13, 4)` (Fri 13 Nov 2026 12:00 in Malaysia); helpers insert expenses through the typed API.

```dart
test('refresh reads the alias, the groups, the requests and the removed notices', () async {
  // routes return groups_select.json (2 groups, one with 3 members, owner user-1), a join request from user-2 for group g1,
  // a join request row of user-1 (left out), alias 'Ali', removed notice (7, 'Kedai Group')
  await repo.refresh();
  final s = repo.state.value;
  expect(s.alias, 'Ali');
  expect(s.groups.map((g) => (g.name, g.members, g.requests)), [('Makan Group', 3, 1), ('Trip', 1, 0)]);
  expect(s.removedFrom, [(7, 'Kedai Group')]);
  expect(repo.inGroups.value, true);
});
test('each RPC status word gives the 0.1.1 message', () async {
  // make_group {"status":"too_many_groups"} → 'You are in 5 groups, the most allowed.'; {"status":"bad_name"} → 'Give the group a name of 1 to 40 characters.'
  // ask_to_join "unknown" → 'No group has this code. Check it with the person who sent it.'; "full" → 'This group has 10 members, the most allowed.'
  // answer_request "expired" for alias Mei → 'This request is older than 7 days. Ask Mei to send it again.'
  // rename_group "not_owner" → 'Only the group owner can do this.'; leave_group "use_leave" → 'Use Leave group to leave.'
  // new_group_code '"GRP-7KQ2"' → null; '"not_owner"' → 'Only the group owner can make a new code.'
});
test('an RPC call sends the 0.1.1 parameter names', ...);
  // answer(JoinRequest('g1', 'user-2', 'Mei'), true) → POST /rest/v1/rpc/answer_request body {'p_group': 'g1', 'p_user': 'user-2', 'p_approve': true}
test('sign-in links the device token and refreshes', ...);
  // FakeGoogleAccounts → GoogleIdentity('id-token', 'nonce-1', 'Ali'); link_account body {'p_device_token': 'test-device-token', 'p_alias': 'Ali'}; reply '"ok"' → null; state.userId 'user-1'
test('sign-in without an accepted invite signs out again', ...);
  // link_account '"no_invite"' → 'Groups need online access. Enter your invite code in Settings first.'; secrets group_session null
test('a cancelled Google sign-in sends nothing and shows nothing', ...);
test('an expired session on a read says Sign in again and signs out', ...); // groups route 401 {"code":"PGRST301","message":"JWT expired"}
test('delete account calls the function and signs out', ...); // POST /functions/v1/delete-account with header authorization 'Bearer <access token>' → 204; group_session null; state userId null
// Review Focus 3
test('shared totals leave out money in, dismissed and private payments and are exact to the cent', () async {
  // user-1 joined 2026-11-10T01:00:00+00:00; expenses (MYR, food): 0.10 and 0.20 on Wed 11 Nov; RECEIVE 50.00; DISMISSED 9.00; privateToGroups 7.00;
  // one IDR 25000.00 (transport) on 11 Nov
  await repo.syncTotals();
  final rows = jsonDecode(insertRequest.body) as List;
  expect(rows, containsAll([
    {'user_id': 'user-1', 'currency': 'MYR', 'period': 'week', 'period_start': '2026-11-09', 'category': 'Food', 'amount': '0.30'},
    {'user_id': 'user-1', 'currency': 'MYR', 'period': 'month', 'period_start': '2026-11-01', 'category': 'Food', 'amount': '0.30'},
    {'user_id': 'user-1', 'currency': 'IDR', 'period': 'week', 'period_start': '2026-11-09', 'category': 'Transport', 'amount': '25000.00'},
  ]));
  expect(rows.length, 4);
  expect(backend.requests.map((r) => '${r.method} ${r.url.path}'),
      containsAllInOrder(['DELETE /rest/v1/shared_totals', 'POST /rest/v1/shared_totals', 'PATCH /rest/v1/profiles']));
});
// Review Focus 4
test('a payment at Sunday 23:30 Malaysia time counts in that week', ...);
  // joined 2026-11-02; expense at DateTime.utc(2026, 11, 8, 15, 30) (Sun 23:30 MYT) and DateTime.utc(2026, 11, 8, 16) (Mon 00:00 MYT)
  // → week 2026-11-02 has the first amount, week 2026-11-09 has the second
test('a payment with no category goes as Uncategorized', ...);
test('a payment change starts one sync after the quiet time', ...); // syncDelay 20 ms; 3 inserts in a row → one DELETE /rest/v1/shared_totals
test('loadGroup sorts members by total and keeps the requests of that group', ...);
// Review Focus 2
test('with Online features off no method sends a request', () async {
  // backend with no routes; start(), refresh(), syncTotals(), makeGroup('A'), deleteAccount(), signIn(), loadGroup(...)
  expect(backend.requests, isEmpty);
  expect(await repo.makeGroup('A'), 'Turn on online features first.');
});
test('turning Online features on restores the session and refreshes', ...);

// periods_test.dart
test('Malaysia day starts at 16:00 UTC of the day before', () {
  expect(GroupPeriodMath.malaysiaDay(DateTime.utc(2026, 11, 8, 16)), DateTime.utc(2026, 11, 9));
  expect(GroupPeriodMath.malaysiaDayStartMs(DateTime.utc(2026, 11, 9)), DateTime.utc(2026, 11, 8, 16).millisecondsSinceEpoch);
});
```

- [ ] **Step 2: Run.** `flutter test test/online/group_repository_test.dart test/rules/periods_test.dart` → FAIL.
- [ ] **Step 3: Implement.** Generate: `dart run build_runner build --delete-conflicting-outputs`. `schema_test.dart` must still pass. Parse `joined_at` and `totals_updated_at` with `DateTime.parse` (PostgREST gives `2026-11-12T05:59:05.867657+00:00`).
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (16 new tests).
- [ ] **Step 5: Commit.** "Port the group reads, actions and shared totals sync".

### Task 5: Groups tab, account menu and Count in group totals

**Files:**
- Create: `koban/lib/screens/groups/groups_view_model.dart`, `koban/lib/screens/groups/groups_screen.dart`, `koban/lib/screens/groups/group_dialogs.dart`
- Modify: `koban/lib/app/app_services.dart` (`inGroups` = `online.groups.inGroups`; remove the always-false slot), `koban/lib/app/home_shell.dart` (Groups body = `GroupsScreen`; `initState` calls `services.online.groups.start()` one time), `koban/lib/app/online_placeholder.dart` (remove `OnlineFeature.groups` and `OnlineFeature.inviteCode`)
- Test: `koban/test/screens/groups_screen_test.dart`, `koban/test/screens/payment_screen_test.dart` (add 1 test)

**Interfaces:**
- Consumes: `GroupRepository` (Task 4), `KobanSettings.setOnlineFeatures`, kit (`LargeTopBar`, `ListGroup`, `KobanRow`, `InitialsAvatar`, `DialogTextField`), `pushPage` (plan 4a).
- Produces:
  - `class GroupsViewModel extends ChangeNotifier { GroupsViewModel(AppServices s, {String? groupId}); GroupsState get state; bool get busy; String? get message; Period get period; GroupDetail? get detail; bool get groupExists; DateTime? get loadedAt; Future<void> refresh(); void setPeriod(Period p); Future<void> run(Future<String?> Function(GroupRepository r) action, {bool silent = false, VoidCallback? onOk}); Future<void> setOnline(bool on); void messageShown(); }` — port of `GroupsViewModel.kt`; `run` returns at once while `busy` (Review Focus 5); a `state.message` from the repository (for example `Sign in again.`) goes to `message` one time.
  - `group_dialogs.dart`: `Future<String?> showNameDialog(BuildContext context, {required String title, required String label, required String start, required String confirm, required int max})` and `Future<bool> showConfirmDialog(BuildContext context, {required String title, required String body, required String confirm})` — ports of `NameDialog` and `ConfirmDialog` with `Cancel`.
  - `GroupsScreen` — `GroupsScreen.kt` `GroupsScreen`: `LargeTopBar('Groups')` with the `Account` menu (`Change your name`, `Sign out`, `Delete account`) only when signed in; states in order: online off (`Online features are off`, the 0.1.1 body, `Turn on online features`), signed out (`Compare spending with friends`, the 3 lines, `Sign in with Google` / `Signing in…`, `Groups use the invite code you entered in Settings.`), signed in (`RefreshIndicator` → `refresh`; the removed notices `The owner removed you from $name.` with `OK`; the empty line; the group rows `$n member(s)` + ` · you are the owner`, the requests pill `$n request(s)`, tap label `Open group`; `Make a group`, `Join a group`, `You can be in up to 5 groups. Each group has up to 10 members.`). Dialogs: make (`Make a group`, `Group name`, `Make group`, 40), join (`Join a group`, `Group code, for example GRP-7KQ2`, `Ask to join`, 8; on ok the snackbar `Request sent. You join when the group owner approves it.`), alias (`Your name in groups`, `Name`, `Save`, 30), delete (`Delete your account?`, the 0.1.1 body, `Delete account`). Messages show in a `SnackBar`. A group row opens the group page (Task 6; until then a no-op).

- [ ] **Step 1: Write the failing tests.** `testServices(http: backend.client, secrets: {...})`; `FakeGoogleAccounts` in `AppServices.online` through the harness.

```dart
testWidgets('with Online features off the tab offers to turn them on', ...);
  // prefs online_features false, a stored session → 'Online features are off' and 0 requests; tap 'Turn on online features' → prefs true; backend gets the refresh call
testWidgets('signed out the tab offers Google sign-in', ...); // no stored session → 'Compare spending with friends', 'Sign in with Google'
// Review Focus 1, on screen
testWidgets('a refused 0.1.1 session shows the sign-in page and Sign in again', ...);
// Review Focus 5
testWidgets('two fast taps on Sign in with Google start one sign-in', ...); // FakeGoogleAccounts.calls == 1; text 'Signing in…' between
testWidgets('the group list shows members, owner and requests', ...); // '3 members · you are the owner', '1 request'
testWidgets('Make a group sends the name and refreshes', ...);
testWidgets('Join a group shows Request sent after an ok answer', ...);
testWidgets('a removed notice goes away after OK', ...); // DELETE /rest/v1/removed_notices?id=eq.7
testWidgets('Delete account asks first and then shows the sign-in page', ...);
testWidgets('Groups meets the tap target guidelines and works at text scale 1.3', ...);

// payment_screen_test.dart
testWidgets('Count in group totals shows for a spend when the person is in a group', ...);
  // groups state with one group → 'Count in group totals', 'Group members see this in your totals'; tap → 'Group members do not see this payment'; saved privateToGroups 1
```

- [ ] **Step 2: Run.** `flutter test test/screens/groups_screen_test.dart test/screens/payment_screen_test.dart` → FAIL.
- [ ] **Step 3: Implement.** If plan 4a did not build the `Count in group totals` row, build it now from `PaymentScreen.kt` lines 279 to 287 (`Count in group totals`, the 2 subtitles, a switch on `!privateToGroups`, only for `Spent`).
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (11 new tests).
- [ ] **Step 5: Commit.** "Add the Groups tab, the account menu and Count in group totals".

### Task 6: Group page

**Files:**
- Create: `koban/lib/screens/groups/group_screen.dart`
- Modify: `koban/lib/app/routes.dart` (`openGroup`), `koban/lib/screens/groups/groups_screen.dart` (row tap → `openGroup`), `koban/test/app/parity_test.dart` (route `groups/{groupId}` → `openGroup`, title the group name)
- Test: `koban/test/screens/group_screen_test.dart`

**Interfaces:**
- Consumes: `GroupsViewModel(s, groupId:)` (Task 5), `GroupRepository.loadGroup` and actions (Task 4), `DeviceControl.shareText` (plan 4b, Task 1), `relativeTime` (Task 1 of this plan), `SegmentedControl`, `MoneyText`, `CategoryDot`, `categoryColor`, `MoneyColors.goldText`, `TonalButton`, `rm` (plan 4a).
- Produces:
  - `routes.dart`: `Future<void> openGroup(BuildContext context, String groupId)`.
  - `GroupScreen(groupId)` — `GroupsScreen.kt` `GroupScreen` and `GroupBody`: title the group name (`Group` while loading), Back, `Group actions` menu (`Rename group`, `Make a new code` for the owner; `Leave group`); the page pops when `groupExists` is false; `Week` / `Month` segments (`month` first selected, as 0.1.1); `Updated just now. Pull down to refresh.` or `Updated <relativeTime>. Pull down to refresh.`; my card (`You spent in <full month name>` or `You spent this week`, the total, `<ordinal> of <n> in <group>. Resets in <d> day(s).`); join requests for the owner (`Join requests`, the 0.1.1 note, `Decline`, `Approve`); `Members` with the `How to read this list` / `Hide how to read this list` button and its text; member rows (`<alias> (you)` in gold text for me, the total, the category bar with `max(0.02, total / top)` width, the stale line `Updated <relativeTime>` or `No totals sent yet` when older than 24 h or never, expanded categories or `No spending in this period.`, my note, `Make owner` and `Remove` (error color) for the owner on others; tap labels `Show categories` / `Hide categories`, state `Expanded` / `Collapsed`); the code card (`Group code`, the code, `Share code` → `shareText('Join my Koban group "<name>" with the code <code>.', chooserTitle: 'Share group code')`). Dialogs: rename (`Rename group`, `Group name`, `Save`, 40), new code (`Make a new code?`, `The old code stops working. Members stay in the group.`, `Make new code`), leave (`Leave <name>?`, the 0.1.1 body, `Leave group`), remove (`Remove <alias>?`, the 0.1.1 body, `Remove`), hand over (`Make <alias> the owner?`, the 0.1.1 body, `Make owner`). Category colors: `categoryColor` of the built-in category whose name matches (case ignored), else `other` (0.1.1 `categoryColor(name)`). `ordinal(n)`: 1st, 2nd, 3rd, 4th, 11th, 12th, 13th, 21st, 22nd, 101st, 111th.

- [ ] **Step 1: Write the failing tests.** Group `Makan Group`, me `user-1` (owner, Ali, RM 30.00), `user-2` Mei RM 45.50 updated 2 days ago, `user-3` Abu with no totals; `now` Fri 13 Nov 2026; device channel `relativeTime` answers `'2 days ago'`.

```dart
testWidgets('my card shows my total, my place and the days left', ...);
  // 'You spent in November', 'RM 30.00', '2nd of 3 in Makan Group. Resets in 18 days.'
testWidgets('the week view resets on Monday', ...); // tap 'Week' → 'You spent this week', 'Resets in 3 days.'; shared_totals query has period=eq.week&period_start=eq.2026-11-09
testWidgets('members are listed by total with stale and missing totals marked', ...);
  // order Mei, Ali (you), Abu; 'Updated 2 days ago' under Mei; 'No totals sent yet' under Abu
testWidgets('a member row opens its categories and the owner can remove the member', ...);
testWidgets('Share code sends the 0.1.1 text', ...); // device shareText {text: 'Join my Koban group "Makan Group" with the code GRP-7KQ2.', chooserTitle: 'Share group code'}
testWidgets('Approve answers the request and reloads', ...);
testWidgets('leaving the group closes the page', ...); // leave_group '"ok"' → groups list without g1 → page popped
test('ordinal suffixes follow English', ...);
testWidgets('the group page meets the tap target guidelines and works at text scale 1.3', ...);
```

- [ ] **Step 2: Run.** `flutter test test/screens/group_screen_test.dart test/app/parity_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, one at a time.** `flutter analyze`; `flutter test` → PASS (9 new tests). Gradle test → BUILD SUCCESSFUL. `flutter build apk --debug` → `koban/build/app/outputs/flutter-apk/app-debug.apk` exists (with a root `.env` present, the Gradle output has no `SUPABASE_KEY is missing` warning). Do not install it.
- [ ] **Step 5: Check.** `grep -rn "OnlineFeature\." koban/lib` → only `updates` (Settings) and `receiptReading` (split editor, 2 uses). `git diff --stat main -- app/ gradle/ supabase/` → empty. `git grep -n "eyJ\|sb_publishable_" -- koban/` → nothing (no literal token or key; `fakeJwt` builds its tokens at run time).
- [ ] **Step 6: Commit.** "Add the group page".

## Known limits

- One Google nonce per app run (Decision 4).
- Each app start with Online features on and a stored session spends one refresh call (Decision 2). 0.1.1 refreshed only near expiry.
- Shared totals sync only while the app process lives, as in 0.1.1 (the capture engine does not sync).
- The relative time texts come from Android; milestone 7 needs an iPhone text for `relativeTime` and an iPhone source for `onlineConfig`.
- Real Google sign-in, the real restore and delete account first run in the owner device checks at the end of plan 5c.
