# Flutter milestone 5c: updater and milestone check — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the 0.1.1 self-updater: a daily and a manual check of the latest GitHub release (asset `koban-<versionCode>.apk`, versionCode check, only with Online features on), the download, the native package installer session with `com.expensetracker.app.update.UpdateInstallReceiver`, the "Update available" dialog and the Settings row; then close milestone 5 (no placeholder left) with the owner device checks for 5a, 5b and 5c.

**Architecture:** The rules and the state machine are Dart: `ReleaseParser`, `UpdateSchedule` and `UpdateRepository` port `update/*.kt` one to one and download the APK with the shared `http.Client` into the app cache. The install step stays native (spec 6.6: no plugin installs through a `PackageInstaller` session with a status receiver of a fixed class name): a new channel `io.github.skooyo.koban/update` checks the APK (`ApkCheck`, ported in Kotlin), writes it into a session and commits it with a `PendingIntent` to `UpdateInstallReceiver`, which sends the status back to the Dart side that started the install.

**Tech Stack:** Flutter 3.50.0 / Dart 3.14.0; plans 5a and 5b. Android `PackageInstaller` (platform). No new pub package and no new Kotlin library.

**Spec:** `docs/superpowers/specs/2026-11-13-flutter-migration-design.md` (6.6 "Updates", 6.3 component names, 6.7 item 5). Release rules: `docs/RELEASING.md` (sections 1, 3 steps 7 and 9, 4, 8). Reference: `app/.../update/` (`UpdateRepository.kt`, `ReleaseParser.kt`, `UpdateSchedule.kt`, `ApkCheck.kt`, `UpdateInstallReceiver.kt`), `ui/components/UpdateDialog.kt`, `ui/viewmodel/AppViewModel.kt` (start check), `ui/screens/SettingsScreen.kt` (About row), Kotlin tests `update/ReleaseParserTest.kt`, `UpdateScheduleTest.kt`, `ApkCheckTest.kt`.

**Order:** plan 3 of 3. Start on branch `feature/flutter-m5c` from `main` after plan 5b is merged. Milestone 6 (the switch release) comes next.

**Decisions (the spec leaves these to the builder):**
1. **Native install, Dart everything else.** Rejected: `open_filex` and similar plugins (they open the APK with `ACTION_VIEW`; no session, no status, and no fixed receiver name), `ota_update` (does the download natively too and owns the state machine, so the rules would live in a plugin). The native part is about 120 lines of Kotlin ported from `UpdateRepository.install` and `UpdateInstallReceiver`.
2. **Status back to Dart:** `UpdateInstaller` (a Kotlin `object`) keeps the status handler of the plugin instance that called `install`. Both engines (UI and capture) add `KobanNativePlugin`, so a global handler could go to the capture engine.
3. **The expected package is `context.packageName`** (0.1.1 used `BuildConfig.APPLICATION_ID`, the same value). A debug build therefore refuses a release APK; the owner device check uses that (check 6).
4. **The dialog opens with `showDialog` from `HomeShell`** (root navigator), one dialog per episode; its content follows the state, and it closes itself on `Idle` or `UpToDate`. So it shows over any page, as the 0.1.1 dialog in the app root did.

**Not in this plan:** the iPhone (`Check for updates` is hidden on iPhone, milestone 7). Release signing, `versionCode` 3 and the release steps of the Flutter build (milestone 6).

## Global Constraints

