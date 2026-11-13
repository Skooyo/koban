# Flutter milestone 2: database and data import — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Flutter app the same 11-table database as Room version 11, and an import that copies a friend's 0.1.1 database and 8 settings into it once, tested against files that the real 0.1.1 Kotlin code wrote.

**Architecture:** Drift owns the new database. The 11 tables are written as SQL in `koban/lib/data/schema.drift`, copied from the `CREATE TABLE` statements of a real Room v11 file, so names, types and indexes are the same. The import (`koban/lib/data/legacy_import.dart`) reads the old file read-only with `package:sqlite3` and copies the rows by column name in one Drift transaction. A native Kotlin reader in `koban/android/` reads the two DataStore files and sends the values to Dart over a method channel. The import stores the settings with `SharedPreferencesAsync`.

**Tech Stack:** Flutter 3.50.0 / Dart 3.14.0, `drift` (2.32 or later) with `drift_dev` and `build_runner`, `drift_flutter`, `sqlite3` (3.x, SQLite comes through build hooks, so no `sqlite3_flutter_libs`), `shared_preferences` (`SharedPreferencesAsync`), `path`; Kotlin `androidx.datastore:datastore-preferences:1.1.1` and JUnit 4.13.2 in `koban/android/`; Robolectric only in a temporary test in `app/`.

**Spec:** `docs/superpowers/specs/2026-11-13-flutter-migration-design.md` (sections 6.2 "Data", 6.4 "Data import", 6.7 item 2).

**Not in this milestone:** DAO queries move with their callers (capture in milestone 3, screens in milestone 4). Seeding the default categories (`CategoryRepository.seedIfEmpty`) is milestone 4. No screen shows the import result yet; milestone 4 shows `importFailedMessage`. The import keeps the old `group_session` JSON; milestone 5 gives its refresh token to `supabase_flutter`. No state management or dependency injection library: milestone 2 has no widget that needs one, so milestone 4 picks it.

## Global Constraints

- Work on branch `feature/flutter-m2`. `flutter` means `D:/flutter/bin/flutter`, `dart` means `D:/flutter/bin/dart`. Gradle runs with `JAVA_HOME=D:/jdk-17` and `--max-workers=2`.
- Commit steps: the controller runs them. The implementer stops after the last verification step and reports the changed files.
- Run at most one Gradle or Flutter build or test run at a time. No step runs builds in parallel.
- Each task ends with `flutter analyze` → "No issues found!" and `flutter test` → "All tests passed!" (run from `koban/`).
- `koban/lib/rules/` stays pure Dart (the purity test guards it). Database code goes in `koban/lib/data/`, which may import Drift, `dart:io` and Flutter services.
- Schema: "the same 11 tables, columns and meanings as Room version 11, so the import is a copy, not a conversion" (spec 6.2). Every table, column (name, declared type, NOT NULL, default, primary key, column order) and index equals a fresh Room v11 file. Drift `schemaVersion` starts at 1.
- Stored formats equal Room's: money is TEXT from `AmountFormatter.toMoney(v)` with exactly 2 decimals (`"12.50"`, never `"12.5"`); enums are TEXT with the Kotlin constant name (`dbName` / `fromDbName` in `koban/lib/rules/types.dart`); booleans are INTEGER 0 or 1; times are INTEGER milliseconds.
- The import copies stored values without change. It never parses and writes back a value.
- Failure text, verbatim: `Koban could not move your data. Your data is safe. Update again later.`
- Old file names: `databases/expense_tracker.db`; on success it becomes `expense_tracker.db.pre-flutter`. Do not delete it.
- `git diff main -- app/ gradle/` stays empty at the end of every task. Delete every temporary Kotlin file before the task ends.
- The repository is public: fixture tokens are fake (`test-...`), never real ones.
- Doc comments and test names in ASD-STE100 Simplified Technical English.

## Review Focus

1. The old app was killed by the update, so its last rows are only in `expense_tracker.db-wal` — the import must copy them, and the rename must move `-wal` (and `-shm`, `-journal` if present) with the main file, or `.pre-flutter` loses them. Pinned in Task 5.
2. The owner's database was migrated from version 1, so its columns are in another order than a fresh Room file and some have extra `DEFAULT`s — the copy must go by column name. Pinned in Task 5.
3. Amount text must stay byte-identical (`"12.50"`, `"-0.02"`), because DAO queries in later milestones compare `amount` as TEXT. Pinned in Tasks 1 and 5.
4. The import fails or the app stops after the commit, the friend uses the app, and the import runs again — no duplicate rows, no lost new rows, old rows win on the same key, and settings the friend changed later stay. Pinned in Task 5.
5. The old file has another `user_version`, a missing table or cannot open — no partial import, the old file stays, the result names the tables. Pinned in Task 5.

