# Flutter milestone 3: Android payment capture — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture payment notifications in the Flutter app as 0.1.1 does — with the app closed and after a restart — through the native Kotlin listener, a persistent native queue and a headless Dart engine that parses and saves.

**Architecture:** The listener and its helpers move to `koban/android/` as native Kotlin with the same package and class names. For each notification from a chosen app, the listener first writes a row to a small native SQLite queue (`capture_queue.db`), then wakes one headless `FlutterEngine` per process. That engine runs the Dart entry point `captureMain`, which pulls the rows over a method channel, runs `PaymentRules`, writes the card with Drift, and only then acknowledges the row. A row that is not acknowledged stays on disk, so a process death or restart does not lose it (guarantee 1), and the Dart dedup checks make a second delivery harmless (guarantee 2). One in-app Kotlin plugin (`KobanNativePlugin`) gives every engine the same channels, and a process-wide native gate lets only one isolate run the 0.1.1 import at a time.

**Tech Stack:** Flutter 3.50.0 / Dart 3.14.0; existing `drift` 2.35, `drift_flutter` 0.3.1, `shared_preferences` 2.5 (`SharedPreferencesAsync`); Android `SQLiteOpenHelper` and `SharedPreferences` (platform, no new library); Kotlin `androidx.core:core-ktx:1.15.0` (same as the Kotlin app); test-only Robolectric (newest stable 4.x that runs `@Config(sdk = [35])`) and `androidx.test:core`. No new pub package.

**Spec:** `docs/superpowers/specs/2026-11-13-flutter-migration-design.md` (sections 6.3 "Android payment capture", 6.4 step 4 "notification log", 6.7 item 3). Carry-over: `.superpowers/sdd/carry-over.md`, "Milestone 3 inputs".

**Decisions (the spec leaves these to the builder):**
1. **Background Dart: native queue + one headless engine (chosen).** Rejected: (a) send each notification straight over a channel to a running engine — a process death between the post and the save loses it, which breaks guarantee 1; (b) the `workmanager` plugin — a new dependency, the system can delay the work for minutes, and the data handoff still needs a store. The queue is about 120 lines of Kotlin and needs no plugin.
2. **Payment-app filter: native first, Dart again.** The listener reads a native copy of the list (`SharedPreferences` file `koban_capture`, key `payment_apps`). Dart owns the list in `SharedPreferencesAsync` (as milestone 2 writes it) and writes the copy on each engine start and on each change. Before the first copy exists (the first notification after the update, before any Dart code ran), the listener queues every app and Dart filters, so no payment is lost and the "log shows all apps until the list loads" rule of 0.1.1 stays. Native filtering keeps the text of other apps (chat messages) off the disk and does not wake Dart for them.
3. **Channels on every engine:** `KobanNativePlugin` is a `FlutterPlugin` added by `MainActivity.configureFlutterEngine` and by `CaptureEngine`. It owns the channels `io.github.skooyo.koban/legacy` (moved out of `MainActivity`), `io.github.skooyo.koban/capture` and `io.github.skooyo.koban/listener`. A local plugin package was rejected: it is a separate Gradle module and cannot see the listener classes in the app module.
4. **Import guard:** a native `ImportGate` (one per process; the UI engine and the capture engine are in the same process) gives the gate to one engine at a time, first come first served, and frees it when its engine detaches. A Dart file lock was rejected: POSIX locks belong to the process, so two isolates in one process do not block each other. The gate also covers the first open of the Drift database, so only one isolate creates the schema.
5. **Two isolates write one database:** each isolate keeps its own Drift connection (no `shareAcrossIsolates`: if the isolate that owns the shared connection dies with its engine, the other isolate loses the database). Drift starts native transactions with `BEGIN IMMEDIATE`, and every connection sets `PRAGMA busy_timeout = 5000`, so the dedup check and the insert of one capture are atomic across isolates.
6. **Sure and unsure payments:** the 0.1.1 code (`ExpenseNotificationListener.processForExpense` → `PendingPaymentRepository.capture`, commit 933785d) sends every rule match, `KNOWN` and `UNKNOWN`, to Check payments (`pending_payments`); no payment saves without a check. Spec 6.3 item 3 says "as today", so this plan ports that code one to one. The owner confirms this reading (see Known limits).
7. **Notification log:** stays the native in-memory `RecentNotificationsStore` (200 rows, as 0.1.1). Both engines are in one process, so both see the same log through the channels.

**Not in this milestone:** screens (milestone 4): the Check payments swipe (hold, undo, `saveConfirmed`, drop markers written on drop, merchant category on save, `flushHold` in `onStop`), the payment apps picker, onboarding (`POST_NOTIFICATIONS` request), the notification log screen, all UI text (`reconnectStatusMessage`, `xiaomiChecklist`). The updater and `UpdateInstallReceiver` (milestone 5). Milestone 3 gives milestone 4 these Dart APIs: `PendingPaymentRepository.watchWaiting` / `watchWaitingCount` / `forceCapture`, `PaymentApps.load` / `save`, `ListenerControl`, and `KobanDatabaseDedup.hasExpenseFor`.

## Global Constraints

- Work on branch `feature/flutter-m3`. `flutter` means `D:/flutter/bin/flutter`, `dart` means `D:/flutter/bin/dart`. Gradle: `cd koban/android && JAVA_HOME=D:/jdk-17 ./gradlew.bat --max-workers=2 :app:testDebugUnitTest`.
- Commit steps: the controller runs them. The implementer stops after the last verification step and reports the changed files.
- Run at most one Gradle or Flutter build or test run at a time.
- Each task ends with `flutter analyze` → "No issues found!" and `flutter test` → "All tests passed!" (from `koban/`), and, when Kotlin changed, the Gradle command above → BUILD SUCCESSFUL. Task 7 also runs `flutter build apk --debug`.
- No phone or emulator. Every check is a JVM/Robolectric test in `koban/android`, a Dart test, or the debug build. Device steps go to "Owner device checks".
- `git diff main -- app/ gradle/` stays empty. The Kotlin app is the reference. Do not change it.
- Component names stay byte for byte (Android stores notification access by component name): `com.expensetracker.app.listener.ExpenseNotificationListener`, `com.expensetracker.app.listener.ListenerKeepAliveService`, `com.expensetracker.app.listener.BootCompletedReceiver`, `com.expensetracker.app.listener.ListenerWatchdogReceiver`. `com.expensetracker.app.update.UpdateInstallReceiver` is kept for milestone 5. The Flutter `namespace` is `io.github.skooyo.koban`, so the manifest writes these names in full, never with a leading dot.
- Port the listener helpers line for line from `app/src/main/java/com/expensetracker/app/listener/`. Change only the imports (`io.github.skooyo.koban.R`, `io.github.skooyo.koban.BuildConfig`, `io.github.skooyo.koban.MainActivity`), the Hilt lookup, and the flow in `ExpenseNotificationListener.handleNotification` (Task 2). Values stay: watchdog 15 min (Xiaomi family 30 min), "soon" 5 s, health check 90 s, reconnect burst 0 / 2 / 5 / 15 / 30 / 60 s plus a check at +1.5 s, reconnect throttle 30 s, channel and notification ids, and the 10 strings in `app/src/main/res/values/strings.xml` lines 4 to 13.
- The parsing rules exist only in Dart (spec 6.3). Kotlin filters only by app, event, group summary and empty text. It never matches an amount.
- Spec 6.3 guarantees, verbatim: "1. no notification from a chosen app is lost when the app is closed or the phone restarts; 2. the same notification is never saved twice (`dedupKey`, as today); 3. sure payments save at once and unsure ones go to "Check payments", as today." Item 3 is read as Decision 6.
- A queue row is removed only after its card is committed, or after a final skip (`SKIPPED_ALLOWLIST`, `SKIPPED_NO_RULE`, `SKIPPED_DUPLICATE`) is decided. An error keeps the row.
- Capture writes through the milestone 2 database (`openKobanDatabase`) and its typed Drift API, so the formats stay: money TEXT with 2 decimals, enums as Kotlin constant names, booleans 0/1, times in ms.
- Dedup values, from the Kotlin code: amount window ±5 min (`300000` ms, inclusive), dedup key lookback 30 min (`DedupKeyGenerator.dedupLookbackMs()`), drop markers older than 30 days (`2592000000` ms) are deleted at each capture, forced key prefix `forced:`, drop key `"$notificationKey@$postTime"`.
- The repository is public: test texts are synthetic. Use the texts of `koban/test/rules/payment_rules_test.dart` (for example `Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.` from `com.maybank2u.life`). Never the owner's real notifications.
- New dependencies: only `androidx.core:core-ktx:1.15.0` (main), Robolectric and `androidx.test:core` (test). No new pub package.
- Doc comments and test names in ASD-STE100 Simplified Technical English.