- `flutter` means `D:/flutter/bin/flutter`, `dart` means `D:/flutter/bin/dart`; run them from `koban/`. Gradle: `cd koban/android && JAVA_HOME=D:/jdk-17 ./gradlew.bat --max-workers=2 :app:testDebugUnitTest`.
- Commit steps: the controller runs them. The implementer stops after the last verification step and reports the changed files.
- Run at most one Gradle or Flutter build or test run at a time.
- Each task ends with `flutter analyze` → "No issues found!" and `flutter test` → "All tests passed!"; when Kotlin changed, also the Gradle command → BUILD SUCCESSFUL.
- `git diff main -- app/ gradle/ supabase/` stays empty.
- No test calls GitHub. Dart tests use `MockClient`; Kotlin tests use Robolectric.
- Updater rules, verbatim from 0.1.1: the URL is `RELEASES_URL` of `UpdateRepository.kt`; the check sends only the headers `Accept: application/vnd.github+json` and `User-Agent: Koban-Android`; the asset name matches `^koban-(\d+)\.apk$` and the highest number wins; an update exists only when that number is above the app's `versionCode`; `versionName` is `tag_name` without a leading `v`; notes are the first 500 characters of `body` (null → empty); automatic checks run at most once per 86 400 000 ms and also when the clock went back; any HTTP answer sets `last_update_check`; the download sends only `User-Agent: Koban-Android`; the file is `<cache>/updates/koban-<versionCode>.apk`, the folder is emptied first, the file is deleted after the install call; the APK must have the app's package name and exactly the expected `versionCode`.
- The `online_features` setting gates the check and the download, as in 0.1.1.
- Component name, byte for byte: `com.expensetracker.app.update.UpdateInstallReceiver` (not exported). The manifest writes it in full.
- UI text is copied byte for byte from `UpdateDialog.kt`, `UpdateRepository.kt` and `SettingsScreen.kt`.
- Doc comments and test names in ASD-STE100 Simplified Technical English.

## Review Focus

1. Two fast taps on `Update` start one download. Pinned in Task 3.
2. A download that stops early (fewer bytes than `Content-Length`) must give `Update failed. Try again later.` and never reach the installer. Pinned in Task 3.
3. Without "Install unknown apps", `Update` opens that settings page, sets `last_update_check` to 0 (so the next start checks again if Android closed Koban), and shows `Allow Koban to install apps, then tap Update again.`; `OK` goes back to the update. Pinned in Task 3.
4. An APK of another app, or of another `versionCode`, is never written into a session. Pinned in Task 2.
5. GitHub answers 403 (rate limit): the automatic check is silent and waits a day; the manual check shows `Could not check for updates. Try again later.`. With Online features off nothing is sent. Pinned in Task 3.

---

### Task 1: Release rules in Dart and the APK check in Kotlin

**Files:**
- Create: `koban/lib/update/release_parser.dart`, `koban/lib/update/update_schedule.dart`, `koban/android/app/src/main/kotlin/com/expensetracker/app/update/ApkCheck.kt` (copied without change)
- Test: `koban/test/update/release_parser_test.dart`, `koban/test/update/update_schedule_test.dart`, `koban/android/app/src/test/kotlin/com/expensetracker/app/update/ApkCheckTest.kt` (copied without change)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class AvailableUpdate { const AvailableUpdate({required this.versionCode, required this.versionName, required this.apkUrl, required this.apkSize, required this.notes}); final int versionCode; final String versionName; final String apkUrl; final int apkSize; final String notes; }` with value equality.
  - `abstract final class ReleaseParser { static AvailableUpdate? parseLatest(String json, int currentVersionCode); }` — any parse error → null.
  - `abstract final class UpdateSchedule { static const checkIntervalMs = 86400000; static bool shouldCheck({required bool online, required int lastCheckMs, required int nowMs, required bool manual}); }`
  - Kotlin `object ApkCheck { fun matches(archivePackage: String?, archiveVersionCode: Long?, expectedPackage: String, expectedVersionCode: Int): Boolean }`.

- [ ] **Step 1: Write the failing tests.** Port `ReleaseParserTest.kt` (6 cases) and `UpdateScheduleTest.kt` (5 cases) one to one, same values; copy `ApkCheckTest.kt` (4 cases).

```dart
// release_parser_test.dart — release(tag, assets, {body = 'Fixes'}) builds the JSON as the Kotlin helper (size 65000000, url https://example.test/<name>)
test('a newer APK gives the update', () => expect(ReleaseParser.parseLatest(release('v0.7.0', ['koban-7.apk']), 6),
    const AvailableUpdate(versionCode: 7, versionName: '0.7.0', apkUrl: 'https://example.test/koban-7.apk', apkSize: 65000000, notes: 'Fixes')));
test('the same version gives nothing', ...);
test('a release with no APK asset gives nothing', ...);
test('bad JSON gives nothing', ...); // '{not json'
test('of two APKs the highest number wins', ...); // ['koban-7.apk', 'koban-8.apk'] → 8
test('a null body gives empty notes', ...);