---

### Task 1: Parked fix, packages and type converters

**Files:**
- Modify: `koban/test/rules/people_math_test.dart:107`, `koban/pubspec.yaml`, `koban/analysis_options.yaml`, `koban/lib/rules/types.dart`, `koban/test/rules/types_test.dart`
- Create: `koban/lib/data/converters.dart`
- Test: `koban/test/data/converters_test.dart`

**Interfaces:**
- Consumes: `AmountFormatter.toMoney(Decimal) → Decimal` (milestone 1); the `dbName` / `fromDbName` pattern in `types.dart`.
- Produces:
  - `types.dart`: `enum DebtStatus { open('OPEN'), paid('PAID') }` with `dbName` and `static DebtStatus fromDbName(String)`, same pattern as the other enums.
  - `converters.dart`: `class MoneyConverter extends TypeConverter<Decimal, String>`; `class TransactionTypeConverter`, `ParseConfidenceConverter`, `ExpenseStatusConverter`, `CaptureFormatConverter`, `DebtStatusConverter`, each `extends TypeConverter<E, String>` through `dbName` / `fromDbName`; all `const` constructors.

- [ ] **Step 1: Fix the parked finding.** In `koban/test/rules/people_math_test.dart` line 107, replace the literal U+00A0 character with the escape `\u00a0`. The line becomes `PeopleMath.normalizedName('Ali\u00a0Bin'),`; line 108 keeps the plain space. Check: `grep -nP "\xA0" koban/test/rules/people_math_test.dart` prints nothing.
- [ ] **Step 2: Add packages.** In `koban/`: `flutter pub add drift drift_flutter sqlite3 shared_preferences path` and `flutter pub add dev:drift_dev dev:build_runner dev:shared_preferences_platform_interface`. Use the versions pub resolves; drift must be 2.32 or later and sqlite3 3.x. Do not add `sqlite3_flutter_libs`. In `analysis_options.yaml`, add `lib/**/*.g.dart` to `analyzer.exclude`.
- [ ] **Step 3: Write the failing tests.**

```dart
// koban/test/rules/types_test.dart (add)
test('debt status names equal the Kotlin constants', () {
  expect(DebtStatus.values.map((e) => e.dbName), ['OPEN', 'PAID']);
  for (final e in DebtStatus.values) {
    expect(DebtStatus.fromDbName(e.dbName), e);
  }
  expect(() => DebtStatus.fromDbName('open'), throwsArgumentError);
});

// koban/test/data/converters_test.dart
test('money is stored as text with 2 decimals like Kotlin', () {
  const c = MoneyConverter();
  expect(c.toSql(Decimal.parse('12.5')), '12.50');
  expect(c.toSql(Decimal.parse('1234')), '1234.00');
  expect(c.toSql(Decimal.parse('-0.02')), '-0.02');
  expect(c.toSql(Decimal.parse('0.005')), '0.01');
  expect(c.toSql(Decimal.parse('-0.005')), '-0.01');
  expect(c.fromSql('12.50'), Decimal.parse('12.50'));
  expect(c.fromSql('7'), Decimal.parse('7.00'));
});
test('enum converters store the Kotlin constant names', () {
  expect(const ExpenseStatusConverter().toSql(ExpenseStatus.autoSaved), 'AUTO_SAVED');
  expect(const ExpenseStatusConverter().fromSql('DISMISSED'), ExpenseStatus.dismissed);
  expect(const TransactionTypeConverter().toSql(TransactionType.receive), 'RECEIVE');
  expect(const ParseConfidenceConverter().fromSql('LOW'), ParseConfidence.low);
  expect(const CaptureFormatConverter().toSql(CaptureFormat.unknown), 'UNKNOWN');
  expect(const DebtStatusConverter().fromSql('PAID'), DebtStatus.paid);
});
```

- [ ] **Step 4: Run.** `flutter test test/rules/types_test.dart test/data/converters_test.dart` → FAIL (`DebtStatus`, `MoneyConverter` not defined).
- [ ] **Step 5: Implement.** Add `DebtStatus` to `types.dart`. Write `converters.dart`: `MoneyConverter.toSql(v)` = `AmountFormatter.toMoney(v).toStringAsFixed(2)` (same as Kotlin `toMoney(it).toPlainString()`); `fromSql(s)` = `AmountFormatter.toMoney(Decimal.parse(s))`.
- [ ] **Step 6: Run.** `flutter analyze` → "No issues found!"; `flutter test` → "All tests passed!" (3 new tests).
- [ ] **Step 7: Commit.** "Add Drift packages and the Room value converters".