## Review Focus

1. The process dies after the card is committed but before the queue row is acknowledged. The row comes again — it must give `SKIPPED_DUPLICATE`, not a second card. Pinned in Task 5.
2. Touch 'n Go uses one notification key for every payment. Two payments with the same key and other post times must both reach Check payments — in the queue's unique key and in the dedup checks. Pinned in Tasks 1 and 4.
3. The first payment after the update arrives before any Dart code ran (no native copy of the payment apps yet). It must be queued, and captured after the import copies the old list. Pinned in Tasks 2 and 6.
4. On the first start after the update, the UI and the capture engine open the database at the same time. The import must run one time, with no false "could not move your data" result. Pinned in Tasks 3 and 6.
5. The capture isolate and the UI isolate write the same file through two connections. The same payment must give one card and no "database is locked" error. Pinned in Task 4.

---

### Task 1: Native queue, payment-app copy and notification log

**Files:**
- Modify: `koban/android/app/build.gradle.kts`
- Create (in `koban/android/app/src/main/kotlin/com/expensetracker/app/listener/`): `CapturedNotification.kt` and `RecentNotificationsStore.kt` (ported verbatim), `CaptureQueue.kt`, `PaymentAppsMirror.kt`
- Test: `koban/android/app/src/test/kotlin/com/expensetracker/app/listener/CaptureQueueTest.kt`, `PaymentAppsMirrorTest.kt`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `CapturedNotification`, `NotificationCaptureEvent`, `NotificationDisposition`, `ListenerDebugState`, `RecentNotificationsStore` — same names and members as 0.1.1.
  - `data class QueuedNotification(val id: Long = 0, val logId: String, val packageName: String, val title: String?, val text: String, val postTime: Long, val notificationKey: String?, val attempts: Int = 0)`
  - `class CaptureQueue internal constructor(context: Context, name: String = "capture_queue.db") : SQLiteOpenHelper` with `companion object { const val MAX_ATTEMPTS = 5; fun get(context: Context): CaptureQueue }` (one per process), `fun add(item: QueuedNotification): Boolean` (false when the same post is in the queue), `fun take(afterId: Long, limit: Int = 20): List<QueuedNotification>` (rows with `id > afterId`, oldest first, `attempts` + 1 for each row it returns), `fun giveUp(): List<QueuedNotification>` (removes and returns rows with `attempts >= MAX_ATTEMPTS`), `fun remove(id: Long)`, `fun size(): Int`.
  - `object PaymentAppsMirror { fun read(context: Context): Set<String>?; fun write(context: Context, apps: Set<String>) }` — file `koban_capture`, key `payment_apps`, `commit()`. `null` means "never written".

- [ ] **Step 1: Gradle.** In `koban/android/app/build.gradle.kts` add `implementation("androidx.core:core-ktx:1.15.0")`, `testImplementation("org.robolectric:robolectric:<newest stable 4.x>")`, `testImplementation("androidx.test:core:<newest stable>")`, `buildFeatures { buildConfig = true }` and `testOptions { unitTests { isIncludeAndroidResources = true } }`.
- [ ] **Step 2: Write the failing tests.** Robolectric, `@Config(sdk = [35])`, a new `CaptureQueue(context, "test_queue.db")` per test.

```kotlin
@Test fun rowsComeBackOldestFirstAfterTheGivenId() {
    // add a (postTime 1), b (2), c (3)
    assertEquals(listOf("a", "b", "c"), q.take(afterId = 0).map { it.logId })
    val firstId = q.take(afterId = 0).first().id
    assertEquals(listOf("b", "c"), q.take(afterId = firstId).map { it.logId })
}
@Test fun theSamePostIsQueuedOnce() {
    assertTrue(q.add(row(key = "k1", postTime = 1000, text = "t")))
    assertFalse(q.add(row(key = "k1", postTime = 1000, text = "t")))
    assertEquals(1, q.size())
}
// Review Focus 2
@Test fun theSameKeyWithAnotherPostTimeIsANewRow() {
    assertTrue(q.add(row(key = "k1", postTime = 1000, text = "t")))
    assertTrue(q.add(row(key = "k1", postTime = 2000, text = "t")))
    assertEquals(2, q.size())
}
@Test fun rowsStayAfterTheQueueOpensAgain() {
    q.add(row(key = "k1", postTime = 1000, text = "RM 15.00")); q.close()
    val again = CaptureQueue(context, "test_queue.db")
    assertEquals(listOf("RM 15.00"), again.take(0).map { it.text })
}
@Test fun takeCountsTriesAndGiveUpRemovesTheRowAfterFive() {
    q.add(row(key = "k1", postTime = 1000, text = "t"))
    repeat(4) { q.take(0) }
    assertEquals(emptyList<QueuedNotification>(), q.giveUp())
    q.take(0)
    assertEquals(listOf(5), q.giveUp().map { it.attempts })
    assertEquals(0, q.size())
}
@Test fun removeDeletesOneRow() { /* add 2, remove the first id, size == 1 */ }
```

```kotlin
// PaymentAppsMirrorTest
@Test fun readIsNullBeforeTheFirstWrite() = assertNull(PaymentAppsMirror.read(context))
@Test fun writeThenReadGivesTheSameSet() {
    PaymentAppsMirror.write(context, setOf("com.maybank2u.life", "my.com.tngdigital.ewallet"))
    assertEquals(setOf("com.maybank2u.life", "my.com.tngdigital.ewallet"), PaymentAppsMirror.read(context))
}
@Test fun anEmptySetIsNotNull() {
    PaymentAppsMirror.write(context, emptySet())
    assertEquals(emptySet<String>(), PaymentAppsMirror.read(context))
}
```