// update_schedule_test.dart
test('with Online features off it never checks', () => expect(UpdateSchedule.shouldCheck(online: false, lastCheckMs: 0, nowMs: 100000000, manual: true), false));
// + 'a manual check runs at once', 'an automatic check waits one day' (86399999 → false), 'an automatic check runs after one day' (86400000 → true), 'a clock set back checks'
```

- [ ] **Step 2: Run.** `flutter test test/update/` → FAIL; Gradle test → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (11 new tests). Gradle test → BUILD SUCCESSFUL (4 new tests).
- [ ] **Step 5: Commit.** "Port the release rules and the APK check".

### Task 2: Native installer, the update channel and UpdateInstallReceiver

**Files:**
- Create: `koban/android/app/src/main/kotlin/com/expensetracker/app/update/UpdateInstaller.kt`, `koban/android/app/src/main/kotlin/com/expensetracker/app/update/UpdateInstallReceiver.kt`, `koban/android/app/src/main/kotlin/io/github/skooyo/koban/UpdateChannel.kt`, `koban/lib/update/update_installer.dart`
- Modify: `koban/android/app/src/main/kotlin/io/github/skooyo/koban/KobanNativePlugin.kt` (register the channel), `koban/android/app/src/main/AndroidManifest.xml` (`REQUEST_INSTALL_PACKAGES`; the receiver), `koban/android/app/src/test/kotlin/io/github/skooyo/koban/KobanNativePluginTest.kt` (5 channel names), `koban/android/app/src/test/kotlin/com/expensetracker/app/listener/ComponentNamesTest.kt` (add the receiver)
- Test: `koban/android/app/src/test/kotlin/com/expensetracker/app/update/UpdateInstallReceiverTest.kt`, `koban/android/app/src/test/kotlin/io/github/skooyo/koban/UpdateChannelTest.kt`, `koban/test/update/update_installer_test.dart`

**Interfaces:**
- Consumes: `ApkCheck` (Task 1); `KobanNativePlugin.register(context, messenger)` and its executor (milestone 3 Task 3).
- Produces:
  - `object UpdateInstaller { @Volatile var onStatus: ((Int, String?) -> Unit)?; fun isExpectedApk(context: Context, file: File, versionCode: Int): Boolean; fun install(context: Context, file: File) }` — port of `UpdateRepository.isExpectedApk` (expected package `context.packageName`, Decision 3) and `install` (session `MODE_FULL_INSTALL`; `USER_ACTION_NOT_REQUIRED` from Android 12; `openWrite("koban.apk", 0, length)`, `fsync`; `PendingIntent.getBroadcast(context, sessionId, Intent(context, UpdateInstallReceiver::class.java), FLAG_UPDATE_CURRENT or FLAG_MUTABLE from Android 12)`; `abandonSession` on any error, then rethrow).
  - `class UpdateInstallReceiver : BroadcastReceiver()` — port of the 0.1.1 receiver without Hilt: `STATUS_PENDING_USER_ACTION` starts `EXTRA_INTENT` with `FLAG_ACTIVITY_NEW_TASK` (null intent → `onStatus(STATUS_FAILURE, "No confirm intent")` and return); then `UpdateInstaller.onStatus?.invoke(status, EXTRA_STATUS_MESSAGE)`.
  - Channel `io.github.skooyo.koban/update` (Dart → native): `versionCode` → int (`PackageInfo.longVersionCode`); `canInstall` → bool (`canRequestPackageInstalls()`); `openInstallSettings` (`ACTION_MANAGE_UNKNOWN_APP_SOURCES`, `package:<packageName>`, `FLAG_ACTIVITY_NEW_TASK`; `ActivityNotFoundException` ignored); `install {path, versionCode}` → null after `commit` (sets `UpdateInstaller.onStatus` to this channel's sender first); errors `NOT_KOBAN_APK` (check failed, no session made) and `INSTALL` (session error). Native → Dart: `installStatus {status: 'success' | 'pendingUserAction' | 'failure', message}`.
  - `update_installer.dart`: `enum InstallStatus { success, pendingUserAction, failure }`; `class NotKobanApk implements Exception {}`; `abstract interface class UpdateInstaller { Future<int> versionCode(); Future<bool> canInstall(); Future<void> openInstallSettings(); Future<void> install(String path, int versionCode); void onStatus(void Function(InstallStatus status, String? message) handler); }`; `class ChannelUpdateInstaller implements UpdateInstaller`.
  - Manifest: `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />`; `<receiver android:name="com.expensetracker.app.update.UpdateInstallReceiver" android:exported="false" />`.

- [ ] **Step 1: Write the failing tests.**

```kotlin
// UpdateInstallReceiverTest — Robolectric @Config(sdk = [35]); UpdateInstaller.onStatus records (status, message)
@Test fun successGoesToTheHandler() {
    UpdateInstallReceiver().onReceive(context, Intent().putExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_SUCCESS))
    assertEquals(listOf(PackageInstaller.STATUS_SUCCESS to null), seen)
}
@Test fun pendingUserActionOpensTheConfirmScreen() {
    val confirm = Intent("android.content.pm.action.CONFIRM_INSTALL")
    UpdateInstallReceiver().onReceive(context, Intent().putExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_PENDING_USER_ACTION).putExtra(Intent.EXTRA_INTENT, confirm))
    val started = shadowOf(app).nextStartedActivity
    assertEquals("android.content.pm.action.CONFIRM_INSTALL", started.action)
    assertTrue(started.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
    assertEquals(listOf(PackageInstaller.STATUS_PENDING_USER_ACTION to null), seen)
}
@Test fun pendingUserActionWithoutAnIntentFails() { /* seen == [STATUS_FAILURE to "No confirm intent"] */ }