### Task 2: Test files written by the real 0.1.1 code

**Files:**
- Create (temporary, deleted in Step 6): `app/src/test/java/com/expensetracker/app/data/LegacyFixtureExport.kt`; temporary lines in `app/build.gradle.kts`
- Create (kept): `koban/test/fixtures/room_v11.db`, `koban/android/app/src/test/resources/legacy/datastore/settings.preferences_pb`, `koban/android/app/src/test/resources/legacy/datastore/secrets.preferences_pb`, `koban/test/fixtures/README.md`
- Test: `koban/test/data/fixture_test.dart`

**Interfaces:**
- Consumes: the Kotlin `ExpenseDatabase` (Room 2.6.1, version 11), its DAOs, and `SettingsRepository` from `app/`, unchanged.
- Produces: the fixture files above, with exactly the rows and settings listed in Step 2. Tasks 3, 4 and 5 rely on these values.

- [ ] **Step 1: Add Robolectric for this task only.** In `app/build.gradle.kts`, add `testImplementation("org.robolectric:robolectric:<newest stable 4.x with SDK 35>")` and `testImplementation("androidx.test:core:<newest stable>")` as plain strings (no change to `gradle/libs.versions.toml`).
- [ ] **Step 2: Write `LegacyFixtureExport.kt`.** One `@Test` under `@RunWith(RobolectricTestRunner::class)` and `@Config(sdk = [35])`. Build the database with `Room.databaseBuilder(context, ExpenseDatabase::class.java, "expense_tracker.db").build()` and insert through the real DAOs inside `runBlocking`. Call `SettingsRepository(context)` setters for the settings. Rows (fixed ids and times; times in ms, `T = 1762000000000`):

| Table | Rows |
|---|---|
| `expenses` (4) | `e1`: 12.50 MYR, merchant `KEDAI Café ☕`, raw `Pembayaran RM\u00a012.50 kepada KEDAI Café ☕ berjaya`, source `my.com.tngdigital.ewallet`, post `T`, created `T+500`, dedup `dk-e1`, AUTO_SAVED, HIGH, notificationKey `nk-1`, category `food`, notes null, WITHDRAW, countedAmount null, private false. `e2`: 1234.00, merchant null, EDITED, MEDIUM, notificationKey null, category null, notes `Dinner with Ali`, WITHDRAW, countedAmount 411.33, private true. `e3`: 50.00, merchant `Ali Bin Abu`, DISMISSED, LOW, RECEIVE. `e4`: 0.01 SGD. Each row gets its own dedupKey `dk-eN`. |
| `categories` (8) | the 7 rows of `DefaultCategories.all` + `c-custom`, `Kopi`, `#123456`, isDefault false |
| `merchant_category_map` (2) | `kedai cafe` → `KEDAI Café ☕`, `food`, `T+1000`; `grab` → `Grab`, `transport`, `T+2000` |
| `pending_payments` (2) | `p1`: 18.40, merchant `Grab`, WITHDRAW, KNOWN, notificationKey `nk-p1`, category `transport`, likelyPromotion false, edited false, directionUnclear false. `p2`: 5.00, merchant null, RECEIVE, UNKNOWN, notificationKey null, category null, likelyPromotion true, edited true, directionUnclear true |
| `dropped_notifications` (2) | (`dk-d1`, `nk-d1`, `T`); (`dk-d2`, null, `T`) |
| `split_bills` (2) | `b1`: merchant `Nasi Kandar`, printedTotal 30.00, service 3.00, tax 1.80, discount 0.00, rounding -0.02, linkedExpenseId `e1`, manual false. `b2`: merchant null, printedTotal null, all charges 0.00, linkedExpenseId null, manual true |
| `split_items` (2) | `i1` (b1, `Nasi lemak`, qty 2, 12.00, position 0); `i2` (b1, `Teh tarik`, qty 1, 3.20, position 1) |
| `split_people` (2) | `s1`: `Ali Bin Abu`, qrPath `/data/user/0/io.github.skooyo.koban/files/qr/s1.img`, archived false, suggestedSettleExpenseId `e3`. `s2`: `Mei\u00a0Ling`, qrPath null, archived true, suggested null |
| `split_item_shares` (3) | (i1, s1), (i1, s2), (i2, s1) |
| `split_debts` (2) | `d1`: b1, s1, 10.00, OPEN, repayment null, suggested `e3`, paidAt null. `d2`: b2, s2, 25.50, PAID, repayment `e3`, suggested null, paidAt `T+100000000` |
| `owed_items` (2) | `o1`: s1, `Movie ticket`, 18.00, OPEN, paidAt null. `o2`: s2, `Parking`, 2.50, PAID, paidAt `T+3000` |
| `settings` | `setPaymentApps(setOf("my.com.tngdigital.ewallet", "com.maybank2u.life"))` (also sets `payment_apps_chosen` true), `setOnboardingDone()`, `setDarkMode(false)`, `setOnlineFeatures(false)`, `setLastUpdateCheck(1762300000000)` |
| `secrets` | `setDeviceToken("test-device-token-0001")`, `setGroupSession("""{"access_token":"test-access","refresh_token":"test-refresh-0001","expires_at":1762303600,"user_id":"00000000-0000-0000-0000-000000000001"}""")` |

  Then close the database (so no `-wal` file holds rows) and copy `context.getDatabasePath("expense_tracker.db")` to `../koban/test/fixtures/room_v11.db`, and `filesDir/datastore/settings.preferences_pb` and `secrets.preferences_pb` to `../koban/android/app/src/test/resources/legacy/datastore/` (the unit test working folder is `app/`).