- [ ] **Step 3: Run.** Gradle test → FAIL (`CaptureQueue` not defined).
- [ ] **Step 4: Implement.** Copy `CapturedNotification.kt` and `RecentNotificationsStore.kt` without change. `CaptureQueue` table `queue(id INTEGER PRIMARY KEY AUTOINCREMENT, logId TEXT NOT NULL, packageName TEXT NOT NULL, title TEXT, text TEXT NOT NULL, postTime INTEGER NOT NULL, notificationKey TEXT, uniqueKey TEXT NOT NULL UNIQUE, attempts INTEGER NOT NULL DEFAULT 0)`; `uniqueKey = "${notificationKey ?: packageName}|$postTime|${text.hashCode()}"`; `add` uses `insertWithOnConflict(..., CONFLICT_IGNORE)` and returns `rowId != -1L`; `take` selects and updates `attempts` in one transaction. If native SQLite fails under Robolectric on Windows, add `@SQLiteMode(SQLiteMode.Mode.LEGACY)` to the test class.
- [ ] **Step 5: Run.** Gradle test → BUILD SUCCESSFUL (9 new tests). `flutter analyze`; `flutter test` → PASS.
- [ ] **Step 6: Commit.** "Add the native capture queue and the payment-app copy".

### Task 2: Listener, keep-alive, watchdog and boot in the Flutter app

**Files:**
- Create (in `koban/android/app/src/main/kotlin/com/expensetracker/app/listener/`): `ExpenseNotificationListener.kt`, `NotificationListenerBridge.kt`, `ListenerKeepAliveService.kt`, `ListenerWatchdog.kt`, `ListenerReconnectScheduler.kt`, `ListenerDisconnectNotifier.kt`, `NotificationAccessHelper.kt`, `OemBatteryHelper.kt`, `BootCompletedReceiver.kt`, `CaptureSignal.kt`; `koban/android/app/src/main/kotlin/io/github/skooyo/koban/KobanApplication.kt`; `koban/android/app/src/main/res/values/strings.xml`; `koban/android/app/src/main/res/drawable/ic_stat_koban.xml` (copy of `app/src/main/res/drawable/ic_stat_koban.xml`)
- Modify: `koban/android/app/src/main/AndroidManifest.xml`, `koban/android/app/src/main/kotlin/io/github/skooyo/koban/MainActivity.kt` (only the `EXTRA_RECONNECT_LISTENER` constant, so the notifier compiles)
- Test: `koban/android/app/src/test/kotlin/com/expensetracker/app/listener/ComponentNamesTest.kt`, `ExpenseNotificationListenerTest.kt`, `BootCompletedReceiverTest.kt`

**Interfaces:**
- Consumes: `CaptureQueue`, `PaymentAppsMirror`, `RecentNotificationsStore` (Task 1).
- Produces:
  - The 0.1.1 helpers with the same public functions: `NotificationAccessHelper.isNotificationAccessGranted / isListenerConnected / ensureListenerActive / reconnectListener: ReconnectResult / softReconnectListener / requestRebind / openNotificationAccessSettings / isBatteryOptimizationIgnored / openBatteryOptimizationSettings`, `OemBatteryHelper.isXiaomiFamily / openManufacturerBackgroundSettings: OpenResult`, `NotificationListenerBridge.isServiceConnected / refreshActiveNotifications`, `ListenerKeepAliveService.start / stop / sync`, `ListenerDisconnectNotifier.show / hide`.
  - `object CaptureSignal { @Volatile var wake: (Context) -> Unit = {}; fun wakeIfQueued(context: Context) }` — `wake` is the test seam; Task 3 sets the default to `CaptureEngine::wake`. `wakeIfQueued` calls `wake` when `CaptureQueue.get(context).size() > 0`.
  - `MainActivity.EXTRA_RECONNECT_LISTENER = "reconnect_listener"`.

- [ ] **Step 1: Write the failing tests.** Robolectric, `@Config(sdk = [35])`. Grant access with `Settings.Secure.putString(resolver, "enabled_notification_listeners", ComponentName(pkg, "com.expensetracker.app.listener.ExpenseNotificationListener").flattenToString())`. Set `CaptureSignal.wake = { wakes++ }` in `@Before`. Build each `StatusBarNotification` with a `Notification.Builder` title and text and an explicit post time.

```kotlin
// ComponentNamesTest — pkg = context.packageName
@Test fun listenerKeepsTheComponentNameOfTheKotlinApp() {
    val info = pm.getServiceInfo(ComponentName(pkg, "com.expensetracker.app.listener.ExpenseNotificationListener"), 0)
    assertEquals("android.permission.BIND_NOTIFICATION_LISTENER_SERVICE", info.permission)
    assertTrue(info.exported)
}
@Test fun serviceAndReceiversKeepTheirNames() {
    assertFalse(pm.getServiceInfo(ComponentName(pkg, "com.expensetracker.app.listener.ListenerKeepAliveService"), 0).exported)
    assertTrue(pm.getReceiverInfo(ComponentName(pkg, "com.expensetracker.app.listener.BootCompletedReceiver"), 0).exported)
    assertFalse(pm.getReceiverInfo(ComponentName(pkg, "com.expensetracker.app.listener.ListenerWatchdogReceiver"), 0).exported)
}
@Test fun bootReceiverGetsBootAndUpdate() {
    for (action in listOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED)) {
        val names = pm.queryBroadcastReceivers(Intent(action).setPackage(pkg), 0).map { it.activityInfo.name }
        assertEquals(action, listOf("com.expensetracker.app.listener.BootCompletedReceiver"), names)
    }
}
```

```kotlin
// ExpenseNotificationListenerTest — listener = Robolectric.buildService(ExpenseNotificationListener::class.java).create().get()
@Test fun paymentFromAChosenAppIsQueuedLoggedAndWakesDart() {
    PaymentAppsMirror.write(context, setOf("com.maybank2u.life"))
    listener.onNotificationPosted(sbn("com.maybank2u.life", key = "k1", postTime = 1000, text = "Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456."))
    val row = queue.take(0).single()
    assertEquals("Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.", row.text)
    assertEquals(1000L, row.postTime)
    assertEquals(NotificationDisposition.PENDING, RecentNotificationsStore.snapshot().single().disposition)
    assertEquals(row.logId, RecentNotificationsStore.snapshot().single().id)
    assertEquals(1, wakes)
}
@Test fun anAppThatIsNotChosenIsNotQueuedOrLogged() { /* mirror {maybank}; post from com.example.chat → queue 0, log 0, wakes 0 */ }
// Review Focus 3
@Test fun beforeTheFirstCopyEveryAppIsQueuedAndLogged() { /* mirror never written; post from com.example.bank → queue 1, log 1, wakes 1 */ }
@Test fun theSamePostTwiceIsQueuedOnce() {
    // post the same sbn two times
    assertEquals(1, queue.size())
    assertEquals(listOf(NotificationDisposition.SKIPPED_DUPLICATE, NotificationDisposition.PENDING),
        RecentNotificationsStore.snapshot().map { it.disposition })
    assertEquals("Already processing this notification", RecentNotificationsStore.snapshot().first().detail)
}
// Review Focus 2
@Test fun theSameKeyWithANewPostTimeIsQueuedAgain() { /* key k1, postTime 1000 and 2000 → queue 2, wakes 2 */ }
@Test fun groupSummaryAndRemovedAreLoggedOnly() {
    // FLAG_GROUP_SUMMARY post → SKIPPED_GROUP_SUMMARY "Group summary notification";
    // onNotificationRemoved → INFO_ONLY "Removed from status bar"; queue 0, wakes 0
}
```