// UpdateChannelTest — FakeMessenger, direct executor
// Review Focus 4
@Test fun aFileThatIsNotTheKobanApkIsRefusedWithoutASession() {
    // write "not an apk" to cacheDir/updates/koban-9.apk
    val error = messenger.callForError(UPDATE, "install", mapOf("path" to f.path, "versionCode" to 9))
    assertEquals("NOT_KOBAN_APK", error.code)
    assertEquals(0, shadowOf(context.packageManager.packageInstaller).allSessions.size)
}
@Test fun canInstallFollowsThePhoneSetting() { /* shadowOf(pm).setCanRequestPackageInstalls(false/true) → false/true */ }
@Test fun openInstallSettingsOpensTheUnknownAppsPage() { /* action Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, data "package:<pkg>" */ }
@Test fun versionCodeIsTheInstalledVersion() { /* == packageInfo.longVersionCode */ }

// ComponentNamesTest
@Test fun updateReceiverKeepsItsName() {
    assertFalse(pm.getReceiverInfo(ComponentName(pkg, "com.expensetracker.app.update.UpdateInstallReceiver"), 0).exported)
}
```

```dart
// update_installer_test.dart — mock io.github.skooyo.koban/update
test('install sends the path and the version code', ...); // {path: '/c/updates/koban-9.apk', versionCode: 9}
test('a refused APK becomes NotKobanApk', ...); // PlatformException code NOT_KOBAN_APK → throwsA(isA<NotKobanApk>())
test('the native status comes back typed', ...); // handleMockMessage installStatus {status: 'pendingUserAction', message: null} → handler(InstallStatus.pendingUserAction, null)
```

- [ ] **Step 2: Run.** Gradle test → FAIL; `flutter test test/update/update_installer_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (3 new tests). Gradle test → BUILD SUCCESSFUL (8 new tests, 1 changed).
- [ ] **Step 5: Commit.** "Install updates through a package installer session".

### Task 3: Update repository

**Files:**
- Create: `koban/lib/update/update_repository.dart`
- Modify: `koban/lib/data/koban_settings.dart` (add `last_update_check`), `koban/lib/app/app_services.dart` (add `updates`), `koban/test/support/harness.dart` (`FakeUpdateInstaller`)
- Test: `koban/test/update/update_repository_test.dart`