- [ ] **Step 3: Run it once.** From the repository root: `./gradlew.bat --max-workers=2 testDebugUnitTest --tests "*LegacyFixtureExport*"`. Expected: BUILD SUCCESSFUL and the 3 files exist. If native SQLite fails on Windows, add `@SQLiteMode(SQLiteMode.Mode.LEGACY)`; both modes write a real SQLite file.
- [ ] **Step 4: Write `koban/test/data/fixture_test.dart`.**

```dart
// setUp: db = sqlite3.open('test/fixtures/room_v11.db', mode: OpenMode.readOnly); tearDown: db.close()
test('the fixture is a Room version 11 file with every table filled', () {
  expect(db.select('PRAGMA user_version').first.columnAt(0), 11);
  expect(rowCounts(db), fixtureCounts);
  expect(fixtureCounts, {
    'expenses': 4, 'categories': 8, 'merchant_category_map': 2,
    'pending_payments': 2, 'dropped_notifications': 2, 'split_bills': 2,
    'split_items': 2, 'split_people': 2, 'split_item_shares': 3,
    'split_debts': 2, 'owed_items': 2,
  });
});
test('the fixture holds every enum value', () {
  // distinct values, sorted
  expect(distinct(db, 'expenses', 'status'), ['AUTO_SAVED', 'DISMISSED', 'EDITED']);
  expect(distinct(db, 'expenses', 'confidence'), ['HIGH', 'LOW', 'MEDIUM']);
  expect(distinct(db, 'expenses', 'transactionType'), ['RECEIVE', 'WITHDRAW']);
  expect(distinct(db, 'pending_payments', 'format'), ['KNOWN', 'UNKNOWN']);
  expect(distinct(db, 'split_debts', 'status'), ['OPEN', 'PAID']);
  expect(distinct(db, 'owed_items', 'status'), ['OPEN', 'PAID']);
  expect(db.select("SELECT amount FROM expenses WHERE id = 'e1'").first['amount'], '12.50');
});
```

  Put the helpers in `koban/test/data/test_db.dart`: `const Map<String, int> fixtureCounts` (the 11 counts, 31 rows), `Map<String, int> rowCounts(Database db)` and `List<Object?> distinct(Database db, String table, String column)` (sorted). Task 5 adds `Future<Map<String, int>> rowCountsOf(KobanDatabase db)` to the same file.
- [ ] **Step 5: Write `koban/test/fixtures/README.md`** (5 lines or fewer): what the files are, that a temporary Robolectric test in `app/` wrote them with the 0.1.1 code on the base commit, the row table lives in this plan (Task 2), and the tokens are fake.
- [ ] **Step 6: Remove the temporary Kotlin code.** Delete `LegacyFixtureExport.kt`; run `git checkout -- app/build.gradle.kts`. Check: `git status --short app/ gradle/` and `git diff main -- app/ gradle/` both print nothing.
- [ ] **Step 7: Run.** `flutter analyze`; `flutter test` → PASS (2 new tests).
- [ ] **Step 8: Commit.** "Add test files written by the 0.1.1 Room and DataStore code".

### Task 3: Drift schema equal to Room version 11

**Files:**
- Create: `koban/lib/data/schema.drift`, `koban/lib/data/database.dart`, `koban/lib/data/database.g.dart` (generated, committed so CI needs no build step)
- Test: `koban/test/data/schema_test.dart`