```kotlin
// BootCompletedReceiverTest
@Test fun bootWithAccessStartsKeepAliveAndTheWatchdog() {
    grantAccess(); BootCompletedReceiver().onReceive(context, Intent(Intent.ACTION_BOOT_COMPLETED))
    assertEquals("com.expensetracker.app.listener.ListenerKeepAliveService", shadowOf(app).nextStartedService.component!!.className)
    val alarm = shadowOf(alarmManager).nextScheduledAlarm!!
    assertEquals(15 * 60 * 1000L, alarm.triggerAtTime - System.currentTimeMillis(), 1000.0)
}
@Test fun bootWithoutAccessStartsNothing() { /* nextStartedService null, nextScheduledAlarm null */ }
@Test fun bootWakesDartOnlyWhenRowsWait() { /* empty queue → wakes 0; one row → wakes 1 */ }
```

- [ ] **Step 2: Run.** Gradle test → FAIL (classes not defined).
- [ ] **Step 3: Port the helpers.** Copy the 8 files listed under Files except the listener and `CaptureSignal`, line for line (Global Constraints). Copy the 10 strings. `KobanApplication : android.app.Application` calls `NotificationAccessHelper.ensureListenerActive(this)` in `onCreate` (as `ExpenseTrackerApp`). `BootCompletedReceiver` also calls `CaptureSignal.wakeIfQueued(context.applicationContext)` (queued rows from before a restart).
- [ ] **Step 4: Write the listener.** Keep the 0.1.1 lifecycle (`onCreate`, `onDestroy`, `onListenerConnected`, `onListenerDisconnected`, `captureActiveNotifications`, `extractText`) and remove Hilt, the coroutine scope and `processingKeys`. `onListenerConnected` also calls `CaptureSignal.wakeIfQueued(this)`. `handleNotification(sbn, event)` becomes:
  1. `watched = PaymentAppsMirror.read(this)`; a log row is written only when `watched == null || sbn.packageName in watched` (0.1.1 rule: "Only watched apps go in the log").
  2. Null payload, `REMOVED`, group summary and empty text: log as in 0.1.1 (same dispositions and detail texts) and return.
  3. `watched != null && sbn.packageName !in watched`: return.
  4. Log `PENDING` "Processing…" with the title and parse text; `CaptureQueue.get(this).add(...)` with that log id, `sbn.key`, `sbn.postTime` and the parse text. On `false`, update the log row to `SKIPPED_DUPLICATE` "Already processing this notification" and return.
  5. `CaptureSignal.wake(this)`.
  The parse text rule stays: the trimmed body, or title + body when the body is blank.