**Interfaces:**
- Consumes: Tasks 1 and 2; `OnlineServices.http`, `TimeoutClient` (plan 5a); `AppServices.cacheDir` (plan 5b).
- Produces:
  - `KobanSettings`: `Future<int> lastUpdateCheck()` (key `last_update_check`, default 0), `Future<void> setLastUpdateCheck(int ms)`.
  - `sealed class UpdateState`; `UpdateIdle`, `UpdateUpToDate`, `UpdateAvailable(AvailableUpdate update)`, `UpdateDownloading`, `UpdateInstalling`, `UpdateFailed(String message, {AvailableUpdate? retry})` (value equality).
  - `class UpdateRepository { UpdateRepository({required http.Client http, required KobanSettings settings, required UpdateInstaller installer, required String cacheDir, required DateTime Function() now}); ValueListenable<UpdateState> get state; Future<void> check({required bool manual}); Future<void> downloadAndInstall(); void later(); }` — port of `UpdateRepository.kt`: `check` returns at once while downloading or installing and when `UpdateSchedule.shouldCheck` is false; the check uses `TimeoutClient(http)` (20 s); results: an update → `UpdateAvailable`; none → `UpToDate` (manual) or `Idle`; non-200 or any error → `UpdateFailed('Could not check for updates. Try again later.')` (manual) or `Idle`; the state changes only when not busy. `downloadAndInstall`: only from `UpdateAvailable`; without install permission → `setLastUpdateCheck(0)`, `openInstallSettings()`, `UpdateFailed('Allow Koban to install apps, then tap Update again.', retry: u)`; else set `UpdateDownloading` before the first `await` (Review Focus 1); Online off → `Idle`; download with the plain `http` client (no total timeout; 60 s without data → error); fewer bytes than `contentLength` → error; `UpdateInstalling`; `installer.install(path, u.versionCode)`; the file is deleted in `finally`; any error → `UpdateFailed('Update failed. Try again later.', retry: u)`; a state still `UpdateDownloading` at the end → `Idle`. `later()` and the install status rules: as `UpdateRepository.later` and `onInstallStatus` (`success` → `Idle`, `pendingUserAction` → no change, `failure` → `UpdateFailed('Update failed. Try again later.', retry: the update in progress)`). The constructor registers `installer.onStatus`.
  - `AppServices.updates`: `UpdateRepository(http: online.http, settings:, installer: ChannelUpdateInstaller(), cacheDir:, now:)`; the app's `versionCode` comes from `installer.versionCode()` at the first check.
  - Harness: `testServices` puts `last_update_check` = the test `now` in the prefs unless the test gives the key, and uses `FakeUpdateInstaller`. So the start check of Task 4 sends no request in the widget tests of earlier plans (their default `MockClient` fails on any request).

- [ ] **Step 1: Write the failing tests.** `now` = `T` = 100000000 ms; `FakeUpdateInstaller` (`versionCode` 6, `canInstall` true, records `install(path, code)` and the file size seen at that moment, `emit(InstallStatus, message)`); release JSON as Task 1 with `koban-7.apk`, size 5.

```dart
test('an automatic check finds the update and records the time', () async {
  await repo.check(manual: false);
  expect(repo.state.value, UpdateAvailable(seven));
  expect(await settings.lastUpdateCheck(), T);
  final r = backend.requests.single;
  expect(r.headers.keys.toSet(), {'accept', 'user-agent'});
  expect((r.headers['accept'], r.headers['user-agent']), ('application/vnd.github+json', 'Koban-Android'));
});
test('a manual check with nothing new says up to date', ...); // koban-6.apk → UpdateUpToDate
test('an automatic check the same day sends nothing', ...); // last check T - 1000 → 0 requests
// Review Focus 5
test('a 403 is silent for the automatic check and shown for the manual one', ...);
  // automatic → Idle, last check T; manual → UpdateFailed('Could not check for updates. Try again later.')
test('with Online features off nothing is sent', ...); // manual too → 0 requests, state Idle
test('Update downloads the APK, installs it and deletes the file', () async {
  // GET https://example.test/koban-7.apk → 5 bytes
  await repo.downloadAndInstall();
  expect(installer.installs, [('$cache/updates/koban-7.apk', 7, 5)]);
  expect(File('$cache/updates/koban-7.apk').existsSync(), false);
  expect(repo.state.value, const UpdateInstalling());
  expect(backend.requests.last.headers.keys.toSet(), {'user-agent'});
});
// Review Focus 1
test('two fast taps start one download', ...); // two calls without await → 1 download request, 1 install
// Review Focus 2
test('a download that ends early fails and never installs', ...);
  // MockClient.streaming: contentLength 5, 3 bytes → UpdateFailed('Update failed. Try again later.', retry: seven); installs empty
test('a refused APK fails with the retry', ...); // installer throws NotKobanApk → UpdateFailed(..., retry: seven)
// Review Focus 3
test('without the install permission it opens the settings and asks to try again', () async {
  // canInstall false
  await repo.downloadAndInstall();
  expect(installer.openedSettings, 1);
  expect(await settings.lastUpdateCheck(), 0);
  expect(repo.state.value, UpdateFailed('Allow Koban to install apps, then tap Update again.', retry: seven));
  repo.later();
  expect(repo.state.value, UpdateAvailable(seven));
});
test('Close while installing goes back to the update', ...); // later() on Installing → Available(seven)
test('the install status moves the state', ...); // emit(success) → Idle; emit(failure, 'x') → UpdateFailed(..., retry: seven); emit(pendingUserAction) → no change
```

