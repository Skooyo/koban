# Flutter milestone 4b: Check payments, payment apps, Settings, notification log and onboarding — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build every screen that works with payment capture at parity with 0.1.1: Check payments (swipe, hold, undo, save, drop), the payment apps picker, Settings, the notification log and onboarding, plus the 0.1.1 auto-open on app start.

**Architecture:** The screens use the milestone 3 Dart APIs (`PendingPaymentRepository`, `PaymentApps`, `ListenerControl`, `ChannelCaptureHost.updateLog`) and the plan 4a shell. A new class `PaymentChecks` owns the 4-second hold, Undo and the commit of a swipe (save through `ExpenseRepository.saveConfirmed`, or a drop marker), so the capture isolate keeps using only `PendingPaymentRepository`. Because the capture isolate writes through its own Drift connection, the UI isolate polls `PRAGMA data_version` while the app is in front and marks the tables as changed, so new cards show without a restart. Phone facts that no milestone 3 channel gives (installed apps, app names, Android version, app version, the alerts permission, the gallery, share) come from one new native channel `io.github.skooyo.koban/device` on the milestone 3 `KobanNativePlugin`.

**Tech Stack:** Flutter 3.50.0 / Dart 3.14.0; plan 4a code; milestone 3 Kotlin (`KobanNativePlugin`, Robolectric tests). No new pub package. No new Gradle dependency.

**Spec:** `docs/superpowers/specs/2026-11-13-flutter-migration-design.md` (sections 6.2 "Screens", 6.4 step 4, 6.7 item 4). Contract: `docs/superpowers/plans/2026-11-14-flutter-m3-capture.md`, Interfaces of Tasks 3 to 6 and its "Not in this milestone" line.

**Order:** plan 2 of 3. Start on branch `feature/flutter-m4b` from `main` after plan 4a (`2026-11-14-flutter-m4a-shell-home-activity.md`) is merged. Plan 4c comes next.

**Decisions (the spec leaves these to the builder):**
1. **Hold and commit in a UI-only class (`PaymentChecks`),** not in `PendingPaymentRepository`: the capture isolate makes its own `PendingPaymentRepository` and must not own timers or the hidden set. Kotlin's process `Mutex` becomes one `db.transaction` per commit; milestone 3 Decision 5 (`BEGIN IMMEDIATE`, `busy_timeout` 5000) makes it atomic across isolates.
2. **New cards from the capture isolate: poll `PRAGMA data_version` every 2 s while the app is resumed** (`ExternalWrites`). Rejected: a native `cardsChanged` call from the capture engine to the UI engine (changes the milestone 3 Kotlin protocol for a 2-second gain); `shareAcrossIsolates` (rejected by milestone 3 Decision 5).
3. **Phone facts through one native channel,** not plugins: `device_apps` and `installed_apps` are not maintained or give no icons; `permission_handler` and `share_plus` would add 2 packages for 3 calls; the gallery save is a port of `QrStore.saveToGallery` (about 50 lines). Image picking stays with a plugin (plan 4c).
4. **Live notification log: poll `ListenerControl.recentNotifications()` every 2 s while the log screen is open.** 0.1.1 observed an in-process flow; milestone 3 gives only request and answer calls.
5. **The swipe stamps say `Save` and `Not a payment`,** not `SAVE` and `NOT A PAYMENT`: DESIGN.md "No all-caps labels" overrides the 0.1.1 text.
6. **`reconnectStatusMessage` is not ported:** 0.1.1 defines it in `NotificationAccessHelper.kt` but no screen calls it.
7. **App start:** 0.1.1 auto-opens on each activity `ON_START`; Flutter's `AppLifecycleListener.onShow` is the same moment. The 0.1.1 rotation guard (`isChangingConfigurations`) is not needed: Flutter does not restart the activity on rotation.

**Not in this plan:** People, person, splits, the People badge (plan 4c). Invite code check, the update check and dialog (milestone 5: the buttons open `OnlinePlaceholder`). iPhone hiding of these screens (milestone 7).

## Global Constraints

- All Global Constraints of plan 4a apply (tools, controller commits, one build at a time, analyze and test at the end of each task, `git diff main -- app/ gradle/` empty, 0.1.1 text, money format, `AppServices.now`, accessibility checks, motion, STE).
- Gradle: `cd koban/android && JAVA_HOME=D:/jdk-17 ./gradlew.bat --max-workers=2 :app:testDebugUnitTest`. Run it at the end of Task 1 and Task 7 only (the tasks that change Kotlin or check the branch).
- Keep the milestone 3 channel names and methods. Add only the `device` channel and its registration.
- Timing values from 0.1.1: hold and Undo window 4000 ms (`HOLD_MS`, `UNDO_MS`); swipe commit 100 dp, stamp full at 90 dp, fly-out 520 dp in 250 ms, tilt 1 degree per 18 dp, 3 cards in the stack (each lower card 10 dp down, 4% smaller, 25% more transparent); reconnect result after 65 s; drop marker key `"$notificationKey@$postTime"`.
- Messages, verbatim: `Already saved, so it was not added again.`, `Choose Spent or Received first.`, `Saved $what · Undo`, `Skipped $what · Undo`.
- The repository is public: test texts are the milestone 3 synthetic texts (for example `Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.` from `com.maybank2u.life`).

## Review Focus