- [ ] **Step 5: Manifest.** Copy the permissions `RECEIVE_BOOT_COMPLETED`, `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, and the `service` / `receiver` blocks of `app/src/main/AndroidManifest.xml` for the 4 listener components (with the `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` property), with full class names. Set `android:name="io.github.skooyo.koban.KobanApplication"`. `INTERNET`, `REQUEST_INSTALL_PACKAGES` and `UpdateInstallReceiver` wait for milestone 5.
- [ ] **Step 6: Run.** Gradle test → BUILD SUCCESSFUL (12 new tests). `flutter analyze`; `flutter test` → PASS.
- [ ] **Step 7: Commit.** "Move the payment listener and its helpers into the Flutter app".

### Task 3: One plugin for every engine, the import gate and the capture engine

**Files:**
- Create: `koban/android/app/src/main/kotlin/io/github/skooyo/koban/KobanNativePlugin.kt`, `koban/android/app/src/main/kotlin/io/github/skooyo/koban/ImportGate.kt`, `koban/android/app/src/main/kotlin/com/expensetracker/app/listener/CaptureEngine.kt`
- Modify: `MainActivity.kt` (same folder as the plugin), `CaptureSignal.kt`
- Test: `koban/android/app/src/test/kotlin/io/github/skooyo/koban/ImportGateTest.kt`, `KobanNativePluginTest.kt`

**Interfaces:**
- Consumes: Task 1 (`CaptureQueue`, `PaymentAppsMirror`, `RecentNotificationsStore`), Task 2 (helpers), `LegacySettingsReader.read(File)` (milestone 2).
- Produces:
  - `class KobanNativePlugin(executor: Executor = Executors.newSingleThreadExecutor()) : FlutterPlugin` with `fun register(context: Context, messenger: BinaryMessenger)` (called by `onAttachedToEngine`; test seam), `fun requestDrain()` (sends `drain` on the capture channel). `onDetachedFromEngine` calls `ImportGate.forget(this)`. Disk work runs on `executor`; replies go back on the main thread.
  - `object ImportGate { fun acquire(owner: Any, onGranted: () -> Unit); fun release(owner: Any); fun forget(owner: Any) }` — one holder at a time, waiters in arrival order; `forget` frees the gate when `owner` holds it and drops the waits of `owner`.
  - `object CaptureEngine { fun wake(context: Context) }` — main thread. The first call in a process starts the Flutter loader, makes `FlutterEngine(appContext)` (generated plugins register by themselves), adds a `KobanNativePlugin`, and runs `DartEntrypoint(findAppBundlePath(), "captureMain")`. Later calls call `requestDrain()`. The engine lives as long as the process.
  - Channel `io.github.skooyo.koban/legacy`: `databasePath`, `readSettings` — same results and error code `LEGACY_SETTINGS` as milestone 2.
  - Channel `io.github.skooyo.koban/capture` (Dart → native): `takeQueue {afterId: int}` → `List<Map>` with keys `id, logId, packageName, title, text, postTime, notificationKey` (first, each row from `giveUp()` gets its log row set to `SKIPPED_ERROR` "Gave up after 5 tries"); `finish {id, logId, disposition, detail}` (removes the row, updates the log); `updateLog {logId, disposition, detail}`; `appendLog {title, body, disposition, detail}` (a new log row with `packageName` = the app's package, `postTime` = now); `setPaymentApps {apps: List<String>}`; `acquireImportGate` (replies when granted); `releaseImportGate`. Native → Dart: `drain` (no arguments).
  - Channel `io.github.skooyo.koban/listener` (for milestone 4): `isAccessGranted` → bool, `isConnected` → bool, `ensureActive`, `reconnect` → `ReconnectResult` name, `openAccessSettings`, `isBatteryOptimizationIgnored` → bool, `openBatteryOptimizationSettings`, `isXiaomiFamily` → bool, `openBackgroundSettings` → `OemBatteryHelper.OpenResult` name, `recentNotifications` → `List<Map>` (keys `id, packageName, title, body, postTime, capturedAt, event, disposition, detail`; enums as names), `listenerState` → `Map` (keys `isConnected, lastConnectedAt, lastDisconnectedAt, totalCaptured`), `clearLog`, `snapshotActive` → bool.

- [ ] **Step 1: Write the failing tests.**

```kotlin
// ImportGateTest — plain JUnit
@Test fun theFirstOwnerGetsTheGateAtOnce() { ImportGate.acquire(a) { log += "a" }; assertEquals(listOf("a"), log) }
@Test fun theNextOwnerWaitsUntilRelease() {
    ImportGate.acquire(a) { log += "a" }; ImportGate.acquire(b) { log += "b" }
    assertEquals(listOf("a"), log)
    ImportGate.release(a)
    assertEquals(listOf("a", "b"), log)
}
@Test fun aDetachedOwnerFreesTheGateAndDropsItsWait() {
    ImportGate.acquire(a) { log += "a" }; ImportGate.acquire(b) { log += "b" }; ImportGate.acquire(c) { log += "c" }
    ImportGate.forget(b); ImportGate.forget(a)
    assertEquals(listOf("a", "c"), log)
}
// @After: release every owner, so the tests do not share a held gate.
```

```kotlin
// KobanNativePluginTest — Robolectric; FakeMessenger implements BinaryMessenger, keeps the handlers by
// channel name, and sends StandardMethodCodec calls to them; executor = Executor { it.run() };
// idle the main looper before each reply check.
@Test fun registersTheThreeChannelsOnAnyEngine() {
    KobanNativePlugin(direct).register(context, messenger)
    assertEquals(setOf("io.github.skooyo.koban/legacy", "io.github.skooyo.koban/capture", "io.github.skooyo.koban/listener"), messenger.handlers.keys)
}
@Test fun takeQueueGivesRowsAndFinishRemovesThem() {
    // queue: one maybank row with logId L (and a PENDING log row L)
    val rows = messenger.call("io.github.skooyo.koban/capture", "takeQueue", mapOf("afterId" to 0L)) as List<Map<String, Any?>>
    assertEquals("com.maybank2u.life", rows.single()["packageName"])
    messenger.call(CAPTURE, "finish", mapOf("id" to rows.single()["id"], "logId" to "L", "disposition" to "WAITING", "detail" to "RESTORAN CONTOH · RM 15.00"))
    assertEquals(0, queue.size())
    assertEquals(NotificationDisposition.WAITING, RecentNotificationsStore.snapshot().single().disposition)
}
@Test fun takeQueueGivesUpARowAfterFiveTries() { /* row taken 5 times → next takeQueue returns [] and log detail "Gave up after 5 tries" */ }
@Test fun setPaymentAppsWritesTheNativeCopy() { /* apps [a, b] → PaymentAppsMirror.read == {a, b} */ }
@Test fun readSettingsAnswersWithTheErrorCodeWhenAFileIsCorrupt() { /* write garbage to filesDir/datastore/settings.preferences_pb → error code "LEGACY_SETTINGS" */ }
```

- [ ] **Step 2: Run.** Gradle test → FAIL.
- [ ] **Step 3: Implement.** Move the legacy channel code from `MainActivity` into the plugin (use the application context; keep the `catch (e: Throwable)` and its comment). `MainActivity`: `configureFlutterEngine` only adds `KobanNativePlugin()`; `onCreate` and `onNewIntent` call `NotificationAccessHelper.reconnectListener(this)` when the intent has `EXTRA_RECONNECT_LISTENER` true (the launch mode is `singleTop`); `onResume` calls `ensureListenerActive(this)`, `ListenerDisconnectNotifier.hide(this)` when the listener is connected, and `CaptureSignal.wakeIfQueued(this)`. Set `CaptureSignal.wake` default to `CaptureEngine::wake`. `CaptureEngine` is not unit-tested (it needs the Flutter native library); Task 7 builds it and the owner checks it on a phone.
- [ ] **Step 4: Run.** Gradle test → BUILD SUCCESSFUL (8 new tests). `flutter analyze`; `flutter test` → PASS (`legacy_source_test.dart` still passes: same channel name and methods).
- [ ] **Step 5: Commit.** "Give every Flutter engine the native channels and add the capture engine".

### Task 4: Capture store in Dart (dedup and the waiting card)

**Files:**
- Create: `koban/lib/data/capture_queries.drift`, `koban/lib/data/pending_payment_repository.dart`, `koban/lib/data/expense_dedup.dart`, `koban/lib/data/ids.dart`
- Modify: `koban/lib/data/database.dart` (add `'capture_queries.drift'` to `include`), `koban/lib/data/database.g.dart` (generated), `koban/lib/data/open_database.dart` (add `configureConnection` only)
- Test: `koban/test/data/pending_payment_repository_test.dart`, `koban/test/data/ids_test.dart`

**Interfaces:**
- Consumes: `KobanDatabase` and its tables (milestone 2); `PaymentRules.match`, `Matched`, `ParsedExpense`, `DedupKeyGenerator.generate` / `dedupLookbackMs`, `AmountFormatter.toMoney` / `formatDisplay`, `CaptureFormat`, `TransactionType` (milestone 1).
- Produces:
  - `capture_queries.drift`: named queries that copy the Room `@Query` text of `ExpenseDao.findByNotificationKey`, `findByDedupKeySince`, `findByAmountInWindow` and `PendingPaymentDao.findByKeys`, `findByAmountInWindow`, `findDropped`, `deleteDroppedBefore`, `observeAll` (`ORDER BY createdAt ASC`).
  - `ids.dart`: `String newId()` — a random version 4 UUID in the form of Java `UUID.randomUUID().toString()`, from `Random.secure()`.
  - `expense_dedup.dart`: `const amountDedupWindowMs = 300000;` `const forcedDedupPrefix = 'forced:';` `extension KobanDatabaseDedup on KobanDatabase { Future<bool> hasExpenseFor({required Decimal amount, required TransactionType transactionType, required String? merchant, required int postTime, required String dedupKey, required String? notificationKey}) }` — the order and rules of Kotlin `ExpenseRepository.hasExpenseFor` (milestone 4 reuses it for `saveConfirmed`).
  - `pending_payment_repository.dart`: `class PendingPaymentRepository { PendingPaymentRepository(KobanDatabase db, {int Function()? now}); Future<String?> capture({required ParsedExpense parsed, required CaptureFormat format, required String rawText, required String sourcePackage, required int notificationPostTime, required String? notificationKey}); Future<bool> forceCapture({required String sourcePackage, required String rawText, required int notificationPostTime}); Stream<List<PendingPayment>> watchWaiting(); Stream<int> watchWaitingCount(); }` — `capture` returns the new card id, or null for a duplicate; it runs the Kotlin steps (delete old drop markers, `hasExpenseFor`, `findByKeys`, `findByAmountInWindow` with `matchMerchant` only for `RECEIVE`, `findDropped` with the drop key, insert) inside one `db.transaction`. Card values: as Kotlin `insertCard` (`categoryId` null, `likelyPromotion` false, `edited` false, `directionUnclear = !parsed.directionClear`, `createdAt = now()`).
  - `open_database.dart`: `void configureConnection(Database db)` — runs `PRAGMA busy_timeout = 5000`. Top-level, because Drift sends it to the background isolate.

- [ ] **Step 1: Write the failing tests.** `db = KobanDatabase(NativeDatabase.memory(setup: configureConnection))`, `now = () => T` with `T = 1762000000000`, `P = T - 60000`, `repo = PendingPaymentRepository(db, now: () => T)`. A helper inserts expenses through the typed API.

```dart
test('a new payment becomes a waiting card in the Room formats', () async {
  final id = await repo.capture(parsed: rm15, format: CaptureFormat.known, rawText: qrText,
      sourcePackage: maybank, notificationPostTime: P, notificationKey: 'k1');
  final row = await db.customSelect('SELECT * FROM pending_payments').getSingle();
  expect(row.data, {
    'id': id, 'amount': '15.00', 'currency': 'MYR', 'merchant': 'RESTORAN CONTOH',
    'transactionType': 'WITHDRAW', 'sourcePackage': maybank, 'rawNotificationText': qrText,
    'notificationPostTime': P, 'notificationKey': 'k1',
    'dedupKey': DedupKeyGenerator.generate(packageName: maybank, amount: Decimal.parse('15.00'), merchant: 'RESTORAN CONTOH', postTime: P),
    'format': 'KNOWN', 'categoryId': null, 'likelyPromotion': 0, 'createdAt': T, 'edited': 0, 'directionUnclear': 0,
  });
});
test('an expense with the same notification key and post time blocks the card', ...); // → null, 0 cards
// Review Focus 2
test('the same notification key with another post time makes a new card', ...); // expense k1 at P - 600000 → card made
test('a dismissed expense does not block by notification key or amount', ...);
  // DISMISSED expense 15.00 WITHDRAW, key 'k1', post time P, dedupKey 'other' → a card