- [ ] **Step 2: Run.** `flutter test test/update/update_repository_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (12 new tests).
- [ ] **Step 5: Commit.** "Port the update check, download and install state".

### Task 4: Update dialog, Settings row and the milestone check

**Files:**
- Create: `koban/lib/update/update_dialog.dart`
- Modify: `koban/lib/app/home_shell.dart` (start check; dialog), `koban/lib/screens/settings/settings_view_model.dart`, `koban/lib/screens/settings/settings_screen.dart`, `koban/test/rules/PORTED.md` (the updater and screen rules moved)
- Delete: `koban/lib/app/online_placeholder.dart` and every import of it; the placeholder tests of plan 4a Task 5 (`OnlinePlaceholder` only)
- Test: `koban/test/update/update_dialog_test.dart`, `koban/test/screens/settings_test.dart` (replace the `Check for updates` placeholder test)

**Interfaces:**
- Consumes: `UpdateRepository` (Task 3); `HomeShell` (plan 4a Task 5, with the plan 5a `initState`); `SettingsViewModel` (plan 4b Task 5).
- Produces:
  - `update_dialog.dart`: `class UpdateDialogContent extends StatelessWidget { const UpdateDialogContent({required this.state, required this.onUpdate, required this.onDismiss}); }` — the 4 dialogs of `UpdateDialog.kt` (radius 24, `surfaceContainer`): Available (`Update available`, `Koban <versionName> is ready (<n> MB).` with `n = max(1, round(apkSize / 1000000))`, the notes when not blank, `Update`, `Later`, scrollable body); Downloading (`Downloading the update…`, a linear progress bar, no buttons, not dismissible); Installing (`Installing…`, `Close`); Failed (the message, `OK`). `void watchUpdateDialog(BuildContext context, UpdateRepository updates)` — Decision 4: opens one `showDialog` when the state becomes a dialog state; `Later`, `Close`, `OK`, Back and a tap outside call `later()` (Downloading: no dismiss); the dialog pops itself on `UpdateIdle` and `UpdateUpToDate`.
  - `HomeShell.initState`: after the first frame, `watchUpdateDialog(context, s.updates)` and `s.updates.check(manual: false)` (one time per process, next to the plan 5a `groups.start()`).
  - Settings › About: subtitle `Turn on Online features to check for updates.` (off) or `Koban is up to date.` (state `UpdateUpToDate`); `Check for updates` → `updates.check(manual: true)`; the button is off with Online features off.

- [ ] **Step 1: Write the failing tests.**

```dart
// update_dialog_test.dart
testWidgets('Update available shows the version, the size and the notes', ...);
  // apkSize 65000000 → 'Koban 0.7.0 is ready (65 MB).', 'Fixes'; apkSize 400000 → '(1 MB)'
testWidgets('the start check opens the dialog over any page and Later closes it', ...);
  // http mock → koban-7.apk; pumpKoban; open Settings; → 'Update available' shows; tap 'Later' → gone; state Idle
testWidgets('the dialog follows the state to Downloading and to Failed', ...);
  // tap 'Update' with a download that ends early → 'Downloading the update…' → 'Update failed. Try again later.'; 'OK' → 'Update available' again
testWidgets('Back on Downloading does not close the dialog', ...);