**Interfaces:**
- Consumes: Task 1 converters; the fixture from Task 2.
- Produces: `class KobanDatabase extends _$KobanDatabase` with `KobanDatabase(QueryExecutor executor)` and `int get schemaVersion => 1`; the 11 tables with their Room names (`expenses`, `categories`, `merchant_category_map`, `pending_payments`, `dropped_notifications`, `split_bills`, `split_items`, `split_people`, `split_item_shares`, `split_debts`, `owed_items`) and their Room camelCase column names; `const legacyTableOrder = <String>[...]`, the 11 names in that order (the import copies and reports in this order).

- [ ] **Step 1: Write the failing tests.** Open the fixture read-only with `sqlite3` and the new database with `KobanDatabase(NativeDatabase.memory())`.

```dart
test('the new database has exactly the 11 Room tables', () async {
  // user tables: sqlite_master type 'table', minus sqlite_%, android_metadata, room_master_table
  expect(await userTables(newDb), userTables(fixture)); // both sorted
  expect(userTables(fixture).length, 11);
});
test('every table has the same columns as Room version 11', () async {
  for (final t in legacyTableOrder) {
    // rows of PRAGMA table_info(t): cid, name, type, notnull, dflt_value, pk
    expect(await tableInfo(newDb, t), tableInfo(fixture, t), reason: t);
  }
});
test('every index matches Room version 11', () async {
  for (final t in legacyTableOrder) {
    // PRAGMA index_list(t) -> (name, unique), plus PRAGMA index_info(name) columns, sorted by name
    expect(await indexes(newDb, t), indexes(fixture, t), reason: t);
  }
});
test('stored values use the Room formats', () async {
  // insert one expense through the typed Drift API:
  // amount Decimal.parse('12.5'), status ExpenseStatus.edited, confidence ParseConfidence.high,
  // transactionType TransactionType.withdraw, privateToGroups true, countedAmount null
  final row = await newDb.customSelect('SELECT amount, status, transactionType, privateToGroups, countedAmount FROM expenses').getSingle();
  expect(row.data, {'amount': '12.50', 'status': 'EDITED', 'transactionType': 'WITHDRAW', 'privateToGroups': 1, 'countedAmount': null});
});
```