test('an expense with the same dedup key blocks only from 30 minutes before the post time', () async {
  // expense dedupKey = the key of rm15 at P; notificationPostTime P - 1740000 → null
  // same, but notificationPostTime P - 1800001 → a card
});
test('the same amount and direction within 5 minutes blocks a spend from another app', ...);
  // expense 15.00 WITHDRAW from my.com.tngdigital.ewallet at P + 300000 → null; at P + 300001 → card
test('a receive is blocked only by the same sender', ...);
  // expense 50.00 RECEIVE merchant 'ALI' at P; capture RECEIVE 'ALI' → null; 'MEI' → card
test('a waiting card with the same keys or the same amount blocks a second card', ...);
test('a dropped payment does not come back', ...);
  // drop marker dedupKey == key → null; marker notificationKey 'k1@$P' with another dedupKey → null
test('drop markers older than 30 days are deleted at capture', ...);
  // marker droppedAt T - 2592000001 → capture makes a card and the marker is gone; T - 2592000000 stays
test('a text with no clear direction makes a card with directionUnclear 1', ...);
test('force capture skips every check and uses a forced key', () async {
  // an expense covers the payment already
  expect(await repo.forceCapture(sourcePackage: maybank, rawText: qrText, notificationPostTime: P), true);
  // the card dedupKey startsWith 'forced:', notificationKey null
});
test('force capture returns false when the text has no amount', ...); // 'Your statement is ready.'
test('waiting cards come oldest first', ...); // watchWaiting().first: createdAt ascending
// Review Focus 5
test('two connections that capture the same payment at once make one card', () async {
  // a and b: KobanDatabase(NativeDatabase.createInBackground(file, setup: configureConnection)) on one temp file
  final ids = await Future.wait([repoA.capture(...same...), repoB.capture(...same...)]);
  expect(ids.whereType<String>().length, 1);
  expect((await a.customSelect('SELECT COUNT(*) AS n FROM pending_payments').getSingle()).data['n'], 1);
});
```

```dart
// ids_test.dart
test('new ids have the form of a Java random UUID', () {
  final ids = List.generate(100, (_) => newId());
  for (final id in ids) {
    expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
  }
  expect(ids.toSet().length, 100);
});
```

- [ ] **Step 2: Run.** `flutter test test/data/pending_payment_repository_test.dart test/data/ids_test.dart` → FAIL.
- [ ] **Step 3: Implement.** Write the queries; let Drift map the `:amount` variable through `MoneyConverter`, so a `Decimal` compares as text (`'15.00'`). Generate: `dart run build_runner build --delete-conflicting-outputs`. Write the rest. `schema_test.dart` must still pass: the queries do not change a table.
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (16 new tests).
- [ ] **Step 5: Commit.** "Port the capture dedup checks and the waiting card to Dart".

### Task 5: Capture host, worker and payment apps in Dart

**Files:**
- Create: `koban/lib/capture/capture_host.dart`, `koban/lib/capture/capture_worker.dart`, `koban/lib/capture/payment_apps.dart`
- Modify: `koban/lib/data/legacy_import.dart` (rename `_describe` to public `describeError`, no other change)
- Test: `koban/test/capture/fake_capture_host.dart`, `koban/test/capture/capture_host_test.dart`, `koban/test/capture/capture_worker_test.dart`, `koban/test/capture/payment_apps_test.dart`

**Interfaces:**
- Consumes: the capture channel protocol (Task 3); `PendingPaymentRepository` (Task 4); `PaymentRules`, `AmountFormatter`.
- Produces:
  - `enum NotificationDisposition { pending('PENDING'), waiting('WAITING'), skippedAllowlist('SKIPPED_ALLOWLIST'), skippedNoRule('SKIPPED_NO_RULE'), skippedDuplicate('SKIPPED_DUPLICATE'), skippedGroupSummary('SKIPPED_GROUP_SUMMARY'), skippedEmpty('SKIPPED_EMPTY'), skippedError('SKIPPED_ERROR'), infoOnly('INFO_ONLY') }` with `dbName` and `fromDbName`, as in `types.dart`.
  - `class QueuedNotification { final int id; final String logId; final String packageName; final String? title; final String text; final int postTime; final String? notificationKey; }`
  - `abstract interface class CaptureHost { Future<List<QueuedNotification>> takeQueue(int afterId); Future<void> finish(QueuedNotification row, NotificationDisposition d, String detail); Future<void> updateLog(String logId, NotificationDisposition d, String detail); Future<void> appendLog(String title, String body, NotificationDisposition d, String detail); Future<void> setPaymentApps(Set<String> apps); Future<void> acquireImportGate(); Future<void> releaseImportGate(); void onDrain(Future<void> Function() handler); }` and `class ChannelCaptureHost implements CaptureHost` on `io.github.skooyo.koban/capture`.
  - `class PaymentApps { PaymentApps(SharedPreferencesAsync prefs, CaptureHost? host); Future<Set<String>> load(); Future<void> save(Set<String> apps); Future<void> syncToNative(); }` — key `payment_app_allowlist` (sorted list); `save` also sets `payment_apps_chosen` true (as Kotlin `setPaymentApps`), then calls `host.setPaymentApps`; `syncToNative` sends `load()` (an empty set when the key is missing).
  - `class CaptureWorker { CaptureWorker({required CaptureHost host, required PendingPaymentRepository payments, required PaymentApps paymentApps}); Future<void> drain(); }`

`drain` rules: load the payment apps one time per run. Loop: `takeQueue(afterId)` until it is empty; `afterId` = the last id of the batch. A `drain` call during a run sets a flag; the run then continues from its `afterId` (new rows have higher ids; failed rows wait for the next wake). For each row, in this order, with the 0.1.1 detail texts:
1. App not in the set, or the set is empty → `finish(skippedAllowlist, 'Package not on allowlist')`.
2. `PaymentRules.match` is `NoMatch` → `finish(skippedNoRule, 'No rule matched this text')`.
3. `capture(...)` gives an id → `finish(waiting, '${merchant ?? 'Unknown'} · RM ${AmountFormatter.formatDisplay(amount)}')`; null → `finish(skippedDuplicate, 'Duplicate within dedup window')`.
4. An error → `updateLog(row.logId, skippedError, describeError(e))`; no `finish`; continue with the next row.

- [ ] **Step 1: Write the failing tests.** `FakeCaptureHost` keeps `queue` (a list; `finish` removes the row), `finished` (list of `(id, dbName, detail)`), `logUpdates` (`(logId, dbName, detail)`), `appended` (`(title, body, dbName, detail)`), `paymentApps` (null until set), a FIFO gate with `bool gateHeld`, and `Future<void> triggerDrain()` (calls the `onDrain` handler, as a native `drain` call does). Worker tests use an in-memory database and `InMemorySharedPreferencesAsync.empty()`.

```dart
test('a payment from a chosen app becomes a card and the log says WAITING', () async {
  // prefs payment_app_allowlist [maybank]; queue [row(1, maybank, qrText, postTime P, key 'k1')]
  await worker.drain();
  expect(host.finished, [(1, 'WAITING', 'RESTORAN CONTOH · RM 15.00')]);
  expect(await countPending(db), 1);
});
test('an app that is not chosen is skipped and acknowledged', ...); // [(1, 'SKIPPED_ALLOWLIST', 'Package not on allowlist')], 0 cards
test('no chosen apps skips every app', ...);
test('a text with no amount is skipped and acknowledged', ...); // 'Your statement is ready.' → SKIPPED_NO_RULE
// Review Focus 1
test('a row that comes again after a crash makes one card', () async {
  // drain with row 1; put the same row (same id and values) in the queue again; drain
  expect(host.finished.map((f) => f.$2), ['WAITING', 'SKIPPED_DUPLICATE']);
  expect(host.finished.last.$3, 'Duplicate within dedup window');
  expect(await countPending(db), 1);
});
test('a save error keeps the row in the queue', () async {
  // close the database before drain
  expect(host.queue.map((r) => r.id), [1]);
  expect(host.finished, isEmpty);
  expect(host.logUpdates.single.$2, 'SKIPPED_ERROR');
});
test('rows that arrive during a drain are handled in the same run, each one time', () async {
  // the fake adds rows 2 and 3 to the queue when takeQueue(1) runs; call drain() two times without await
  expect(host.finished.map((f) => f.$1), [1, 2, 3]);
});
```

```dart
// payment_apps_test.dart
test('saving payment apps writes the settings and the native copy', () async {
  await apps.save({'my.com.tngdigital.ewallet', 'com.maybank2u.life'});
  expect(await prefs.getStringList('payment_app_allowlist'), ['com.maybank2u.life', 'my.com.tngdigital.ewallet']);
  expect(await prefs.getBool('payment_apps_chosen'), true);
  expect(host.paymentApps, {'com.maybank2u.life', 'my.com.tngdigital.ewallet'});
});
test('sync sends an empty set when no apps are chosen', ...); // host.paymentApps == <String>{}