// settings_test.dart
testWidgets('Check for updates says up to date when nothing is new', ...); // koban-6.apk → 'Koban is up to date.'
testWidgets('a failed manual check shows the message in a dialog', ...); // 500 → 'Could not check for updates. Try again later.'
```

- [ ] **Step 2: Run.** `flutter test test/update/update_dialog_test.dart test/screens/settings_test.dart` → FAIL.
- [ ] **Step 3: Implement.** Delete `online_placeholder.dart`. Update `PORTED.md`: the "move in later milestones" lines now point to `test/update/` (ReleaseParser 6, UpdateSchedule 5), Kotlin `ApkCheckTest` (4, in `koban/android`), `test/receipts/cache_file_test.dart` (CacheFile 5) and `test/screens/split_read_note_test.dart` (SplitReadNote 1).
- [ ] **Step 4: Run, one at a time.** `flutter analyze` → "No issues found!"; `flutter test` → "All tests passed!" (6 new tests); Gradle test → BUILD SUCCESSFUL.
- [ ] **Step 5: Build once.** `flutter build apk --debug` (with the root `.env` present; no `SUPABASE_KEY is missing` warning) → `koban/build/app/outputs/flutter-apk/app-debug.apk` exists. Do not install it.
- [ ] **Step 6: Check the built manifest.** `D:/Android/build-tools/<newest>/aapt2 dump xmltree --file AndroidManifest.xml koban/build/app/outputs/flutter-apk/app-debug.apk` → holds `android.permission.INTERNET`, `android.permission.REQUEST_INSTALL_PACKAGES`, `com.expensetracker.app.update.UpdateInstallReceiver`, `fullBackupContent` and `dataExtractionRules`, and still the 4 listener component names of milestone 3.
- [ ] **Step 7: Check milestone 5 is complete.** `grep -rn "OnlineFeature\|OnlinePlaceholder\|online_placeholder" koban/lib koban/test` → nothing. `grep -rn "inGroups" koban/lib` → `AppServices`, `GroupRepository` and the payment sheet. `git diff --stat main -- app/ gradle/ supabase/` → empty. `git grep -n "eyJ\|sb_publishable_" -- koban/` → nothing.
- [ ] **Step 8: Draft the map note** for issue #20 (3 to 5 lines, STE): groups with the restored 0.1.1 sign-in, the invite code, receipt reading with ML Kit and Claude, delete account and the updater are in Flutter; no placeholder is left; the owner device checks are open. The controller posts it.
- [ ] **Step 9: Commit.** "Add the update dialog and close milestone 5".

## Known limits

- A debug build cannot install a release APK (Decision 3). The full update path (download, check, install, restart) is first proven in milestone 6 with a release-signed build, before any friend gets it (`docs/RELEASING.md` section 7).
- Android closes Koban after a self-update and does not open it again, as in 0.1.1.
- GitHub allows 60 calls per hour per IP address without a token (`docs/RELEASING.md` section 8); the rules for 403 stay as 0.1.1.

## Owner device checks (end of milestone 5)

Build the debug APK with the root `.env` present. Use the test phone of milestones 3 and 4. About 45 minutes.

1. Restore: on the test phone, install the 0.1.1 debug build, enter your invite code, sign in to Groups and open a group. Then install the Flutter build over it (`adb install -r koban/build/app/outputs/flutter-apk/app-debug.apk`) and open Koban › Groups: your groups show with no sign-in; Settings › Online shows `Accepted. Receipts are read by Claude on Koban's server.`.
2. Online switch: Settings › Online features off → Groups shows `Online features are off`; Split a bill › Take photo reads on the phone only. Turn it on → the groups come back.
3. Google sign-in: Groups › Account › Sign out, then `Sign in with Google` → Google's own sign-in screen (not a bottom sheet) → the groups show. Change your name, open a group, `Share code` opens the share sheet with the 0.1.1 text.
4. Totals: make a small payment, wait 10 seconds, pull down on the group page → your total changes and shows `Updated just now`. Edit the payment, turn off `Count in group totals` → after the next sync your total drops by that amount.
5. Receipts: Split a bill › Take photo → the ML Kit scanner opens → items show with `✓ Read by Claude · <n> reads left today`. Repeat with `Choose from gallery`. Close the editor, then `adb shell run-as io.github.skooyo.koban.debug ls -R cache` → no scan or picked photo is left.
6. Updater: build the debug APK with `--build-number 1`, install it, Settings › Check for updates → `Update available` with the latest GitHub release. Tap `Update`: the first time, the "Install unknown apps" page opens; allow it, go back, tap `Update` again → `Downloading the update…` → `Update failed. Try again later.`. This is the expected result: the release APK has the app ID `io.github.skooyo.koban` and the debug build is `io.github.skooyo.koban.debug` (Decision 3). `adb logcat -d | grep -i "Install failed\|NOT_KOBAN_APK"` shows the refusal, not a crash.
7. Delete account: only with a spare Google account. Sign out, sign in with the spare account, Groups › Account › Delete account › `Delete account` → the sign-in page shows. In the Supabase dashboard, `profiles` has no row for that account.