1. The friend swipes and leaves the app (Home button) inside the 4-second Undo window: the swipe must commit at once, and when the app comes back the card must not show again. Pinned in Tasks 2 and 3.
2. A payment arrives while Home or Check payments is open: it must show within a few seconds without a restart, even though the capture isolate wrote it. Pinned in Task 2.
3. The friend drops a card ("Not a payment") and the same notification comes again (Touch 'n Go reuses one key): it must not come back as a card, but a second payment with the same key and another post time must. Pinned in Task 2.
4. A card whose direction is unclear must not save until the friend picks Spent or Received; a drop still works. Pinned in Task 3.
5. A new friend opens the app for the first time: onboarding comes first, then the payment apps picker, and only then Check payments; an existing friend with access never sees onboarding. Pinned in Task 7.

---

### Task 1: Device channel

**Files:**
- Create: `koban/android/app/src/main/kotlin/io/github/skooyo/koban/DeviceChannel.kt`, `koban/lib/device/device_control.dart`
- Modify: `koban/android/app/src/main/kotlin/io/github/skooyo/koban/KobanNativePlugin.kt` (register the channel; implement `ActivityAware` and `PluginRegistry.RequestPermissionsResultListener`), `koban/android/app/src/main/AndroidManifest.xml` (add the 0.1.1 `<queries>` block for `MAIN` / `LAUNCHER`, and `WRITE_EXTERNAL_STORAGE` with `android:maxSdkVersion="28"`), `koban/android/app/src/test/kotlin/io/github/skooyo/koban/KobanNativePluginTest.kt` (the channel set now has 4 names)
- Test: `koban/android/app/src/test/kotlin/io/github/skooyo/koban/DeviceChannelTest.kt`, `koban/test/device/device_control_test.dart`

**Interfaces:**
- Consumes: `KobanNativePlugin.register(context, messenger)` and its `executor` (milestone 3 Task 3).
- Produces:
  - Channel `io.github.skooyo.koban/device` (Dart → native): `installedApps` → `List<Map>` with keys `packageName`, `label`, `icon` (PNG bytes, 40 dp square, or null) for launcher apps other than Koban, one row per package (port of `PaymentAppsViewModel.loadApps` without the sort); `appLabels {packages: List<String>}` → `Map<String, String>` (the package name when the app is not visible); `sdkInt` → int; `versionName` → String; `notificationsAllowed` → bool (true below Android 13); `shouldShowNotificationRationale` → bool (false with no activity); `requestNotificationPermission` → bool (granted; true below Android 13 with no dialog); `openAppNotificationSettings`; `openAppInfo`; `storageAllowed` → bool (true from Android 10); `requestStoragePermission` → bool; `saveImageToGallery {path, displayName}` → String (the MediaStore uri; port of `QrStore.saveToGallery` and `writeJpeg`; errors as `PlatformException` code `GALLERY` with the Kotlin message `That file isn't an image.` or `Couldn't save to gallery.`); `shareText {text, chooserTitle}` (an `ACTION_SEND` `text/plain` chooser, `FLAG_ACTIVITY_NEW_TASK`).
  - `koban/lib/device/device_control.dart`: `class InstalledApp { final String packageName; final String label; final Uint8List? icon; }` and `class DeviceControl { DeviceControl([MethodChannel channel = const MethodChannel('io.github.skooyo.koban/device')]); Future<List<InstalledApp>> installedApps(); Future<Map<String, String>> appLabels(Iterable<String> packages); Future<int> sdkInt(); Future<String> versionName(); Future<bool> notificationsAllowed(); Future<bool> shouldShowNotificationRationale(); Future<bool> requestNotificationPermission(); Future<void> openAppNotificationSettings(); Future<void> openAppInfo(); Future<bool> storageAllowed(); Future<bool> requestStoragePermission(); Future<void> saveImageToGallery(String path, String displayName); Future<void> shareText(String text, {String chooserTitle = 'Share summary'}); }` — `saveImageToGallery` throws `KobanUserError(message)` for the code `GALLERY`.

- [ ] **Step 1: Write the failing tests.**

```kotlin
// DeviceChannelTest — Robolectric @Config(sdk = [35]); FakeMessenger and the direct executor of milestone 3
@Test fun installedAppsListsLauncherAppsWithLabelsAndLeavesOutKoban() {
    // shadowOf(pm).addResolveInfoForIntent(launcher intent, info for "com.maybank2u.life" label "MAE" and for context.packageName)
    val apps = messenger.call(DEVICE, "installedApps", null) as List<Map<String, Any?>>
    assertEquals(listOf("com.maybank2u.life"), apps.map { it["packageName"] })
    assertEquals("MAE", apps.single()["label"])
}
@Test fun appLabelsGiveThePackageNameForAnAppThatIsNotVisible() { /* {"x.y": "x.y"} */ }
@Test @Config(sdk = [32]) fun notificationPermissionIsGrantedBeforeAndroid13WithNoDialog() { /* true; no permission request recorded */ }
@Test fun saveImageToGalleryRefusesAFileThatIsNotAnImage() { /* text file → error code "GALLERY", message "That file isn't an image." */ }
@Test fun shareTextStartsAChooserWithTheText() {
    // shadowOf(app).nextStartedActivity: action ACTION_CHOOSER, EXTRA_TITLE "Share summary", inner EXTRA_TEXT "Kedai Contoh, 13 Nov 2026"
}
// KobanNativePluginTest: registersTheFourChannelsOnAnyEngine — adds "io.github.skooyo.koban/device"
```

```dart
// device_control_test.dart — mock the device channel
test('installed apps come back as typed rows with their icon bytes', ...);
test('a gallery error becomes a user error with the native text', ...); // PlatformException(code: 'GALLERY', message: "That file isn't an image.") → KobanUserError("That file isn't an image.")
```

- [ ] **Step 2: Run.** Gradle test → FAIL; `flutter test test/device/` → FAIL.
- [ ] **Step 3: Implement.** Disk and PackageManager work runs on the plugin `executor`; replies go back on the main thread (milestone 3 rule). Permission requests use the attached activity and request code `4201` (alerts) and `4202` (storage); a request with no activity answers the current state.
- [ ] **Step 4: Run.** Gradle test → BUILD SUCCESSFUL (5 new tests, 1 changed). `flutter analyze`; `flutter test` → PASS (2 new tests).
- [ ] **Step 5: Commit.** "Add the device channel for apps, permissions, gallery and share".

### Task 2: Saving and dropping checked payments

**Files:**
- Create: `koban/lib/data/payment_checks.dart`, `koban/lib/data/external_writes.dart`
- Modify: `koban/lib/data/expense_repository.dart` (add `saveConfirmed`), `koban/lib/app/app_services.dart` (add `pending`, `paymentChecks`, `externalWrites`, `paymentApps`, `captureHost`, `device`), `koban/lib/app/koban_app.dart` (start `externalWrites` on resume, stop it on hide)
- Test: `koban/test/data/payment_checks_test.dart`, `koban/test/data/external_writes_test.dart`

**Interfaces:**
- Consumes: `PendingPaymentRepository(db, now:)` with `watchWaiting`, `capture` (milestone 3 Task 4); `KobanDatabaseDedup.hasExpenseFor`, `forcedDedupPrefix` (milestone 3 `expense_dedup.dart`); `DedupKeyGenerator.generate`; `PaymentApps`, `ChannelCaptureHost` (milestone 3 Task 5); `MerchantCategoryRepository`, `SplitRepository.suggestRepayment` (plan 4a).
- Produces:
  - `ExpenseRepository.saveConfirmed(PendingPayment p) → Future<bool>` — port of `ExpenseRepository.saveConfirmed` in one `db.transaction`: a `forced:` key skips the duplicate check; else `db.hasExpenseFor(...)` true → false; category = card category, else the merchant memory; status `EDITED` when `p.edited`, else `AUTO_SAVED`; confidence `HIGH`; notes null; new id; `createdAt = now()`; the mapping is saved only when `p.edited`; a `RECEIVE` calls `splits.suggestRepayment` (an error is logged, not thrown).
  - `enum ConfirmResult { saved, alreadySaved, dropped }`
  - `class PaymentChecks { PaymentChecks({required KobanDatabase db, required PendingPaymentRepository pending, required ExpenseRepository expenses, required int Function() now, Duration hold = const Duration(milliseconds: 4000)}); Stream<List<PendingPayment>> watchVisible(); Stream<int> watchVisibleCount(); Stream<ConfirmResult> get results; Future<void> update(PendingPayment p); void hold(String id, {required bool save}); bool undo(); void flushHold(); Future<void> get idle; }` — port of `PendingPaymentRepository.kt` `hold` / `undo` / `flushHold` / `take` / `commit` / `update` and the hidden set: `watchVisible` = `pending.watchWaiting()` without the hidden ids; a hold of another card commits the earlier hold at once; the same card again only replaces the choice and restarts the window; save → `saveConfirmed`, then delete the card in both outcomes (`saved` or `alreadySaved`); drop → insert `DroppedNotification(dedupKey, notificationKey: '${key}@${postTime}' or null, droppedAt: now())` and delete the card in one transaction; an error keeps the card and only logs; the id leaves the hidden set in every outcome. `update` writes `toMoney(amount)`, a new dedup key unless the key starts with `forced:`, and `edited = true`. `idle` completes when no commit runs (a test seam).
  - `class ExternalWrites { ExternalWrites(KobanDatabase db, {Duration every = const Duration(seconds: 2)}); void start(); void stop(); Future<bool> checkNow(); }` — reads `PRAGMA data_version`; on a change, `db.markTablesUpdated({db.pendingPayments, db.expenses})` and returns true. Mark it `// ponytail: polls every 2 s while the app is in front; upgrade: a native call from the capture engine after each card.`

- [ ] **Step 1: Write the failing tests.** In-memory database; `T = DateTime(2026, 11, 13, 12).millisecondsSinceEpoch`; cards made with `pending.capture(...)` from the milestone 3 texts; `fakeAsync` for the timers. If Drift stream timers do not run under `fakeAsync`, use `PaymentChecks(hold: const Duration(milliseconds: 40))` with real time instead; the assertions stay the same.

```dart
test('a held save commits after 4 seconds and the card becomes a payment', () {
  fakeAsync((async) {
    // card RM 15.00 RESTORAN CONTOH; merchant memory 'restoran contoh' → 'food'
    checks.hold(id, save: true);
    async.elapse(const Duration(milliseconds: 3999));
    // pending_payments: 1 row; watchVisible: []
    async.elapse(const Duration(milliseconds: 1)); async.flushMicrotasks();
    // expenses: 1 row, categoryId 'food', status AUTO_SAVED, confidence HIGH, dedupKey == the card key; pending_payments: 0
    // results: [ConfirmResult.saved]
  });
});
test('undo inside the window brings the card back and writes nothing', ...); // undo() true; watchVisible [card]; elapse 5 s → 0 expenses
test('a swipe of another card commits the first at once', ...);
test('a second swipe of the same card only changes the choice', ...); // save then drop → after 4 s: 0 expenses, 1 drop marker
// Review Focus 1
test('flush commits the hold at once', ...);
// Review Focus 3
test('Not a payment writes a drop marker so the same notification does not come back', () async {
  // card key 'k1', post time P; hold(save: false); flushHold(); await idle
  // dropped_notifications: dedupKey == card key, notificationKey 'k1@$P'
  expect(await pending.capture(/* same */), isNull);
  expect(await pending.capture(/* same key, post time P + 60000 */), isNotNull);
});
test('a card that a payment already covers is removed and reports already saved', ...);
test('an edited card saves as EDITED and teaches the shop its category', ...);
  // update(card.copyWith(merchant: Value('Kedai Contoh'), categoryId: Value('food'))) → edited 1, dedupKey regenerated;
  // save → status EDITED; merchant_category_map ('kedai contoh', 'Kedai Contoh', 'food')
test('a forced card keeps its key on edit and saves next to an equal payment', ...);
test('a received card that fits a debt becomes its suggestion', ...);

// external_writes_test.dart — Review Focus 2
test('a card written by another connection shows without a restart', () async {
  // A and B: KobanDatabase(NativeDatabase(file, setup: configureConnection)) on one temp file
  // listen to PaymentChecks(db: A, ...).watchVisibleCount(); first value 0
  // PendingPaymentRepository(B).capture(...)
  expect(await ExternalWrites(A).checkNow(), true);
  // the count stream emits 1
});
test('no write from another connection gives no change', ...); // checkNow() false
```

- [ ] **Step 2: Run.** `flutter test test/data/payment_checks_test.dart test/data/external_writes_test.dart` → FAIL.
- [ ] **Step 3: Implement.** `AppServices.start` makes `PaymentApps(SharedPreferencesAsync(), ChannelCaptureHost())` and `PendingPaymentRepository(db, now: ...)`.
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (12 new tests).
- [ ] **Step 5: Commit.** "Hold, save and drop checked payments, and see cards from the capture engine".

### Task 3: Check payments screen

**Files:**
- Create: `koban/lib/screens/check/check_payments_screen.dart`, `koban/lib/screens/check/check_payments_view_model.dart`, `koban/lib/screens/check/check_payment_card.dart` (the card and `EditPaymentSheet`)
- Modify: `koban/lib/app/routes.dart` (`openCheckPayments`), `koban/lib/screens/home/home_screen.dart`, `koban/lib/screens/home/home_view_model.dart` (waiting count and row)
- Test: `koban/test/screens/check_payments_screen_test.dart`, `koban/test/screens/check_payments_view_model_test.dart`

**Interfaces:**
- Consumes: `PaymentChecks` (Task 2), `DeviceControl.appLabels` (Task 1), `CategoryRepository.watchAll`, `MerchantCategoryRepository.categoryIdForMerchant`, `DirectionSegments`, `KobanRow`, `InitialsAvatar`, `Mon`, `AmountInput`, `showPastDatePicker`, `showDiscardChangesDialog`, `showCategorySheet` (plan 4a).
- Produces:
  - `class CheckCard { final PendingPayment payment; final String appName; final String? categoryId; final String categoryName; }`
  - `class CheckPaymentsViewModel extends ChangeNotifier { CheckPaymentsViewModel(AppServices s); static const alreadySavedMessage = 'Already saved, so it was not added again.'; List<CheckCard>? get cards /* null until the first read */; int get handled; String? get undoLabel; Stream<String> get messages; List<Category> get categories; void swipe(String id, {required bool save}); void undo(); Future<void> edit(PendingPayment p); void flushHold(); }` — port of `CheckPaymentsViewModel.kt`: card category = own category, else the merchant memory, only when that category exists; `what` = merchant, else `RM 1,234.50`; the pill shows 4000 ms; after Undo the pill stays until the card is back (at most 1000 ms); `dispose` calls `flushHold`.
  - `routes.dart`: `Future<void> openCheckPayments(BuildContext context)` (a page).
  - `CheckPaymentsScreen` — layout of `CheckPaymentsScreen.kt` and `CheckPaymentCard.kt`: Back (`Back`), title `Check payments`, counter `${handled + 1} of ${cards.length + handled}`; up to 3 stacked cards, oldest on top; card: avatar, `$appName · $time` (`MaterialLocalizations.formatTimeOfDay` with the phone's 24-hour setting), `Unknown format` tag in `review` for `CaptureFormat.unknown`, the amount (`displayMedium`, `+ ` and `received` color for Received, tap label `Change payment`), `Spent or Received?` with `DirectionSegments` when the direction is unclear, rows `Shop` (`Not set`), `Category`, `Date` (`Today, 12:00`), the notification text in curly quotes `“…”`; stamps `Save` (right, `received`) and `Not a payment` (left, `error`) (Decision 5); the hint `Tap a field to fix it. Swipe right to save, left for Not a payment.`; buttons `Not a payment` (outline) and `Save payment` (filled); the empty state `Mon(MonFace.happy, size: 120)`, `All checked`, `Nothing left. I will just sit here and shine.`, `Back to Home`; the Undo pill (inverse colors, tap label `Undo`, polite live region) 140 dp above the bottom; the screen pops when the list is empty and the pill is gone. Card semantics: merged, custom actions `Save` and `Not a payment` (only `Not a payment` while the direction is unclear). `AppLifecycleListener(onHide: vm.flushHold)`. `EditPaymentSheet`: title `Change payment`, `Amount (RM)` with `Type an amount above 0`, `DirectionSegments`, `Shop`, `Category` (`Change category`), `Date` (`Change date`), `Save changes`; a swipe-down or Back with changes asks `Discard changes?`.
  - Home: `HomeViewModel.waitingCount` from `paymentChecks.watchVisibleCount()`; the row `1 payment to check` / `$n payments to check` (receipt icon in `goldText`, chevron) after the banner → `openCheckPayments`; the first-payment card also needs `waitingCount == 0`.

- [ ] **Step 1: Write the failing tests.** Device channel mocked: `appLabels` gives `{'com.maybank2u.life': 'MAE'}`. Three cards (oldest first): RM 15.00 RESTORAN CONTOH, RM 8.00 Kedai Contoh, RM 50.00 received from ALI.

```dart
// check_payments_view_model_test.dart
test('cards come oldest first with the app name and the remembered category', ...);
test('a swipe hides the card, counts it and shows Saved with the shop', ...); // undoLabel 'Saved RESTORAN CONTOH · Undo', handled 1
test('a swipe of a card with no shop names the amount', ...); // 'Skipped RM 15.00 · Undo'
test('undo counts back and the pill goes when the card is back', ...);
test('an already saved card gives the already saved message', ...);

// check_payments_screen_test.dart
testWidgets('the oldest card is on top with its counter', ...); // '1 of 3', 'MAE · 12:00', 'RM 15.00'
testWidgets('Save payment saves the top card after the Undo window', ...);
  // tap 'Save payment' → 'Saved RESTORAN CONTOH · Undo', '2 of 3'; pump 4 s → 1 expense
testWidgets('Not a payment drops the top card', ...); // 'Skipped RESTORAN CONTOH · Undo'
testWidgets('a drag past 100 dp saves and a shorter drag springs back', ...); // drag(Offset(150, 0)) → pill; drag(Offset(80, 0)) → no pill, card at dx 0 after settle
testWidgets('Undo brings the card back', ...);
// Review Focus 4
testWidgets('a card with no clear direction asks for Spent or Received first', ...);
  // 'Spent or Received?'; tap 'Save payment' → snackbar 'Choose Spent or Received first.', 0 expenses; tap 'Spent' → 'Save payment' works
// Review Focus 1
testWidgets('leaving the app commits the held swipe at once', ...);
  // tap 'Save payment'; handleAppLifecycleStateChanged(AppLifecycleState.hidden) → 1 expense before 4 s
testWidgets('the last card shows All checked and the screen closes after the pill', ...);
testWidgets('a tap on the shop opens Change payment and saves the edit', ...); // 'Change payment', 'Amount (RM)', 'Save changes' → card shows the new shop
testWidgets('screen readers get Save and Not a payment as card actions', ...);
testWidgets('Check payments meets the tap target guidelines and works at text scale 1.3', ...);
// Home
testWidgets('Home shows the waiting count and opens Check payments', ...); // '3 payments to check' → 'Check payments'; one card → '1 payment to check'
```

- [ ] **Step 2: Run.** `flutter test test/screens/check_*` → FAIL.
- [ ] **Step 3: Implement.** Drag with `GestureDetector.onHorizontalDrag*`; the fly-out and spring-back use one `AnimationController`; with animations off, both snap.
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (17 new tests).
- [ ] **Step 5: Commit.** "Add the Check payments screen".

### Task 4: Payment apps picker

**Files:**
- Create: `koban/lib/screens/payment_apps/payment_apps_screen.dart`, `koban/lib/screens/payment_apps/payment_apps_view_model.dart`
- Modify: `koban/lib/app/routes.dart` (`openPaymentApps`), `koban/lib/screens/home/home_screen.dart`, `koban/lib/screens/home/home_view_model.dart` (the "listens to no app" row)
- Test: `koban/test/screens/payment_apps_test.dart`

**Interfaces:**
- Consumes: `DeviceControl.installedApps` (Task 1), `PaymentApps.load` / `save` (milestone 3), `KobanSettings.paymentAppsChosen` / `paymentApps` / `reload`, `PaymentRules.preselectPackages` (milestone 1).
- Produces:
  - `List<InstalledApp> sortApps(List<InstalledApp> apps, Set<String> preselect)` and `Set<String> initialSelection({required bool chosen, required Set<String> allowlist, required Set<String> installed, required Set<String> preselect})` — `PaymentAppsViewModel.kt`.
  - `class PaymentAppsViewModel extends ChangeNotifier { PaymentAppsViewModel(AppServices s); List<InstalledApp>? get apps; Set<String> get selected; String get query; List<InstalledApp> get shown /* label contains the trimmed query, case ignored */; void setQuery(String q); void toggle(String packageName); Future<void> save(); }` — `save` calls `paymentApps.save(selected)` then `settings.reload()`.
  - `routes.dart`: `Future<void> openPaymentApps(BuildContext context)`.
  - `PaymentAppsScreen({VoidCallback? onSaved, VoidCallback? onBack})` (onboarding passes both; the route pops by default) — layout of `PaymentAppsScreen.kt`: title `Payment apps`, Back (`Back`), `Koban reads notifications only from the apps you tick.`, search field `Search apps`, one row per app (icon, label, check box), `No apps match.`, the main button `Save` / `Save 1 app` / `Save $n apps`.
  - Home: `HomeViewModel.listensToNoApp` (`paymentAppsChosen && paymentApps.isEmpty`); the row `Koban listens to no app. Choose your payment apps.` (chevron) → `openPaymentApps`; the first-payment card also needs `!listensToNoApp`.

- [ ] **Step 1: Write the failing tests.** Port `PaymentAppsRulesTest.kt` (3 cases) one to one.

```dart
test('preselected apps come first, then the label order', ...); // ['mb', 'tng', 'a', 'c']
test('the first open ticks only the installed preselected apps', ...); // {'mb'}
test('a later open ticks the stored list', ...); // {'x'}; and {} for an empty stored list
testWidgets('the picker lists the apps with the preselected ones ticked', ...);
  // installedApps: MAE (com.maybank2u.life), Touch 'n Go (my.com.tngdigital.ewallet), Chat (com.example.chat) → button 'Save 2 apps'
testWidgets('search filters by label and says when nothing matches', ...); // 'mae' → 1 row; 'zzz' → 'No apps match.'
testWidgets('save stores the list and the native copy and closes', ...);
  // untick TNG → 'Save 1 app' → prefs payment_app_allowlist ['com.maybank2u.life'], payment_apps_chosen true; capture channel got setPaymentApps; route popped
testWidgets('Home asks to choose payment apps when none is chosen', ...); // chosen true, list [] → row; tap → 'Payment apps'
testWidgets('the picker meets the tap target guidelines and works at text scale 1.3', ...);
```

- [ ] **Step 2: Run.** `flutter test test/screens/payment_apps_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (8 new tests).
- [ ] **Step 5: Commit.** "Add the payment apps picker".

### Task 5: Settings

**Files:**
- Create: `koban/lib/screens/settings/settings_screen.dart`, `koban/lib/screens/settings/settings_view_model.dart`
- Modify: `koban/lib/app/routes.dart` (`openSettings`), `koban/lib/screens/home/home_screen.dart` (the `Settings` icon button in the top bar, and the `Set up later` part of the first-payment card)
- Test: `koban/test/screens/settings_test.dart`

**Interfaces:**
- Consumes: `ListenerControl` (`isAccessGranted`, `ensureActive`, `reconnect`, `isConnected`, `openAccessSettings`, `isBatteryOptimizationIgnored`, `openBatteryOptimizationSettings`, `isXiaomiFamily`, `openBackgroundSettings`, `recentNotifications`); `DeviceControl.versionName`; `KobanSettings`; `CategoryRepository`; `PaymentRules.match`; `openPaymentApps` (Task 4); `openOnlinePlaceholder` (plan 4a).
- Produces:
  - `const xiaomiChecklist = <String>[...]` — the 7 texts of `OemBatteryHelper.xiaomiChecklist()`, verbatim.
  - `class SettingsViewModel extends ChangeNotifier { SettingsViewModel(AppServices s, {Duration reconnectWait = const Duration(seconds: 65)}); bool get isAccessGranted, isBatteryOptimizationIgnored, isXiaomi, onlineFeatures, hasDeviceToken, darkMode; int get paymentAppCount, capturedCount; String get versionName; List<Category> get categories; String? get reconnectMessage, parserResult; Future<void> refresh(); Future<void> reconnect(); Future<void> openNotificationSettings(); Future<void> openBatterySettings(); Future<void> openBackgroundSettings(); Future<void> setDarkMode(bool on); Future<void> setOnlineFeatures(bool on); Future<void> removeDeviceToken(); void runParserTest(String text); Future<void> addCategory(String name); Future<void> deleteCategory(String id); }` — texts of `SettingsViewModel.kt`: `Reconnecting…`; access not granted `Notification access was removed — re-enable it in system settings. On Xiaomi, enable Autostart and avoid clearing the app from recents.`; throttled `Reconnect already attempted recently — wait a moment and try again.`; failed `Reconnect failed — open notification access settings.`; after `reconnectWait`: `Listener connected.` or `Still disconnected after 60s — tap the alert notification or open notification access settings.`; parser result `Amount: MYR 15.00\nMerchant: RESTORAN CONTOH\nType: withdraw\nFormat: known` (`—` for no shop), or `No rule matched this text`; new categories get `#5C6BC0`.
  - `routes.dart`: `Future<void> openSettings(BuildContext context)`.
  - `SettingsScreen` — the sections, rows and texts of `SettingsScreen.kt` in order: Tracking (status banner; `Payment apps` with `None chosen. Koban listens to no app.` / `1 app chosen` / `$n apps chosen`; `Notification log` with `$n notifications captured` or `Every notification the listener receives, with save and skip reasons` (plan 4b Task 6 wires its tap); `Reconnect listener` with the reconnect message + ` If an alert appears, tap it or open notification access settings.` in primary color, else `Use this when payments stop showing up. It retries for about 60 seconds.`), Appearance (`Dark mode`, `Use the dark theme across the app`, switch), Categories (`Built in` / `Your own`, delete `Remove category $name` for own ones, field `New category`, `Add`, `Categories and notes are saved on this phone only.`), Online (`Online features` switch with the two 0.1.1 subtitles; with a device token: `Invite code`, `Accepted. Receipts are read by Claude on Koban's server.`, `Remove`; without: `Invite code`, the 0.1.1 explanation, field `XXXX-XXXX` (upper case), `Use code` (on when the field has text) → `openOnlinePlaceholder(context, OnlineFeature.inviteCode)`), Background (battery rows `Off. Good for background tracking.` / `On. Tracking may stop in the background. Tap to turn it off.` with tap label `Disable battery optimization`; on Xiaomi `Xiaomi autostart` with its subtitle, tap label `Open Xiaomi autostart and battery settings` and `• $step` lines; the 0.1.1 paragraph `You do not need to keep the app open. …`), About (`App version $versionName`, `Turn on Online features to check for updates.` when off, `Check for updates` (off when Online features is off) → `openOnlinePlaceholder(context, OnlineFeature.updates)`; `Parser test tool`, its hint, field `Notification text`, `Test parse`, the result). `refresh` runs on open and on each resume.
  - Home: `IconButton(Icons.settings, tooltip: 'Settings')` → `openSettings`; the first-payment card adds `Set up later` and the row `Online features` / `Read receipts, join groups` → `openSettings`.

- [ ] **Step 1: Write the failing tests.** Listener channel answers: access true, connected true, battery ignored false, Xiaomi false, `recentNotifications` 2 rows, `reconnect` `'ATTEMPTED'`.

```dart
testWidgets('Settings shows the tracking rows with their counts', ...); // '2 apps chosen', '2 notifications captured'
testWidgets('reconnect shows Reconnecting and then the result after the wait', ...);
  // reconnectWait 1 s: tap 'Reconnect listener' → 'Reconnecting… If an alert appears, tap it or open notification access settings.'; pump 1 s → 'Listener connected. If an alert …'
testWidgets('a throttled reconnect says to wait', ...);
testWidgets('the dark mode switch changes the theme at once', ...); // tap → Theme brightness light, prefs dark_mode false
testWidgets('own categories can be added and removed, built-in ones cannot', ...);
testWidgets('the parser tool reads a sample text', ...); // milestone 3 sample → 'Amount: MYR 15.00\nMerchant: RESTORAN CONTOH\nType: withdraw\nFormat: known'
testWidgets('Use code and Check for updates open the online placeholder', ...);
testWidgets('Check for updates is off when Online features is off', ...); // subtitle 'Turn on Online features to check for updates.'
testWidgets('a stored invite code shows Accepted and Remove deletes it', ...);
testWidgets('on a Xiaomi phone the autostart row and the 7 steps show', ...); // '• Security app → Autostart → turn ON for Koban'
testWidgets('the Home settings button and the Set up later row open Settings', ...);
testWidgets('Settings meets the tap target guidelines and works at text scale 1.3', ...);
```

- [ ] **Step 2: Run.** `flutter test test/screens/settings_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (12 new tests).
- [ ] **Step 5: Commit.** "Add the Settings screen".

### Task 6: Notification log

**Files:**
- Create: `koban/lib/screens/notification_log/notification_log_screen.dart`, `koban/lib/screens/notification_log/notification_log_view_model.dart`
- Modify: `koban/lib/app/routes.dart` (`openNotificationLog`), `koban/lib/screens/settings/settings_screen.dart` (the `Notification log` row opens it)
- Test: `koban/test/screens/notification_log_test.dart`

**Interfaces:**
- Consumes: `ListenerControl` (`isAccessGranted`, `isConnected`, `ensureActive`, `reconnect`, `recentNotifications`, `listenerState`, `clearLog`, `snapshotActive`), `LoggedNotification`, `ListenerState`, `CaptureEvent`, `NotificationDisposition` (milestone 3); `PendingPaymentRepository.forceCapture`; `CaptureHost.updateLog` (`ChannelCaptureHost`, milestone 3 Task 5).
- Produces:
  - `enum LogFilter { all, postedOnly, waiting, skipped }` and `List<LoggedNotification> filterLog(List<LoggedNotification> rows, LogFilter f)` — the rules of `NotificationDebugUiState.filteredNotifications`.
  - `class NotificationLogViewModel extends ChangeNotifier { NotificationLogViewModel(AppServices s, {Duration poll = const Duration(seconds: 2), Duration reconnectWait = const Duration(seconds: 65)}); bool get isAccessGranted, isConnected; ListenerState get listenerState; List<LoggedNotification> get shown; LogFilter get filter; String? get message; Future<void> refresh(); Future<void> reconnect(); void setFilter(LogFilter f); Future<void> clearLog(); Future<void> snapshot(); Future<void> markAsPayment(LoggedNotification n); void dismissMessage(); }` — texts of `NotificationDebugViewModel.kt` (`Reconnecting…`, `Notification access was removed — re-enable in system settings.`, `Reconnect already attempted recently.`, `Reconnect failed — open notification access settings.`, `Listener connected.`, `Still disconnected — use the alert notification or open notification access settings.`, `Log cleared`, `Snapshotted active status-bar notifications`, `Listener not connected — toggle notification access off/on, then try again`, `No RM amount in this text. Add the payment by hand.`); `markAsPayment` true → `updateLog(n.id, NotificationDisposition.waiting, 'Added as a card. Check it on the Home screen.')`. It polls `recentNotifications` and `listenerState` every `poll` while it lives (Decision 4; mark it with a `ponytail:` comment).
  - `routes.dart`: `Future<void> openNotificationLog(BuildContext context)`.
  - `NotificationLogScreen` — layout of `NotificationDebugScreen.kt`: title `Notification log`, Back, `Refresh` icon button; the status card (`Notification access not granted` / `Access granted, listener not connected` / `Listener active`; `Captured $n · listener connected` + ` · last connected MMM d, HH:mm:ss`; buttons `Reconnect listener`, `Snapshot`, `Clear log`); filter chips `All`, `Posted`, `Waiting`, `Skipped`; one card per row (`$package · $event · $time`, title, body, `Posted $time`, the disposition badge with the 0.1.1 label and color, the detail, `Add as payment` where 0.1.1 shows it); empty texts `No notifications captured yet. Make a payment or tap “Snapshot active notifications” after granting access.` and `No notifications match this filter.`

- [ ] **Step 1: Write the failing tests.** Listener channel answers 3 rows: WAITING (posted), SKIPPED_NO_RULE (posted, the text `Your statement is ready.`), INFO_ONLY (removed).

```dart
test('the filters follow the 0.1.1 rules', ...); // all 3; posted 2; waiting 1; skipped 1 (INFO_ONLY and PENDING are not skipped)
testWidgets('the log shows the status and the rows', ...); // 'Listener active', 'Captured 3 · listener connected', 'Waiting for check', 'No rule matched', 'Info'
testWidgets('the log shows new rows while it is open', ...); // change the answer to 4 rows, pump 2 s → 4 cards
testWidgets('Add as payment makes a card and marks the row', ...);
  // row with the milestone 3 Maybank text, SKIPPED_NO_RULE → tap 'Add as payment' → 1 pending card; capture channel got updateLog(id, 'WAITING', 'Added as a card. Check it on the Home screen.')
testWidgets('Add as payment for a text with no amount says so', ...); // 'No RM amount in this text. Add the payment by hand.'
testWidgets('Clear log and Snapshot show their result', ...);
testWidgets('Settings opens the log', ...);
testWidgets('the log meets the tap target guidelines and works at text scale 1.3', ...);
```

- [ ] **Step 2: Run.** `flutter test test/screens/notification_log_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (8 new tests).
- [ ] **Step 5: Commit.** "Add the notification log screen".

### Task 7: Onboarding and auto-open at start

**Files:**
- Create: `koban/lib/screens/onboarding/onboarding_rules.dart`, `koban/lib/screens/onboarding/onboarding_screen.dart`, `koban/lib/screens/onboarding/onboarding_view_model.dart`, `koban/lib/app/auto_open.dart`
- Modify: `koban/lib/app/routes.dart` (`openOnboarding`), `koban/lib/app/home_shell.dart` (run `AutoOpen` after the first frame and on each `AppLifecycleListener.onShow`)
- Test: `koban/test/screens/onboarding_rules_test.dart`, `koban/test/screens/onboarding_test.dart`, `koban/test/app/auto_open_test.dart`

**Interfaces:**
- Consumes: `ListenerControl` (`isAccessGranted`, `openAccessSettings`, `isBatteryOptimizationIgnored`, `openBatteryOptimizationSettings`, `isXiaomiFamily`, `openBackgroundSettings`), `DeviceControl` (`sdkInt`, `notificationsAllowed`, `shouldShowNotificationRationale`, `requestNotificationPermission`, `openAppNotificationSettings`, `openAppInfo`), `KobanSettings`, `PaymentChecks.watchVisibleCount`, `PaymentAppsScreen` (Task 4), `openCheckPayments`, `openPaymentApps`, `StepProgress`, `Mon`.
- Produces:
  - `enum OnboardingStep { welcome, access, blocked, apps, running, ready }` and `abstract final class OnboardingRules { static bool shouldShow({required bool done, required bool accessGranted, required bool paymentAppsChosen}); static bool blockedHelp(int sdkInt, {required bool openedSettings, required bool accessGranted}); static OnboardingStep afterSettings(OnboardingStep step, int sdkInt, {required bool accessGranted}); static OnboardingStep onResume(OnboardingStep step, int sdkInt, {required bool accessGranted, required bool openedSettings}); static int? stepNumber(OnboardingStep step); }` — `OnboardingRules.kt`.
  - `class OnboardingViewModel extends ChangeNotifier { OnboardingViewModel(AppServices s); OnboardingStep get step; void next(); void appsSaved(); void back(); void openedSettings(); Future<void> onResume(); Future<void> finish(); }` — `OnboardingViewModel.kt`.
  - `routes.dart`: `Future<void> openOnboarding(BuildContext context)`; `finish` pops to the first route.
  - `OnboardingScreen` — `OnboardingScreen.kt`: step names `Notification access`, `Payment apps`, `Keep it running`, `Ready` on `StepProgress(number, 4, name)`; the texts of each step (Welcome `Koban counts your spending for you.` and its 3 lines, `Get started`; Access `Let Koban see payment alerts` …, `Open settings`, `In the list, tap Koban, then turn on Allow.`; Blocked `Android blocked this` and its 3 numbered lines, `Open app info`, `Try again`; Apps = `PaymentAppsScreen(onSaved: vm.appsSaved, onBack: vm.back)`; Running `Keep Koban running` with the rows `Alerts` / `Tell me when tracking stops` / `Allow` (Android 13 and later), `Battery` / `No restrictions` / `Open settings`, `Autostart` / `Start Koban after a restart` / `Open settings` (Xiaomi only), the done icon label `$title done`, `Only the settings your phone needs show here.`, `Next`, `Skip for now`; Ready `Koban is ready`, its line, `Go to Home`). Back follows `vm.back()` and leaves the app only on Welcome. The Alerts button: after one request, when `shouldShowNotificationRationale` is false, it opens the app notification settings (0.1.1 rule).
  - `auto_open.dart`: `enum AutoOpenTarget { onboarding, paymentApps, checkPayments }` and `class AutoOpen { AutoOpen(AppServices s); Future<AutoOpenTarget?> decide(); }` — `AppViewModel.kt` order: onboarding when `shouldShow`; else payment apps when access is on and apps are not chosen; else Check payments when the visible count (a fresh read) is above 0. `HomeShell` acts only when the shell route is the top route.

- [ ] **Step 1: Write the failing tests.** Port `OnboardingRulesTest.kt` (19 cases) one to one.

```dart
// onboarding_test.dart — device channel: sdkInt 34, notificationsAllowed false
testWidgets('onboarding goes from Welcome to Notification access', ...); // 'Get started' → 'Step 1 of 4 · Notification access'
testWidgets('back from settings with access goes to the payment apps step', ...);
  // tap 'Open settings' → listener got 'openAccessSettings'; access answer true; resume → 'Payment apps'
testWidgets('back from settings without access on Android 14 shows the blocked help', ...); // 'Android blocked this', 'Open app info' → device got 'openAppInfo'
testWidgets('saving apps goes to Keep Koban running with the rows this phone needs', ...); // 'Alerts', 'Battery'; no 'Autostart'
testWidgets('Allow asks for the alerts permission, and the second time opens the settings', ...);
testWidgets('Go to Home stores onboarding as done and closes', ...); // prefs onboarding_done true; HomeShell on top

// auto_open_test.dart — Review Focus 5
testWidgets('a new user gets onboarding first', ...); // done false, access false, chosen false, 2 cards → onboarding
testWidgets('a user with access and no app choice gets the payment apps picker', ...);
testWidgets('a user with waiting cards gets Check payments', ...);
testWidgets('an existing user with access never gets onboarding', ...); // done false, access true, chosen true, 0 cards → nothing
testWidgets('auto-open runs again when the app comes back to the front', ...); // 0 cards; add 1; AppLifecycleState hidden → inactive (onShow) → 'Check payments'
testWidgets('auto-open does nothing while another page is open', ...);
```

- [ ] **Step 2: Run.** `flutter test test/screens/onboarding_* test/app/auto_open_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (31 new tests). Gradle test → BUILD SUCCESSFUL.
- [ ] **Step 5: Build once.** `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk` exists. Do not install it.
- [ ] **Step 6: Check the Kotlin app is untouched.** `git diff --stat main -- app/ gradle/` → empty.
- [ ] **Step 7: Commit.** "Add onboarding and the auto-open at app start".

## Known limits

- New cards from the capture engine show within about 2 s (Decision 2), not at once as in 0.1.1.
- The notification log refreshes every 2 s (Decision 4). The log stays in native memory, as milestone 3 says.
- The invite code check and the update check are milestone 5; their buttons open `OnlinePlaceholder`.
- No phone run in this plan. The device channel, the permission dialogs and the gallery first run in the owner device checks of plan 4c.