// capture_host_test.dart — mock the channel with setMockMethodCallHandler
test('queue rows from the channel become typed rows', ...); // takeQueue(0) sends {'afterId': 0}; a map → QueuedNotification with the same values
test('finish sends the row id, log id, disposition name and detail', ...);
test('a drain call from native runs the handler', ...); // handleMockMessage of 'drain' → handler called 1 time
```

- [ ] **Step 2: Run.** `flutter test test/capture/` → FAIL.
- [ ] **Step 3: Implement** the three files and the rename.
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (12 new tests).
- [ ] **Step 5: Commit.** "Parse and save queued notifications in Dart".

### Task 6: Capture entry point, guarded import and the listener API

**Files:**
- Create: `koban/lib/capture/capture_main.dart`, `koban/lib/capture/listener_control.dart`
- Modify: `koban/lib/data/open_database.dart`, `koban/lib/main.dart` (add `captureMain` only)
- Test: `koban/test/data/open_database_test.dart`, `koban/test/capture/capture_main_test.dart`, `koban/test/capture/listener_control_test.dart`

**Interfaces:**
- Consumes: `importLegacyData`, `ImportResult` with `logLine` (milestone 2); `CaptureHost`, `CaptureWorker`, `PaymentApps` (Task 5); `PendingPaymentRepository`, `configureConnection` (Task 4); fixtures `test/fixtures/room_v11.db`, `fixtureCounts`, `rowCountsOf` (milestone 2).
- Produces:
  - `open_database.dart`: `Future<ImportResult> openAndImport({required KobanDatabase db, required Future<ImportResult> Function() runImport, required CaptureHost host, required PaymentApps paymentApps})` — `acquireImportGate`; inside the gate, open the database (`SELECT 1`, which creates the schema) and run the import; `releaseImportGate` in `finally`; when `logLine` is not null, `appendLog('Data import', logLine, skippedError, '')`; then `paymentApps.syncToNative()`. `openKobanDatabase()` keeps its signature and its per-isolate cache; it opens `driftDatabase(name: 'koban', native: const DriftNativeOptions(setup: configureConnection))` (the same file as milestone 2) and calls `openAndImport` with `ChannelCaptureHost` on Android; on iPhone it returns `ImportSkipped` with no gate.
  - `capture_main.dart`: `Future<CaptureWorker> runCapture({required CaptureHost host, required Future<(KobanDatabase, ImportResult)> Function() open, required SharedPreferencesAsync prefs})` — opens, makes the worker, calls `host.onDrain(worker.drain)`, then `await worker.drain()` (rows queued before Dart was ready).
  - `main.dart`: `@pragma('vm:entry-point') Future<void> captureMain() async` — `WidgetsFlutterBinding.ensureInitialized()`, `DartPluginRegistrant.ensureInitialized()`, then `runCapture(host: ChannelCaptureHost(), open: openKobanDatabase, prefs: SharedPreferencesAsync())`. It is in `main.dart` because `DartEntrypoint(path, "captureMain")` looks in the root library.
  - `listener_control.dart` (milestone 4 calls it): `enum ReconnectResult { accessNotGranted, attempted, throttled, failed }`, `enum BackgroundSettingsResult { xiaomiAutostart, xiaomiOther, genericBattery }`, `enum CaptureEvent { posted, removed, activeSnapshot }` (each with the Kotlin `dbName`), `class LoggedNotification` (the 9 log keys), `class ListenerState` (the 4 keys), and `class ListenerControl` with one method for each `io.github.skooyo.koban/listener` method of Task 3: `isAccessGranted()`, `isConnected()`, `ensureActive()`, `reconnect()`, `openAccessSettings()`, `isBatteryOptimizationIgnored()`, `openBatteryOptimizationSettings()`, `isXiaomiFamily()`, `openBackgroundSettings()`, `recentNotifications()`, `listenerState()`, `clearLog()`, `snapshotActive()`.

- [ ] **Step 1: Write the failing tests.**

```dart
// open_database_test.dart — FakeCaptureHost from Task 5; KobanDatabase on a temp file with configureConnection
test('the import runs inside the gate and the gate opens after an error', () async {
  // runImport records host.gateHeld, then throws StateError('x')
  await expectLater(openAndImport(...), throwsStateError);
  expect(seenGateHeld, true);
  expect(host.gateHeld, false);
});
test('a failed import goes to the notification log', () async {
  // runImport returns ImportFailed(['owed_items'], 'x')
  expect(host.appended, [('Data import', 'Data import failed: owed_items (x)', 'SKIPPED_ERROR', '')]);
});
test('a settings error goes to the notification log', ...); // ImportDone({}, settingsError: 'y') → body 'Settings import failed (y)'
test('a clean import writes no log row', ...);
test('the payment apps go to native after the import', ...); // runImport writes the allowlist to prefs → host.paymentApps == that set
// Review Focus 4
test('two opens at the same time import the 0.1.1 data one time', () async {
  // copy room_v11.db to a temp folder; two KobanDatabase connections on one new file;
  // one FakeCaptureHost gate shared by both; each runImport calls the real importLegacyData
  // with a fake LegacySource on that copy and one shared InMemorySharedPreferencesAsync
  final results = await Future.wait([openAndImport(...a...), openAndImport(...b...)]);
  expect(results.whereType<ImportDone>().length, 1);
  expect(results.whereType<ImportSkipped>().length, 1);
  expect(await rowCountsOf(a), fixtureCounts);
});
```

```dart
// capture_main_test.dart — Review Focus 3
test('a row queued before Dart started is captured after the import', () async {
  // host queue: [row(1, 'com.maybank2u.life', qrText)]; native copy never written;
  // open = openAndImport with this host, and runImport = the real importLegacyData on a copy of the
  // fixture (its settings hold the allowlist [com.maybank2u.life, my.com.tngdigital.ewallet]); returns (db, result)
  await runCapture(host: host, open: open, prefs: prefs);
  expect(host.paymentApps, {'com.maybank2u.life', 'my.com.tngdigital.ewallet'});
  expect(host.finished.single.$2, 'WAITING');
  expect((await rowCountsOf(db))['pending_payments'], 3); // 2 from the fixture + 1
});
test('a drain call after start runs the worker', ...); // host.triggerDrain() with a new row → finished has 2 rows