- [ ] **Step 2: Run.** `flutter test test/data/schema_test.dart` → FAIL (`KobanDatabase` not defined).
- [ ] **Step 3: Write `schema.drift`.** Start from the `sql` column of `SELECT name, sql FROM sqlite_master` in the fixture (tables and `index_%` indexes); keep column order, types, `NOT NULL`, `DEFAULT`, `PRIMARY KEY` and index names as they are. Add `MAPPED BY` with the Task 1 converters to money and enum columns. For booleans, write the Dart type so the declared type stays `INTEGER` (if `BOOLEAN` changes `PRAGMA table_info.type`, use `INTEGER NOT NULL MAPPED BY` a small bool converter in `converters.dart`). Write `database.dart` with `@DriftDatabase(include: {'schema.drift'})`. Generate: `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (4 new tests).
- [ ] **Step 5: Commit.** "Add the Drift database with the Room version 11 schema".

### Task 4: Native settings reader and the method channel

**Files:**
- Create: `koban/android/app/src/main/kotlin/io/github/skooyo/koban/LegacySettingsReader.kt`, `koban/lib/data/legacy_source.dart`
- Modify: `koban/android/app/build.gradle.kts` (add `implementation("androidx.datastore:datastore-preferences:1.1.1")`, `testImplementation("junit:junit:4.13.2")`), `koban/android/app/src/main/kotlin/io/github/skooyo/koban/MainActivity.kt`
- Test: `koban/android/app/src/test/kotlin/io/github/skooyo/koban/LegacySettingsReaderTest.kt`, `koban/test/data/legacy_source_test.dart`

**Interfaces:**
- Consumes: the DataStore fixtures from Task 2.
- Produces:
  - Kotlin: `object LegacySettingsReader { fun read(dataStoreDir: File): Map<String, Any> }` — reads `settings.preferences_pb` and `secrets.preferences_pb` in `dataStoreDir` with the DataStore library; a string set becomes a sorted `List<String>`; a missing file adds nothing.
  - Channel `io.github.skooyo.koban/legacy` with methods `databasePath` → `String` (`getDatabasePath("expense_tracker.db").absolutePath`) and `readSettings` → `Map<String, Any>` (from `File(filesDir, "datastore")`), or error code `LEGACY_SETTINGS`.
  - Dart: `abstract interface class LegacySource { Future<String> databasePath(); Future<Map<String, Object?>> readSettings(); }` and `class ChannelLegacySource implements LegacySource` (values as `String`, `bool`, `int`, `List<String>`).

Test choice: a JVM unit test in `koban/android/`, not an instrumented check. Reason: the DataStore preferences reader is plain JVM code (no Android API), the fixture files come from the real 0.1.1 code, and the test runs in seconds with no phone or emulator. The `MainActivity` channel code (about 15 lines) first runs on a device in milestone 3.

- [ ] **Step 1: Write the failing tests.**

```kotlin
// LegacySettingsReaderTest.kt — copy resources/legacy/datastore to a TemporaryFolder first
@Test fun readsAllEightSettingsFromRealFiles() {
    assertEquals(
        mapOf(
            "payment_app_allowlist" to listOf("com.maybank2u.life", "my.com.tngdigital.ewallet"),
            "payment_apps_chosen" to true, "onboarding_done" to true, "dark_mode" to false,
            "online_features" to false, "last_update_check" to 1762300000000L,
            "device_token" to "test-device-token-0001",
            "group_session" to """{"access_token":"test-access","refresh_token":"test-refresh-0001","expires_at":1762303600,"user_id":"00000000-0000-0000-0000-000000000001"}""",
        ),
        LegacySettingsReader.read(dir),
    )
}
@Test fun returnsEmptyMapWhenNoFilesExist() {
    assertEquals(emptyMap<String, Any>(), LegacySettingsReader.read(tmp.newFolder("empty")))
}
```

```dart
// legacy_source_test.dart — mock the channel with
// TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler
test('channel values become Dart types', () async {
  // mock readSettings returns {'payment_app_allowlist': <Object?>['a', 'b'], 'dark_mode': false, 'last_update_check': 1762300000000}
  final s = await ChannelLegacySource().readSettings();
  expect(s['payment_app_allowlist'], isA<List<String>>());
  expect(s, {'payment_app_allowlist': ['a', 'b'], 'dark_mode': false, 'last_update_check': 1762300000000});
});
test('the database path comes from the channel', () async {
  // mock databasePath returns '/data/user/0/io.github.skooyo.koban/databases/expense_tracker.db'
  expect(await ChannelLegacySource().databasePath(), '/data/user/0/io.github.skooyo.koban/databases/expense_tracker.db');
});
```

- [ ] **Step 2: Run.** `cd koban/android && ./gradlew.bat --max-workers=2 :app:testDebugUnitTest` → FAIL (`LegacySettingsReader` not defined). Then `flutter test test/data/legacy_source_test.dart` → FAIL.
- [ ] **Step 3: Implement.** `read`: for each file, `PreferenceDataStoreFactory.create(scope = CoroutineScope(Dispatchers.IO + SupervisorJob()), produceFile = { file })`, `runBlocking { store.data.first() }`, then cancel the scope. Skip a file that does not exist. A corrupt file throws; do not catch it. In `MainActivity.configureFlutterEngine`, register the channel; run `readSettings` on a background thread and answer on the main thread. Write `legacy_source.dart`.
- [ ] **Step 4: Run.** Gradle test → BUILD SUCCESSFUL, 2 tests. Then `flutter analyze`; `flutter test` → PASS (2 new Dart tests).
- [ ] **Step 5: Commit.** "Read the 0.1.1 settings natively and send them to Dart".

### Task 5: The import and the startup gate

**Files:**
- Create: `koban/lib/data/legacy_import.dart`, `koban/lib/data/open_database.dart`
- Test: `koban/test/data/legacy_import_test.dart` (uses `test_db.dart` from Task 2)

**Interfaces:**
- Consumes: `KobanDatabase`, `legacyTableOrder` (Task 3); `LegacySource` (Task 4); `fixtureCounts`, `rowCounts` (Task 2).
- Produces:
  - `const importFailedMessage = 'Koban could not move your data. Your data is safe. Update again later.';`
  - `const legacySettingKeys` = the 8 keys; `const importDoneKey = 'legacy_import_done';`
  - `sealed class ImportResult`; `final class ImportSkipped`; `final class ImportDone(Map<String, int> rowCounts)`; `final class ImportFailed(List<String> tables, String detail)` with `String get logLine` = `'Data import failed: ${tables.join(', ')} ($detail)'` (milestone 3 writes it to the notification log).
  - `Future<ImportResult> importLegacyData({required KobanDatabase db, required LegacySource legacy, required SharedPreferencesAsync prefs})` — never throws.
  - `open_database.dart`: `Future<(KobanDatabase, ImportResult)> openKobanDatabase()` — opens `driftDatabase(name: 'koban')`, runs `importLegacyData` with `ChannelLegacySource` on Android (on iPhone the result is `ImportSkipped`), and keeps the `Future` in a static, so a second call in the same isolate returns the same result. Every entry point (screens in milestone 4, background capture in milestone 3) gets the database only from here.

`importLegacyData` steps, in this order:
1. If `prefs` has `importDoneKey` true: rename the old files if they still exist (step 7), return `ImportSkipped`.
2. If the file at `legacy.databasePath()` does not exist: return `ImportSkipped`.
3. Copy settings: for each key in `legacySettingKeys` that `readSettings()` returns and `prefs` does not already contain, write it with the matching setter (`setStringList`, `setBool`, `setInt`, `setString`). Settings go first so capture keeps the payment app list even if the table copy fails.
4. Open the old file with `sqlite3.open(path, mode: OpenMode.readOnly)` (this reads the `-wal` file too). If `PRAGMA user_version` is not 11: return `ImportFailed([], 'old database version N, needs 11')`.
5. In one `db.transaction`: for each table in `legacyTableOrder`, select the columns of the Drift table by name (`SELECT "a", "b" ... FROM t`) and write each row with `INSERT OR REPLACE` and the raw values. Then check: the number of old primary keys found in the new table equals the old row count. Catch the error of each table, collect the table names, and continue; at the end, if a name was collected, throw so Drift rolls back.
6. On success: set `importDoneKey` true.
7. Close the old connection. Rename `expense_tracker.db`, and `-wal`, `-shm`, `-journal` when they exist, to the same name with `.pre-flutter` after `.db` (`expense_tracker.db.pre-flutter-wal`, so SQLite finds the WAL when it opens the renamed file). Return `ImportDone(rowCounts)`.
A failure in any step returns `ImportFailed` with the table names (or `[]`) and the error text; the old file stays where it is.

- [ ] **Step 1: Write the failing tests.** Each test copies `test/fixtures/room_v11.db` to a new temp folder as `expense_tracker.db`, uses a file-backed `KobanDatabase(NativeDatabase(File(...)))`, a fake `LegacySource` (that path, and the 8 values of the Task 4 Kotlin test), and `SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty()`.

```dart
test('imports every row of a real 0.1.1 database', () async {
  expect(await run(), isA<ImportDone>());
  expect(await rowCountsOf(newDb), fixtureCounts); // the 11 counts of Task 2, 31 rows
  final e1 = await (newDb.select(newDb.expenses)..where((e) => e.id.equals('e1'))).getSingle();
  expect(e1.amount, Decimal.parse('12.50'));
  expect(e1.merchant, 'KEDAI Café ☕');
  expect(e1.rawNotificationText, 'Pembayaran RM\u00a012.50 kepada KEDAI Café ☕ berjaya');
  expect(e1.status, ExpenseStatus.autoSaved);
  // e2: countedAmount 411.33, privateToGroups true, merchant null; b1: rounding -0.02;
  // d2: status DebtStatus.paid, paidAt 1762100000000; p2: format CaptureFormat.unknown, directionUnclear true
});
test('copies stored values without change', () async {
  // for each table: SELECT * ORDER BY primary key, old file vs new database: equal row maps
});
test('copies the 8 settings and keeps the group session JSON as it is', () async {
  expect(await prefs.getStringList('payment_app_allowlist'), ['com.maybank2u.life', 'my.com.tngdigital.ewallet']);
  expect(await prefs.getBool('dark_mode'), false);
  expect(await prefs.getInt('last_update_check'), 1762300000000);
  expect(await prefs.getString('group_session'), groupSessionJson); // byte for byte
});
test('marks the import done and renames the old file', () async {
  await run();
  expect(await prefs.getBool('legacy_import_done'), true);
  expect(File('$dir/expense_tracker.db').existsSync(), false);
  expect(File('$dir/expense_tracker.db.pre-flutter').existsSync(), true);
  expect(await run(), isA<ImportSkipped>());
  expect((await rowCountsOf(newDb))['expenses'], 4);
});
test('finishes the rename when the mark is set but the old file is still there', () async {
  // prefs legacy_import_done = true, old file present -> ImportSkipped, file renamed, 0 rows copied
});
// Review Focus 1
test('copies rows that are only in the -wal file and moves the -wal file', () async {
  // writer on a separate copy of the fixture: journal_mode=WAL, wal_autocheckpoint=0, insert expense 'w1';
  // while the writer is open, copy its .db and -wal (not -shm) into the temp folder; then close the writer.
  // The read-only import connection makes its own -shm (the folder is writable, as on the phone).
  expect((await rowCountsOf(newDb))['expenses'], 5);
  expect(File('$dir/expense_tracker.db.pre-flutter-wal').existsSync(), true);
  // sqlite3.open('.pre-flutter', readOnly): SELECT COUNT(*) FROM expenses == 5
});
// Review Focus 2
test('copies by column name when the old columns are in another order', () async {
  // in the old copy, rebuild expenses with its columns in reverse order (CREATE new, INSERT SELECT, DROP, RENAME)
  // e1 after import: amount 12.50, dedupKey 'dk-e1', notificationKey 'nk-1', categoryId 'food'
});
// Review Focus 4
test('a second import keeps new rows and lets old rows win on the same key', () async {
  // before: new database holds the 7 default categories with 'food' named 'Food', expense 'new-1';
  // prefs dark_mode = true
  expect(await run(), isA<ImportDone>());
  expect((await rowCountsOf(newDb))['categories'], 8);
  expect((await rowCountsOf(newDb))['expenses'], 5);
  // category 'food' name == 'Food & Dining'
  expect(await prefs.getBool('dark_mode'), true);
});
// Review Focus 5
test('rolls back and keeps the old file when a table cannot be copied', () async {
  // DROP TABLE owed_items in the old copy
  final r = await run() as ImportFailed;
  expect(r.tables, ['owed_items']);
  expect(r.logLine, startsWith('Data import failed: owed_items ('));
  expect((await rowCountsOf(newDb))['expenses'], 0);
  expect(File('$dir/expense_tracker.db').existsSync(), true);
  expect(await prefs.getBool('legacy_import_done'), isNull);
  expect(importFailedMessage, 'Koban could not move your data. Your data is safe. Update again later.');
});
test('refuses an old database that is not version 11', () async {
  // PRAGMA user_version = 10 in the old copy
  final r = await run() as ImportFailed;
  expect(r.tables, isEmpty);
  expect(r.detail, 'old database version 10, needs 11');
  expect((await rowCountsOf(newDb))['expenses'], 0);
});
test('skips when there is no old database', () async {
  // fake path to a missing file -> ImportSkipped, prefs empty
});
```

- [ ] **Step 2: Run.** `flutter test test/data/legacy_import_test.dart` → FAIL (`importLegacyData` not defined).
- [ ] **Step 3: Implement** `legacy_import.dart` and `open_database.dart` with the steps above. Take the column names and primary keys from the Drift tables (`db.allTables`, `$columns`, `$primaryKey`), not from a second hand-written list.
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (11 new tests).
- [ ] **Step 5: Commit.** "Import the 0.1.1 database and settings once at first start".

### Task 6: Branch check

**Files:** none new.

- [ ] **Step 1: Run everything, one at a time.** `cd koban && flutter analyze && flutter test` → "No issues found!" and "All tests passed!". Then `cd koban/android && ./gradlew.bat --max-workers=2 :app:testDebugUnitTest` → BUILD SUCCESSFUL.
- [ ] **Step 2: Build once.** `flutter build apk --debug` → `koban/build/app/outputs/flutter-apk/app-debug.apk` exists (proves the Kotlin channel code and the SQLite build hook compile for Android). Do not install it.
- [ ] **Step 3: Check the Kotlin app is untouched.** `git diff --stat main -- app/ gradle/` → empty; `git status --short app/` → empty.
- [ ] **Step 4: Draft the map note** for issue #20 (3 to 5 lines, STE): the schema equals Room v11, the import passes against files from the real 0.1.1 code, and the owner-database test is in milestone 6. The controller posts it.
- [ ] **Step 5: Commit and push** only if the owner allowed it for this run.

## Known limits

- The import is tested against files from the real 0.1.1 Room and DataStore code, not against a real phone database: the owner's phone runs a non-debuggable release build, so `adb` cannot copy its file. The test with the owner's real database (466 payments, spec 6.4 step 6) happens in milestone 6, before any friend gets the update.
- No device run in this milestone. The `MainActivity` channel and `openKobanDatabase` first run on a device in milestone 3. A debug build has the app ID `io.github.skooyo.koban.debug`, so it never sees the real app's files.
- Milestone 3 must make the background capture isolate call `openKobanDatabase` before it writes, and must stop two isolates from running the import at the same time (the static `Future` guards only one isolate).
- Settings stay plain text, as in 0.1.1 (`SharedPreferencesAsync` instead of plain DataStore). A secure store for `device_token` and `group_session` is a later decision.
- CI runs only the Dart tests. The Kotlin reader test in `koban/android/` runs locally in Tasks 4 and 6.