// listener_control_test.dart — mock io.github.skooyo.koban/listener
test('reconnect gives the native result', ...); // 'THROTTLED' → ReconnectResult.throttled
test('the log comes back as typed rows', ...); // one map → LoggedNotification with event posted, disposition waiting, the same text and times
```

- [ ] **Step 2: Run.** `flutter test test/data/open_database_test.dart test/capture/` → FAIL.
- [ ] **Step 3: Implement.** Keep the `openKobanDatabase` doc comment rule: every entry point gets the database only from here.
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (10 new tests).
- [ ] **Step 5: Commit.** "Start capture in a background Dart entry point and guard the import".

### Task 7: Branch check

**Files:** none new.

- [ ] **Step 1: Run everything, one at a time.** `cd koban && flutter analyze && flutter test` → "No issues found!" and "All tests passed!". Then the Gradle command → BUILD SUCCESSFUL.
- [ ] **Step 2: Build once.** `flutter build apk --debug` → `koban/build/app/outputs/flutter-apk/app-debug.apk` exists. Do not install it.
- [ ] **Step 3: Check the built manifest.** `D:/Android/build-tools/<newest>/aapt2 dump xmltree --file AndroidManifest.xml koban/build/app/outputs/flutter-apk/app-debug.apk` → the output holds each of the 4 component names of the Global Constraints in full, `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE`, `android.intent.action.BOOT_COMPLETED`, `android.intent.action.MY_PACKAGE_REPLACED` and `notification_listener_keepalive`.
- [ ] **Step 4: Check the Kotlin app is untouched.** `git diff --stat main -- app/ gradle/` → empty; `git status --short app/` → empty.
- [ ] **Step 5: Draft the map note** for issue #20 (3 to 5 lines, STE): capture moved with the same component names, the native queue keeps notifications across process death, Dart parses and saves, the device checks are with the owner. The controller posts it.
- [ ] **Step 6: Commit and push** only if the owner allowed it for this run.

## Known limits

- Decision 6: every rule match goes to Check payments, as the 0.1.1 code does. If the owner wants sure (`KNOWN`) payments to save at once, that is a change from 0.1.1 and needs its own decision; the worker is the one place to change.
- The notification log stays in memory, as in 0.1.1: a process death clears it, and with it the import log line. Rows that come again from the queue after a restart have no log row. Milestone 4 shows `importFailedMessage` on screen.
- Notifications that the system posts while the listener is not bound are not captured, as in 0.1.1: the active-notification snapshot at connect only goes to the log.
- The capture engine lives as long as the process (about 20 to 40 MB more memory). If OEM task killers stop the process more often, a later release stops the engine after some idle minutes.
- The payment-app copy is written after the Dart write. If the native write fails, the copy is old until the next engine start. If the 0.1.1 settings could not be read (`ImportDone.settingsError`), the list is empty and capture skips every app; the settings retry is already on the "Before milestone 6" carry-over list.
- No device run in this milestone. `CaptureEngine`, the `MainActivity` channel registration and the `catch (e: Throwable)` path first run in the owner device checks.
- `UpdateInstallReceiver`, `INTERNET` and `REQUEST_INSTALL_PACKAGES` come in milestone 5. CI runs only the Dart tests; the Kotlin tests run locally in Tasks 1 to 3 and 7.

## Owner device checks

Both debug builds have the app ID `io.github.skooyo.koban.debug` and the same debug key, so step 2 tests the real update path. About 20 minutes.

1. On a test phone, install the 0.1.1 debug build (`./gradlew.bat --max-workers=2 :app:installDebug` from the repository root), turn on notification access, choose Touch 'n Go and Maybank, and close the app.
2. Install the Flutter build over it: `adb install -r koban/build/app/outputs/flutter-apk/app-debug.apk`. Do not open it. Check that access is still on: `adb shell cmd notification list_listeners` shows `io.github.skooyo.koban.debug/com.expensetracker.app.listener.ExpenseNotificationListener`, and the "Tracking payment notifications" notification shows.
3. With Koban not open, make a small real payment (for example RM 1 by Touch 'n Go). Then: `adb exec-out run-as io.github.skooyo.koban.debug cat app_flutter/koban.sqlite > koban.sqlite` (also `koban.sqlite-wal` if it exists) and `sqlite3 koban.sqlite "SELECT amount, merchant FROM pending_payments"` → the payment is there one time.
4. Restart the phone. Do not open Koban. Make a second small payment and repeat step 3 → two rows; the old 0.1.1 rows are in `expenses` (import done, `databases/expense_tracker.db.pre-flutter` exists).
5. `adb logcat -d -s ExpenseNotification` → no "Failed" lines; `adb logcat -d | grep -i MissingPluginException` → nothing.
