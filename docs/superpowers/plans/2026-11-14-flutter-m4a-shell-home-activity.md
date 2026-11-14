# Flutter milestone 4a: app shell, theme, data, Home, Activity and the payment sheet — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start the Flutter app with the Koban theme (dark and light), the 4-tab shell with the 0.1.1 screen motion, the local data layer for payments, categories and splits, and the Home, Activity and payment (add and edit) screens at parity with 0.1.1.

**Architecture:** One `AppServices` object holds the database, the settings and the repositories, and an `InheritedWidget` (`AppScope`) gives it to the screens. Each screen has one `ChangeNotifier` view-model, made in the screen's `State` and disposed with it; it subscribes to repository streams and calls `notifyListeners`. Repositories port the Kotlin repositories one to one; their SQL is the Room `@Query` text in `.drift` files. Navigation is the plain `Navigator` with two route classes: `KobanPageRoute` (full-width slide, the page below moves 30% and darkens) and `KobanSheetRoute` (the payment page rises; the page below stays). The four tabs live in one `IndexedStack`, so a tab switch is instant and keeps each tab's state.

**Tech Stack:** Flutter 3.50.0 / Dart 3.14.0, `package:material_ui` (Material 3, as `koban/lib/main.dart` imports it), existing `drift` 2.35, `drift_flutter`, `shared_preferences` (`SharedPreferencesAsync`), `decimal`, `intl`. No new pub package in this plan.

**Spec:** `docs/superpowers/specs/2026-11-13-flutter-migration-design.md` (section 6.2 "Screens", section 6.7 item 4). Design rules: `docs/DESIGN.md`. Reference app: `app/src/main/java/com/expensetracker/app/ui/` and `.../data/`.

**Order:** milestone 4 has 3 plans, executed and merged in this order: **4a (this plan)**, `2026-11-14-flutter-m4b-capture-screens.md`, `2026-11-14-flutter-m4c-people-splits.md`. Start 4a on branch `feature/flutter-m4a` from `main` after milestone 3 is merged.

**Decisions (the spec leaves these to the builder):**
1. **State and dependency injection: no package.** `AppServices` + `AppScope` (an `InheritedWidget`) + one `ChangeNotifier` view-model per screen, read with `ListenableBuilder`. Rejected: `provider` (adds little over one `InheritedWidget` for about 10 objects), `riverpod` (code generation or a second way to make state; the 0.1.1 view-models port more directly to `ChangeNotifier`).
2. **Live queries: one helper, no stream library.** `watchTables(db, tables, load)` yields `load()` once and again on each Drift table update of those tables. It replaces the Kotlin `combine(...)` of several flows. Rejected: `rxdart` (a new package for `combineLatest` only).
3. **Navigation: plain `Navigator` with 2 route classes.** Rejected: `go_router` (its custom transitions also need `CustomTransitionPage` classes, so it adds a package and routes as text for no gain; Koban has no deep links). The root route is a `KobanPageRoute` (`MaterialApp.onGenerateInitialRoutes`), so the shell itself moves 30% when a page covers it. `KobanPageRoute.canTransitionTo(next)` is true only for another `KobanPageRoute`, so the page below a sheet stays still (0.1.1 `KeepUntilTransitionsFinished`).
4. **Colors: tokens first.** Where `koban/lib/theme/tokens.dart` has a token, the theme uses it; values that only `Theme.kt` has (secondary, outline, error containers, `uncategorized`) are copied from `Theme.kt`. 3 light values change slightly from 0.1.1 to the tokens (Bills orange `#E07A0F` for `#F08A1C`, gold-text `#7A5D00` for `#8A6A00`, gold `#F2C94C` for `#D8A31A`), as spec 6.2 asks for the DESIGN.md tokens.
5. **Dark mode as 0.1.1:** the `dark_mode` setting (default on) picks the theme, not the phone setting. DESIGN.md says "light follows the phone setting", but the 0.1.1 code and its imported setting win for parity.
6. **Money totals:** SQLite `SUM` over TEXT money gives a REAL. Every total column is `CAST(<the Room expression> AS TEXT)` mapped by `MoneyConverter`, which rounds to 2 decimals as the Room converter does (`AmountFormatter.toMoney(BigDecimal(text))`).
7. **The import result shows on Home:** an `ImportFailed` result shows `importFailedMessage` as a row at the top of Home for this app start (DESIGN.md: an error with no fix is a status row, not a dialog).
8. **No golden-image tests:** font rendering differs between Windows and CI. Widget tests use exact texts, sizes, semantics and the Flutter accessibility guidelines.

**Not in this plan:** Check payments, payment apps, Settings, notification log, onboarding and the Home rows that open them (plan 4b). People, person, split editor, the People tab badge and "Split this bill" (plan 4c). Online parts (milestone 5).

## Global Constraints

- `flutter` means `D:/flutter/bin/flutter`, `dart` means `D:/flutter/bin/dart`. Run them from `koban/`. Code generation: `dart run build_runner build --delete-conflicting-outputs`.
- Commit steps: the controller runs them. The implementer stops after the last verification step and reports the changed files.
- Run at most one Gradle or Flutter build or test run at a time.
- Each task ends with `flutter analyze` → "No issues found!" and `flutter test` → "All tests passed!".
- `git diff main -- app/ gradle/` stays empty. The Kotlin app is the reference. Do not change it.
- UI text is copied byte for byte from the 0.1.1 Kotlin screen named in each task (including `…`, `–`, `·` and curly quotes). Do not write new UI text. The only new text in milestone 4 is the milestone-5 placeholder (Task 5), which never ships (milestone 6 ships after milestone 5).
- Money text: `RM 12.50` = `'RM ${AmountFormatter.formatGrouped(v)}'`; received: `'+ RM 12.50'`. Amounts use tabular figures (`tabular(style)`, Task 1).
- Every time comes from `AppServices.now` (screens, view-models and repositories). No `DateTime.now()` outside `AppServices.start`.
- Accessibility: every icon-only button has the 0.1.1 `contentDescription` as its `tooltip` or semantics label. Each screen test runs `await expectLater(tester, meetsGuideline(androidTapTargetGuideline))` and `meetsGuideline(labeledTapTargetGuideline)`, and one test pumps the screen at `TextScaler.linear(1.3)` and expects `tester.takeException()` to be null.
- Motion (from `ExpenseTrackerNavHost.kt`): page push and pop 400 ms `Curves.fastOutSlowIn`; the page below slides to `Offset(-0.3, 0)` and fades to opacity 0.6; sheet open 450 ms `Cubic(0.05, 0.7, 0.1, 1)`, sheet close 300 ms `Cubic(0.3, 0, 0.8, 0.15)`; tab switch 0 ms. With `MediaQuery.disableAnimationsOf(context)` true, every route uses `Duration.zero`.
- Doc comments and test names in ASD-STE100 Simplified Technical English.
- The repository is public: test data is synthetic (`RESTORAN CONTOH`, `Kedai Contoh`, `Ali`, `Mei`).

## Review Focus

1. Totals must be exact to the cent: `0.10 + 0.20 + 1234.56` is `RM 1,234.86`, never `RM 1,234.85` or `RM 1,234.8600000001`. Pinned in Task 3.
2. Day, week and month edges use the phone's local time: a payment at 23:59:59.999 counts on that day, the week runs Monday to Sunday, and the month list (SQLite `localtime`) and the Dart ranges agree for a payment at 31 Oct 23:30. Pinned in Task 3.
3. A new category on an edit changes the past payments from the same shop in the same direction (case and outer spaces ignored), and never the other direction. Pinned in Task 3.
4. The payment sheet with typed data asks "Discard changes?" on Back and on X; with no change it closes at once; Save never asks; two fast taps on Save add one payment. Pinned in Task 6.
5. With animations off in the phone settings, every page and sheet shows at once. Pinned in Task 5.

---

### Task 1: Theme, font and Mon

**Files:**
- Modify: `koban/pubspec.yaml` (add `fonts:` family `Bricolage`, asset `assets/fonts/BricolageGrotesque.ttf`)
- Create: `koban/lib/theme/koban_theme.dart`, `koban/lib/theme/mon.dart`
- Test: `koban/test/theme/koban_theme_test.dart`, `koban/test/theme/mon_test.dart`

**Interfaces:**
- Consumes: `KobanColors.dark` / `.light`, `KobanType.*`, `KobanRadius.*` (`koban/lib/theme/tokens.dart`).
- Produces:
  - `ThemeData kobanTheme(Brightness brightness)` — `useMaterial3: true`; `colorScheme` = the `DarkColors` / `LightColors` of `app/.../ui/theme/Theme.kt` with Decision 4 (`primary`, `onPrimary`, `primaryContainer`, `onPrimaryContainer`, `secondary*`, `tertiary`, `error*`, `surface` = night, `onSurface` = ink, `onSurfaceVariant` = muted, `surfaceContainerLowest` … `surfaceContainerHighest`, `outline`, `outlineVariant` = line); `scaffoldBackgroundColor` = night; `textTheme` = the 15 `KobanType` styles with `fontFamily: 'Bricolage'`, `height: lineHeight / size`, `letterSpacing: tracking`, `fontVariations: [FontVariation('wght', weight), FontVariation('opsz', 96 for display and headline, 14 for the rest)]`; `navigationBarTheme` (background `surfaceContainer`, indicator `primaryContainer`); `snackBarTheme` (background ink, content night, action `#7A5D00` on dark and `#F2C94C` on light, radius 12, floating); `dialogTheme` radius 24; `bottomSheetTheme` top radius 24; filled, tonal, outlined and text buttons radius full and minimum height 48.
  - `class MoneyColors extends ThemeExtension<MoneyColors>` with the 13 fields of `Theme.kt` `MoneyColors` (`received`, `review`, `red`, `blue`, `orange`, `purple`, `teal`, `green`, `gold`, `goldText`, `custom`, `other`, `uncategorized`) and `static const dark`, `light`; `static MoneyColors of(BuildContext context)`.
  - `Color categoryColor(BuildContext context, String? categoryId)` — the `Theme.kt` `categoryColor` mapping (`food` red, `transport` blue, `shopping` purple, `bills` orange, `entertainment` green, `health` teal, `other` other, null uncategorized, any other id custom).
  - `TextStyle tabular(TextStyle style)` — adds `FontFeature.tabularFigures()`.
  - `enum MonFace { idle, worry, happy }` and `class Mon extends StatelessWidget { const Mon(this.face, {super.key, required this.size, this.semanticLabel}); }` — width `size`, height `size * 1.1`; a `CustomPainter` that draws `app/src/main/res/drawable/mon_idle.xml`, `mon_worry.xml`, `mon_happy.xml` (viewport 100 × 110, the same group rotations and pivots, ellipses, lines and quadratic curves, colors and stroke widths). No label: `ExcludeSemantics`. With a label: `Semantics(label:, image: true)`.

- [ ] **Step 1: Write the failing tests.**

```dart
// koban_theme_test.dart
test('the dark theme uses the night, ink and gold tokens', () {
  final t = kobanTheme(Brightness.dark);
  expect(t.scaffoldBackgroundColor, const Color(0xFF141B2B));
  expect(t.colorScheme.primary, const Color(0xFFF2C94C));
  expect(t.colorScheme.onPrimary, const Color(0xFF2A2106));
  expect(t.colorScheme.surfaceContainer, const Color(0xFF1C2539));
  expect(t.colorScheme.onSurface, const Color(0xFFEDF0F7));
  expect(t.colorScheme.onSurfaceVariant, const Color(0xFFA2ACC2));
});
test('the light theme uses gold text as the primary color', () {
  final t = kobanTheme(Brightness.light);
  expect(t.colorScheme.primary, const Color(0xFF7A5D00));
  expect(t.colorScheme.onPrimary, const Color(0xFFFFFFFF));
  expect(t.scaffoldBackgroundColor, const Color(0xFFF6F7FA));
});
test('text styles follow the type tokens', () {
  final s = kobanTheme(Brightness.dark).textTheme;
  expect(s.displayLarge!.fontSize, 57);
  expect(s.displayLarge!.height, 64 / 57);
  expect(s.displayLarge!.letterSpacing, -1.5);
  expect(s.displayLarge!.fontFamily, 'Bricolage');
  expect(s.displayLarge!.fontVariations, [const FontVariation('wght', 700), const FontVariation('opsz', 96)]);
  expect(s.bodyMedium!.fontVariations, [const FontVariation('wght', 400), const FontVariation('opsz', 14)]);
});
testWidgets('category colors follow the category ids', (tester) async {
  // pump a Builder in MaterialApp(theme: kobanTheme(Brightness.dark)) and read the colors
  expect(categoryColor(ctx, 'food'), const Color(0xFFFF6B5E));
  expect(categoryColor(ctx, null), const Color(0xFFA3AEBD));
  expect(categoryColor(ctx, 'c1'), const Color(0xFF8C9EFF));
});

// mon_test.dart
testWidgets('Mon is 1.1 times as high as it is wide', ...); // Mon(MonFace.happy, size: 120) → tester.getSize == Size(120, 132)
testWidgets('Mon has no label unless the screen gives one', ...);
  // no label → find.bySemanticsLabel(RegExp('Mon')) finds nothing; semanticLabel 'Mon, sleeping' → finds one
```

- [ ] **Step 2: Run.** `flutter test test/theme/` → FAIL (`kobanTheme` not defined).
- [ ] **Step 3: Implement.** Add the font to `pubspec.yaml`. Write the theme and the painter.
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (6 new tests).
- [ ] **Step 5: Commit.** "Add the Koban theme, the font and Mon".

### Task 2: Split data

**Files:**
- Create: `koban/lib/data/split_queries.drift`, `koban/lib/data/split_repository.dart`, `koban/lib/data/user_error.dart`, `koban/lib/data/watch.dart`
- Modify: `koban/lib/data/database.dart` (add `'split_queries.drift'` to `include`), `koban/lib/data/database.g.dart` (generated)
- Test: `koban/test/data/split_repository_test.dart`

**Interfaces:**
- Consumes: `KobanDatabase` and the data classes `SplitBill`, `SplitItem`, `SplitItemShare`, `SplitDebt`, `SplitPeopleData`, `OwedItem`, `Expense` (milestone 2); `newId()` (`koban/lib/data/ids.dart`, milestone 3); `SplitMath`, `SplitItemInput`, `SplitCharges`, `meId`, `PeopleMath`, `SettleCandidate`, `RepaymentMatcher`, `AmountFormatter`, `DebtStatus`, `TransactionType`, `ExpenseStatus` (milestone 1).
- Produces:
  - `split_queries.drift`: one named query for each `@Query` of `app/.../data/SplitDao.kt`, same SQL text and same names (`observeBills` → `bills`, `getOpenDebts` → `openDebts`, …). The `observeOpenDebts` join returns `OpenDebtRow` columns (`debtId, billId, personId, personName, merchant, billTime, amount, manual`).
  - `user_error.dart`: `class KobanUserError implements Exception { const KobanUserError(this.message); final String message; }` — every error whose text a screen shows (the Kotlin `IllegalArgumentException` and `IllegalStateException` messages).
  - `watch.dart`: `Stream<T> watchTables<T>(KobanDatabase db, Set<ResultSetImplementation> tables, Future<T> Function() load)` — `yield await load()`, then again for each `db.tableUpdates(TableUpdateQuery.onAllTables(tables))` event.
  - `split_repository.dart`: `class DraftItem`, `class SplitDraft`, `class OpenDebtView` (the fields of `SplitRepository.kt`), and `class SplitRepository { SplitRepository(KobanDatabase db, {required int Function() now}); Stream<List<SplitBill>> watchBills(); Stream<List<SplitPeopleData>> watchRecentPeople(); Stream<List<OpenDebtView>> watchOpenDebts(); Future<SplitBill?> billForExpense(String expenseId); Future<bool> isLocked(String billId); Future<SplitDraft?> loadDraft(String billId); Future<String> saveSplit(SplitDraft draft); Future<void> linkPayment(String billId, String? expenseId); Future<void> onExpenseEdited(String expenseId); Future<void> deleteSplit(String billId); Future<List<Expense>> paymentCandidates(String? billId, Decimal total, int billTime); Future<List<Expense>> repaymentCandidates(String debtId); Future<void> markPaid(String debtId, String? repaymentExpenseId); Future<void> confirmSuggestion(String debtId); bool isUsableRepayment(Expense e); Future<void> dismissSuggestion(String debtId); Future<void> closeAllFor(String personId, Expense? expense); Future<void> clearSettleSuggestion(String personId); Future<void> suggestRepayment(Expense receive); }` — port `SplitRepository.kt` line for line; `db.withTransaction` becomes `db.transaction` (Drift nests them as savepoints). Windows: payment 3 days (`259200000` ms), repayment lead 1 day (`86400000` ms). Messages, verbatim: `This split already has a repayment, so it can't change.`, `This payment already belongs to another split.`, `Repayment expense is not available`, `Repayment amount does not match this debt`.

- [ ] **Step 1: Write the failing tests.** `db = KobanDatabase(NativeDatabase.memory())`, `T = DateTime(2026, 11, 13, 12).millisecondsSinceEpoch`, `repo = SplitRepository(db, now: () => T)`. Helpers insert expenses and people through the typed API. Draft A: items `Nasi lemak` 20.00 shared by `{meId, ali}` and `Teh ais` 4.00 by `{ali}`, no charges.

```dart
test('a saved split makes one open debt for each other person', ...);
  // saveSplit(A) → split_debts: one row, person Ali, amount 14.00, status OPEN; split_items positions [0, 1]; bill serviceCharge 0.00
test('a draft person with the same name in other case reuses the stored person and revives them', ...);
  // stored 'Ali' archived → draft person name ' ali ' → same id, archived false, lastUsedAt T
test('a split with a paid debt cannot change', () async {
  // save A, markPaid(debt, null), save A again with its billId
  await expectLater(repo.saveSplit(a2), throwsA(isA<KobanUserError>().having((e) => e.message, 'message', "This split already has a repayment, so it can't change.")));
});
test('a linked payment counts only the share of the owner', ...);
  // expense WITHDRAW 24.00 linked → countedAmount 10.00; unlink (linkPayment(bill, null)) → countedAmount null
test('a payment that belongs to another split is refused', ...); // message 'This payment already belongs to another split.'
test('an edit of the linked payment counts the new share', ...); // amount 30.00 then onExpenseEdited → countedAmount 16.00
test('delete split frees the linked payment and a repayment that pays nothing else', ...);
test('payment candidates are unlinked spends within 3 days with the exact amount first', ...);
  // spends: 24.00 at billTime - 1h, 10.00 at billTime - 2h, 24.00 at billTime - 4 days → [first, second]
test('mark paid with the whole open amount of the person closes every debt of the person', ...);
test('mark paid with another amount is refused', ...); // message 'Repayment amount does not match this debt'
test('a receive that fits open debts becomes their suggestion', ...); // RECEIVE 14.00 from 'ALI' → debt.suggestedRepaymentExpenseId == receive id
test('a receive that fits no debt set suggests a settle up for one person', ...);
  // Ali owes 14.00 on a split and the owner owes Ali 4.00 (owed_items) → RECEIVE 10.00 'ALI' → person.suggestedSettleExpenseId
test('a stale suggestion is cleared and closes nothing', ...); // receive amount changed to 13.00 → confirmSuggestion → debt OPEN, suggestion null
```

- [ ] **Step 2: Run.** `flutter test test/data/split_repository_test.dart` → FAIL.
- [ ] **Step 3: Implement.** Write the queries, generate, write the repository. `schema_test.dart` must still pass.
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (13 new tests).
- [ ] **Step 5: Commit.** "Port the split repository and its queries".

### Task 3: Payment, category and settings data

**Files:**
- Create: `koban/lib/data/expense_queries.drift`, `koban/lib/data/expense_repository.dart`, `koban/lib/data/category_repository.dart`, `koban/lib/data/merchant_category_repository.dart`, `koban/lib/data/summaries.dart`, `koban/lib/data/settings_store.dart`, `koban/lib/data/activity_selection.dart`
- Modify: `koban/lib/data/database.dart` (`include`), `koban/lib/data/database.g.dart` (generated)
- Test: `koban/test/data/expense_repository_test.dart`, `koban/test/data/category_repository_test.dart`, `koban/test/data/settings_store_test.dart`

**Interfaces:**
- Consumes: `SplitRepository`, `watchTables` (Task 2); `PeriodCalculator`, `SpendingPeriod`, `YearMonth`, `MonthNav` (milestone 1, `koban/lib/rules/periods.dart`; months are 0-based in `PeriodCalculator`, 1-based in `YearMonth`); `newId()`; the 8 settings keys of `koban/lib/data/legacy_import.dart`.
- Produces:
  - `expense_queries.drift`: named queries with the SQL of `ExpenseDao.kt`: `anyExpense`, `allActive`, `totalForRange`, `receivedForRange`, `inRange`, `totalsByCategory`, `setCategoryForMerchant`, `recentByType`, `monthlyTotals`, `totalForRangeOnce`. Each money total is `CAST(<Room expression> AS TEXT) AS total` with `MAPPED BY \`const MoneyConverter()\`` (Decision 6).
  - `summaries.dart`: `class CategoryBreakdown { String? categoryId; String name; String colorHex; Decimal total; double fraction; }`, `class PeriodSummary { title, subtitle, total, breakdown, recentExpenses, periodStart, periodEnd, received }`, `class MonthSummary { year, month0, label, total, received }`, `class WeekSummary { startMs, endMs, label, total }`.
  - `class CategoryRepository { CategoryRepository(KobanDatabase db); static const uncategorizedName = 'Uncategorized'; static const uncategorizedColor = '#9E9E9E'; static const defaults = [...]; Stream<List<Category>> watchAll(); Future<void> seedIfEmpty(); Future<void> addCategory(String name, String colorHex); Future<bool> deleteCategory(String id); Future<Category?> getById(String? id); }` — the 7 defaults of `DefaultCategories.kt` (ids, names, colors, `isDefault` true); `watchAll` ordered by name.
  - `class MerchantCategoryRepository { MerchantCategoryRepository(KobanDatabase db, {required int Function() now}); String? normalizeKey(String? merchant); Future<String?> categoryIdForMerchant(String? merchant); Future<void> saveMapping(String? merchant, String? categoryId); }`
  - `class ExpenseRepository { ExpenseRepository(KobanDatabase db, {required CategoryRepository categories, required MerchantCategoryRepository merchants, required SplitRepository splits, required DateTime Function() now}); static const manualSource = 'manual'; Stream<bool> watchHasAnyPayment(); Stream<List<Expense>> watchAllActive(); Stream<Decimal> watchTotalForRange(int start, int end); Stream<Decimal> watchReceivedForRange(int start, int end); Stream<List<Expense>> watchInRange(int start, int end); Stream<List<MonthSummary>> watchMonthlySummaries(); Future<List<WeekSummary>> weekSummariesForMonth(int year, int month0); Stream<PeriodSummary> watchPeriodSummary(SpendingPeriod period); Stream<List<CategoryBreakdown>> watchCategoryBreakdown(int start, int end); Future<Expense?> getById(String id); Future<void> addManualExpense({required Decimal amount, String? merchant, required int postTime, String? categoryId, String? notes, required TransactionType type, bool privateToGroups = false}); Future<void> updateExpense(String id, {same named fields}); Future<void> dismissExpense(String id); }` — rules of `ExpenseRepository.kt` (`RECENT_IN_PERIOD` 5, fraction 4 decimals HALF_UP, manual `dedupKey` `manual:<id>`, status `EDITED`, confidence `HIGH`, currency `MYR`; split hooks catch and log errors as Kotlin does).
  - `class KobanSettings { static Future<KobanSettings> load(SharedPreferencesAsync prefs); ValueListenable<bool> darkMode /* dark_mode, default true */; ValueListenable<bool> onboardingDone /* false */; ValueListenable<bool> paymentAppsChosen /* payment_apps_chosen, else the stored list is not empty */; ValueListenable<Set<String>> paymentApps /* payment_app_allowlist */; ValueListenable<bool> onlineFeatures /* true */; ValueListenable<bool> hasDeviceToken; Future<void> setDarkMode(bool); Future<void> setOnboardingDone(); Future<void> setOnlineFeatures(bool); Future<void> removeDeviceToken(); Future<void> reload(); }`
  - `class Selection { YearMonth month; int? weekStart; String? categoryFilter; bool showAll; }` and `class ActivitySelection extends ValueNotifier<Selection> { ActivitySelection(YearMonth now); void show(YearMonth month, {int? weekStart, String? categoryFilter}); void setCategoryFilter(String? filter); void setShowAll(bool showAll); }` — as `ActivitySelection.kt`.

- [ ] **Step 1: Write the failing tests.** `now = DateTime(2026, 11, 13, 12)` (a Friday), in-memory database, categories seeded.

```dart
// Review Focus 1
test('totals of text money add up to the cent', () async {
  // WITHDRAW 0.10, 0.20, 1234.56 and RECEIVE 50.00 today
  expect(await repo.watchTotalForRange(dayStart, dayEnd).first, Decimal.parse('1234.86'));
  expect(await repo.watchReceivedForRange(dayStart, dayEnd).first, Decimal.parse('50.00'));
});
test('a counted amount replaces the amount in totals', ...); // amount 24.00, countedAmount 10.00 → 10.00
test('dismissed payments count nowhere', ...); // total, breakdown, allActive, anyExpense false
// Review Focus 2
test('a payment at the last millisecond of a day counts on that day', ...);
  // DateTime(2026, 11, 13, 23, 59, 59, 999) in watchPeriodSummary(day).total; DateTime(2026, 11, 14) not
test('the week runs from Monday to Sunday', () async {
  final week = await repo.watchPeriodSummary(SpendingPeriod.week).first;
  expect(week.title, 'This week');
  expect(week.subtitle, 'Mon 9 Nov – Sun 15 Nov');
  // a payment on Sun 15 Nov 23:00 counts; Mon 16 Nov 00:00 does not
});
test('month totals group by the local month', ...);
  // 31 Oct 23:30 (10.00) and 1 Nov 00:10 (5.00) → [MonthSummary(2026, 10, 'November 2026', 5.00), MonthSummary(2026, 9, 'October 2026', 10.00)]
test('a period summary lists the 5 newest payments', ...);
test('the category breakdown gives names, fractions and Uncategorized', ...);
  // food 30.00, no category 10.00 → [('food', 'Food & Dining', 30.00, 0.75), (null, 'Uncategorized', 10.00, 0.25, '#9E9E9E')]
test('week summaries of a month cover full Monday to Sunday weeks', ...); // November 2026 → 6 weeks, first label 'Mon 26 Oct – Sun 1 Nov'
// Review Focus 3
test('a new category on an edit applies to past payments from the shop in the same direction', () async {
  // WITHDRAW 'Kedai Contoh', WITHDRAW ' kedai contoh ', RECEIVE 'Kedai Contoh', all categoryId null
  // updateExpense(first, categoryId: 'food', merchant: 'Kedai Contoh', type: withdraw, ...)
  // → both withdraws 'food', the receive null; merchant_category_map: ('kedai contoh', 'Kedai Contoh', 'food')
});
test('a manual payment has the manual source and key', ...);
  // sourcePackage 'manual', dedupKey 'manual:' + id, status EDITED, confidence HIGH, currency 'MYR',
  // merchant '  ' → null, notes ' x ' → 'x', rawNotificationText ''
test('a received manual payment that fits a debt becomes its suggestion', ...);
test('an edit of a linked payment counts the new share', ...);
test('delete marks the payment dismissed', ...);

// category_repository_test.dart
test('seeding adds the 7 built-in categories one time', ...);
  // watchAll names: ['Bills & Utilities', 'Entertainment', 'Food & Dining', 'Health', 'Other', 'Shopping', 'Transport']; second seed: 7 rows
test('only own categories can be deleted', ...); // deleteCategory('food') false; own category true
test('a blank name adds no category', ...);

// settings_store_test.dart — SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.withData(...)
test('settings have the 0.1.1 defaults', ...); // darkMode true, onboardingDone false, paymentAppsChosen false, onlineFeatures true, hasDeviceToken false
test('an older stored app list counts as chosen', ...); // payment_app_allowlist ['com.maybank2u.life'] only → paymentAppsChosen true
test('dark mode is stored under dark_mode', ...); // setDarkMode(false) → prefs.getBool('dark_mode') false, darkMode.value false
test('remove device token deletes the key', ...);
```

- [ ] **Step 2: Run.** `flutter test test/data/` → FAIL.
- [ ] **Step 3: Implement.** Write the queries, generate, write the classes.
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (21 new tests).
- [ ] **Step 5: Commit.** "Port the payment and category repositories and the settings".

### Task 4: Shared components

**Files:**
- Create (in `koban/lib/ui/`): `kit.dart`, `amount_input.dart`, `date_labels.dart`, `money.dart`, `category_donut.dart`, `payment_row.dart`, `dialogs.dart`, `listener_status_banner.dart`
- Test (in `koban/test/ui/`): `amount_input_test.dart`, `donut_slices_test.dart`, `date_labels_test.dart`, `kit_test.dart`, `payment_row_test.dart`

**Interfaces:**
- Consumes: Task 1 (theme, `Mon`), Task 3 (`CategoryBreakdown`), `Expense`.
- Produces (ports of `app/.../ui/components/`; same names, parameters as Dart named parameters):
  - `kit.dart` (port of `Kit.kt`): `ListGroup({required List<Widget> children})` (one `surfaceContainer` group, radius 16, 1 px `outlineVariant` dividers between rows only), `KobanRow({required String title, String? subtitle, Color? subtitleColor, Widget? leading, Widget? trailing, Widget? titleSuffix, bool showChevron = false, VoidCallback? onTap, String? onTapLabel, int? subtitleMaxLines})` (minimum height 56), `SectionHeading(String text)`, `MoneyText(String text, {TextStyle? style, Color? color})`, `CategoryDot(Color color, {double size = 10})`, `LargeTopBar({required String title, String? subtitle, List<Widget> actions = const []})`, `TonalButton(String text, VoidCallback? onPressed, {IconData? icon})`, `DirectionSegments({TransactionType? selected, ValueChanged<TransactionType>? onPick, VoidCallback? onTapWhenFixed})` (labels `Spent`, `Received`), `SegmentedControl({required List<String> labels, required int selectedIndex, required ValueChanged<int> onPick})`, `StepProgress({required int number, required int total, required String name})` (text `Step $number of $total · $name`), `InitialsAvatar(String name, {double size = 40, Color? tint})`, `String initialsOf(String name)`, `DialogTextField(...)`.
  - `amount_input.dart`: `abstract final class AmountInput { static const maxWholeDigits = 9; static String press(String text, String key); static String backspace(String text); static Decimal? toAmount(String text); static String fromAmount(Decimal amount); }`
  - `date_labels.dart`: `String dateLabel(int ms, DateTime now)` (`Today`, `Yesterday`, `EEE, d MMM`), `String dateTimeLabel(int ms)` (`EEE, d MMM, HH:mm`), `String dayHeaderLabel(int ms, DateTime now)` (adds ` yyyy` when the year differs), all `en_US`.
  - `money.dart` (port of `SpendingPeriodSection.kt`): `String rm(Decimal v)`, `MoneyAmount`, `NoteStrip`, `RelativeBar`, `ReceivedNote`, and the stripes fill for no category.
  - `category_donut.dart` (port of `CategoryCharts.kt`): `const uncategorizedFilter = '__uncategorized'`, `bool matchesCategory(Expense e, String? filter)`, `const everythingElse = 'Everything else'`, `class DonutSlice { String? categoryId; String name; Decimal total; bool folded; }`, `List<DonutSlice> donutSlices(List<CategoryBreakdown> breakdown)`, `CategoryDonut({required List<DonutSlice> slices, VoidCallback? onTap})` with semantics label `Spending by category: Food 60 percent, …` and tap label `Filter by category`.
  - `payment_row.dart` (port of `ExpenseItem.kt`): `ExpenseListCard({required Expense expense, String? categoryName, required VoidCallback onEdit, bool showConfidence = false, String timePattern = 'HH:mm'})` and `List<Widget> expensesByDay({required List<Expense> expenses, required String? Function(Expense) categoryName, required void Function(Expense) onEdit, required DateTime now})` (a day header with the day's spent total, then one `ListGroup`).
  - `dialogs.dart`: `Future<bool> showDiscardChangesDialog(BuildContext context)` (true = Discard; title `Discard changes?`, body `Your changes are not saved.`, buttons `Keep editing`, `Discard` in error color); `Future<int?> showPastDatePicker(BuildContext context, {required int time, required DateTime now})` (no day after today; keeps the local time of day of `time`, as `withDate` in `PastDatePickerDialog.kt`).
  - `listener_status_banner.dart`: `ListenerStatusBanner({required bool isAccessGranted, required VoidCallback onEnable})` — on: `Tracking on`; off: `Mon(MonFace.worry, size: 40)`, `Tracking is off`, `Koban cannot read notifications.`, button `Turn on`.

- [ ] **Step 1: Write the failing tests.** Port `AmountInputTest.kt` (11 cases) and `DonutSlicesTest.kt` (3 cases) one to one; keys are one-character strings. Compare totals as `Decimal` values, not text (`Decimal.parse('30.00').toString()` is `'30'`).

```dart
// donut_slices_test.dart
test('slices follow the fixed order and fold the rest', () {
  final s = donutSlices([row('bills', 'Bills', '10.00'), row('food', 'Food', '30.00'), row('c1', 'Pets', '5.00'), row(null, 'Uncategorized', '7.00')]);
  expect(s.map((e) => (e.name, e.total, e.folded)), [('Food', Decimal.parse('30'), false), ('Bills', Decimal.parse('10'), false), ('Everything else', Decimal.parse('12'), true)]);
});
// + 'a single leftover keeps its name', 'slices stop at 6 and fold the smallest built-in category'

// date_labels_test.dart — now = DateTime(2026, 11, 13, 12)
test('dates near now say Today and Yesterday', ...); // 13 Nov 08:00 → 'Today'; 12 Nov 23:59 → 'Yesterday'; 11 Nov → 'Wed, 11 Nov'
test('a day header of another year shows the year', ...); // 13 Nov 2025 → 'Thu, 13 Nov 2025'
test('a date and time label has the day, the date and the time', ...); // 'Wed, 11 Nov, 20:15'

// kit_test.dart
test('initials use the first letters of the first two words', ...); // "Touch 'n Go" → 'TN'; 'ali' → 'AL'; '  ' → ''
testWidgets('a row is at least 56 high and tells its tap action', ...); // KobanRow(title: 'Shop', onTap:, onTapLabel: 'Change payment') → height >= 56; semantics has tap hint 'Change payment'
testWidgets('a list group puts dividers between rows only', ...); // 3 rows → 2 Divider
testWidgets('step progress says the step and its name', ...); // 'Step 2 of 6 · Items'
testWidgets('the discard dialog gives true only for Discard', ...);
testWidgets('the status banner shows Turn on when tracking is off', ...); // tap 'Turn on' → callback 1 time

// payment_row_test.dart — now as above, 24-hour times
testWidgets('a payment row shows the shop, time, category and amount', ...); // 'RESTORAN CONTOH', '12:00 · Food & Dining', 'RM 15.00'
testWidgets('a payment with no shop says Unknown shop', ...);
testWidgets('a received payment has a plus sign', ...); // '+ RM 50.00'
testWidgets('a used repayment says Repayment and a split spend says what was paid', ...); // RECEIVE counted 0.00 → 'Repayment'; WITHDRAW 24.00 counted 10.00 → 'paid RM 24.00' and 'RM 10.00'
testWidgets('the day header gives the spent total of the day', ...); // two spends 10.00 + 5.50 and one receive → 'Today' and 'RM 15.50'
```

- [ ] **Step 2: Run.** `flutter test test/ui/` → FAIL.
- [ ] **Step 3: Implement** the 8 files.
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (28 new tests).
- [ ] **Step 5: Commit.** "Port the shared screen components".

### Task 5: App services, shell, routes and motion

**Files:**
- Create (in `koban/lib/app/`): `app_services.dart`, `koban_app.dart`, `home_shell.dart`, `routes.dart`, `online_placeholder.dart`
- Modify: `koban/lib/main.dart` (replace the template `main`, `MyApp` and `MyHomePage`; keep `captureMain` from milestone 3 without change)
- Delete: `koban/test/widget_test.dart` (template counter test)
- Test: `koban/test/support/harness.dart`, `koban/test/app/routes_test.dart`, `koban/test/app/home_shell_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 4; `openKobanDatabase()`, `ImportResult` (milestone 2); `ListenerControl` (milestone 3, `koban/lib/capture/listener_control.dart`); `configureConnection` (milestone 3).
- Produces:
  - `class AppServices { AppServices({required KobanDatabase db, required KobanSettings settings, required ImportResult importResult, required ListenerControl listener, DateTime Function() now = DateTime.now}); final db, settings, importResult, listener, now; late final CategoryRepository categories; late final MerchantCategoryRepository merchants; late final SplitRepository splits; late final ExpenseRepository expenses; late final ActivitySelection activitySelection; final ValueListenable<bool> inGroups /* milestone 5 slot: always false */; static Future<AppServices> start(); }` — `start` opens the database (`openKobanDatabase`), loads `KobanSettings`, runs `categories.seedIfEmpty()`.
  - `class AppScope extends InheritedWidget { const AppScope({required AppServices services, required Widget child}); static AppServices of(BuildContext context); }`
  - `class KobanApp extends StatelessWidget { const KobanApp({required this.services}); }` — `MaterialApp` with `theme: kobanTheme(light)`, `darkTheme: kobanTheme(dark)`, `themeMode` from `settings.darkMode` (Decision 5), `builder` that puts a `ColoredBox(scaffoldBackgroundColor)` under the `Navigator` (so the page below darkens toward night as in 0.1.1), and `onGenerateInitialRoutes: (_) => [KobanPageRoute(builder: (_) => const HomeShell())]`.
  - `main.dart`: `Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); final s = await AppServices.start(); runApp(AppScope(services: s, child: KobanApp(services: s))); }`
  - `enum KobanTab { home, activity, people, groups }`; `class HomeShell extends StatefulWidget` with `static HomeShellState of(BuildContext context)` and `HomeShellState.select(KobanTab tab)`. An `IndexedStack` of the 4 tab bodies over a `NavigationBar` (labels `Home`, `Activity`, `People`, `Groups`; icons `Icons.home`, `Icons.receipt_long`, `Icons.people`, `Icons.groups`). Bodies in this plan: Home (Task 7), Activity (Task 8), People = `SizedBox.shrink()` until plan 4c Task 2, Groups = `OnlinePlaceholder(OnlineFeature.groups)` (final for milestone 4).
  - `routes.dart`: `class KobanPageRoute<T> extends PageRoute<T>` (`KobanPageRoute({required WidgetBuilder builder, bool animate = true})`, `opaque`, `maintainState`, push in from `Offset(1, 0)`; as the page below: `SlideTransition` to `Offset(-0.3, 0)` + `FadeTransition` to 0.6 on `secondaryAnimation`; `canTransitionTo(next) => next is KobanPageRoute`); `class KobanSheetRoute<T> extends PageRoute<T>` (rises from `Offset(0, 1)`, durations and curves of Global Constraints); `Future<T?> pushPage<T>(BuildContext context, Widget page)` and `Future<T?> pushSheet<T>(BuildContext context, Widget page)` (both read `MediaQuery.disableAnimationsOf(context)`). Each later task adds its own `openX` function to this file.
  - `online_placeholder.dart`: `enum OnlineFeature { groups('Groups'), inviteCode('Invite code'), receiptReading('Receipt reading'), updates('Check for updates'); final String title; }`, `class OnlinePlaceholder extends StatelessWidget { const OnlinePlaceholder(this.feature); }` (a `LargeTopBar(title: feature.title)` and one line `Comes with the online features in milestone 5.`), `Future<void> openOnlinePlaceholder(BuildContext context, OnlineFeature feature)` (pushes it as a page with a Back button). Milestone 5 deletes this file and each caller.
  - `test/support/harness.dart`: `Future<AppServices> testServices({DateTime? now, Map<String, Object> prefs = const {}, ImportResult importResult = const ImportSkipped(), FakeChannel? listener})` (in-memory database with `configureConnection`, `InMemorySharedPreferencesAsync.withData(prefs)`, categories seeded, `now` fixed, default `DateTime(2026, 11, 13, 12)`); `class FakeChannel { FakeChannel(String name, Map<String, Object?> answers); List<MethodCall> calls; }` (sets `setMockMethodCallHandler` on the test binary messenger and records each call; the listener default answers `isAccessGranted: true`, `isConnected: true`); `Future<void> pumpKoban(WidgetTester tester, AppServices s, {Widget? home, double textScale = 1, bool disableAnimations = false})` (`AppScope` + `KobanApp`, `MediaQuery` with `alwaysUse24HourFormat: true`; `home` replaces `HomeShell` when given); `addTearDown` closes the database after the tree is gone.

- [ ] **Step 1: Write the failing tests.** Screen width 800 in the default test view.

```dart
// routes_test.dart
testWidgets('an opened page slides in and the page below moves 30% and darkens', (tester) async {
  // home 'Below'; pushPage(context, Text('Above'))
  await tester.pump(); await tester.pump(const Duration(milliseconds: 399));
  expect(tester.getTopLeft(find.text('Above')).dx, greaterThan(0));
  await tester.pump(const Duration(milliseconds: 1));
  expect(tester.getTopLeft(find.text('Above')).dx, 0);
  expect(slideOf(tester, 'Below').position.value, const Offset(-0.3, 0));
  expect(fadeOf(tester, 'Below').opacity.value, 0.6);
});
testWidgets('Back slides the page out and brings the page below back', ...); // after pop + 400 ms: 'Above' gone, slide Offset.zero, opacity 1.0
testWidgets('the payment sheet rises in 450 ms and the page below stays', ...);
  // pushSheet: at 449 ms dy > 0, at 450 ms dy == 0; slideOf('Below') Offset.zero, fadeOf('Below') 1.0
testWidgets('the sheet closes in 300 ms', ...);
// Review Focus 5
testWidgets('with animations off every page and sheet shows at once', ...);
  // disableAnimations: true → after push and one pump(): dx == 0; the same for pushSheet

// home_shell_test.dart
testWidgets('the tab bar has Home, Activity, People and Groups with Home on', ...);
testWidgets('a tab switch shows the new tab in the same frame and keeps the old tab', ...);
  // scroll Home by 200, tap 'Activity', pump() once → Activity title visible; tap 'Home' → scroll offset 200
testWidgets('the Groups tab shows the online placeholder', ...); // 'Groups', 'Comes with the online features in milestone 5.'
testWidgets('the app follows the dark mode setting', ...); // prefs dark_mode false → Theme.of brightness light; true → dark
```

- [ ] **Step 2: Run.** `flutter test test/app/` → FAIL.
- [ ] **Step 3: Implement.** The Home and Activity tab bodies are empty `SizedBox` widgets until Tasks 7 and 8.
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (9 new tests).
- [ ] **Step 5: Commit.** "Add the app shell, the tab bar and the 0.1.1 screen motion".

### Task 6: Payment sheet (add and edit)

**Files:**
- Create: `koban/lib/screens/payment/payment_screen.dart`, `koban/lib/screens/payment/payment_view_model.dart`, `koban/lib/screens/payment/category_sheet.dart`
- Modify: `koban/lib/app/routes.dart` (add the open functions)
- Test: `koban/test/screens/payment_screen_test.dart`, `koban/test/screens/payment_view_model_test.dart`

**Interfaces:**
- Consumes: `AppServices` (`expenses`, `categories`, `inGroups`, `now`), `AmountInput`, `showDiscardChangesDialog`, `showPastDatePicker`, kit (Task 4).
- Produces:
  - `class PaymentForm { amountText, type, categoryId, postTime, merchant, notes, privateToGroups; copyWith; == }` (as `PaymentViewModel.kt`).
  - `sealed class PaymentResult { }`, `final class PaymentClosed extends PaymentResult { final String? message; }`, `final class PaymentOpenSplit extends PaymentResult { final String expenseId; }` (plan 4c uses the second).
  - `class PaymentViewModel extends ChangeNotifier { PaymentViewModel(AppServices s, {String? expenseId}); bool get isEditing; String? get loadedCategoryId; PaymentForm? get form; bool get hasChanges; bool get saving; List<Category> get categories; void press(String key); void backspace(); void setType(TransactionType t); void setCategory(String? id); void setDate(int ms); void setMerchant(String s); void setNotes(String s); void setPrivateToGroups(bool on); Future<PaymentResult?> save(); Future<PaymentResult?> delete(); }` — rules of `PaymentViewModel.kt`: messages `Expense added` (new spend), `Income added` (new receive), none on edit, `Payment deleted`; an edit of a missing id gives `PaymentClosed(null)` at once; `save` and `delete` return null while `saving` is true (the double-tap guard).
  - `category_sheet.dart`: `Future<void> showCategorySheet(BuildContext context, {required List<Category> categories, required String? selectedId, required ValueChanged<String?> onPick})` (plan 4b reuses it in the Check payments edit sheet).
  - `routes.dart`: `Future<PaymentResult?> openPaymentNew(BuildContext context)`, `Future<PaymentResult?> openPaymentEdit(BuildContext context, String expenseId)` — both `pushSheet`.
  - `PaymentScreen({String? expenseId})` — the layout of `PaymentScreen.kt`: top row (`Close` icon button, the `Spent` / `Received` segments, title `Payment` when editing, `Delete payment` icon button in error color when editing), the amount (`RM ${amountText or '0'}`, `+ ` for Received, semantics `Amount empty` / `Amount RM 12.5`, tap label `Type the amount`), the line under it (`Tap a number to change it` when adding; `Spent · Wed, 11 Nov, 20:15` when editing), rows `Category` (`Change category`), `Date` (`Change date`), `Shop` (placeholder `Not set`), `Note` (placeholder `Optional`), the hint `A new category also applies to past payments from this shop` (category changed from the loaded one and a shop typed), the number pad (rows `123`, `456`, `789`, `.0<`; `Decimal point`, `Delete digit`; shown on add, hidden on edit until the amount is tapped, hidden while Shop or Note has focus), and the main button `Save payment` / `Save changes` (off until the amount is above 0). `Count in group totals` shows only when `inGroups` is true (always false in milestone 4). The delete dialog: `Delete this payment?`, `It will no longer count in your totals.`, `Delete`, `Cancel`. `PopScope(canPop: !hasChanges || saving)` shows the discard dialog. Category sheet: title `Category`, categories by name, the selected one with a check (`Selected`).

- [ ] **Step 1: Write the failing tests.** Open the sheet from a test page with a button that `await`s `openPaymentNew` and stores the result.

```dart
// payment_view_model_test.dart
test('a new payment starts empty as a spend at now', ...); // form ('', withdraw, null, T, '', ''), hasChanges false
test('save of a new spend adds one manual payment and says Expense added', ...);
test('save of a new receive says Income added', ...);
test('save of an edit says nothing and keeps the id', ...);
// Review Focus 4
test('a second save during the first adds one payment', () async {
  final r = await Future.wait([vm.save(), vm.save()]);
  expect(r.whereType<PaymentClosed>().length, 1);
  expect(await countExpenses(db), 1);
});
test('delete marks the payment dismissed and says Payment deleted', ...);
test('an edit of a missing payment closes at once', ...);

// payment_screen_test.dart
testWidgets('a new payment opens with the number pad and Save payment off', ...);
  // 'Tap a number to change it', 'RM 0', Save payment disabled; tap '1', '2', '.', '5' → 'RM 12.5', semantics 'Amount RM 12.5', enabled
testWidgets('saving closes the sheet with Expense added', ...); // result PaymentClosed('Expense added')
testWidgets('an edit shows Payment, the direction and date line and Save changes', ...);
  // expense 15.00 at 11 Nov 20:15 → 'Payment', 'Spent · Wed, 11 Nov, 20:15', 'Save changes', no number pad until tap on the amount
testWidgets('delete asks first and then closes with Payment deleted', ...);
// Review Focus 4
testWidgets('Back with typed data asks before it discards', ...);
  // type '5'; tester.binding.handleSystemBackGesture or Navigator.maybePop → 'Discard changes?'; 'Keep editing' → sheet stays with 'RM 5'; again → 'Discard' → result null, 0 payments
testWidgets('X with typed data asks too, and with no change closes at once', ...);
testWidgets('a new category with a shop shows the past payments hint', ...);
testWidgets('the category sheet lists categories by name and marks the chosen one', ...);
testWidgets('the date picker offers no day after today', ...); // showDatePicker lastDate == DateTime(2026, 11, 13)
testWidgets('Count in group totals does not show without groups', ...);
testWidgets('the payment sheet meets the tap target guidelines and works at text scale 1.3', ...);
```

- [ ] **Step 2: Run.** `flutter test test/screens/payment_*` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (18 new tests).
- [ ] **Step 5: Commit.** "Add the payment sheet for new and edited payments".

### Task 7: Home

**Files:**
- Create: `koban/lib/screens/home/home_screen.dart`, `koban/lib/screens/home/home_view_model.dart`
- Modify: `koban/lib/app/home_shell.dart` (Home tab body)
- Test: `koban/test/screens/home_screen_test.dart`, `koban/test/screens/home_view_model_test.dart`

**Interfaces:**
- Consumes: `ExpenseRepository.watchPeriodSummary` / `watchHasAnyPayment`, `CategoryRepository.watchAll`, `ActivitySelection`, `ListenerControl.isAccessGranted()` / `openAccessSettings()`, `AppServices.importResult`, `openPaymentNew` / `openPaymentEdit` (Task 6), `HomeShellState.select`.
- Produces:
  - `class HomeViewModel extends ChangeNotifier { HomeViewModel(AppServices s); bool get isAccessGranted; PeriodSummary? get today, week, month; Map<String, String> get categoryNames; bool get hasAnyPayment /* true while loading */; bool get importFailed; Future<void> refresh() /* access and the current day; the screen calls it on start and on each resume */; void selectActivity({required bool withWeek}); Future<void> openNotificationSettings(); }` — a new day from `now()` at `refresh` rebuilds the 3 period streams (0.1.1 `currentDay`).
  - `HomeScreen` — layout of `HomeScreen.kt` in this order: `LargeTopBar(title: 'Today', subtitle: 'Fri, 13 Nov')`; the import row when `importFailed` (warning icon in error color, text `importFailedMessage`); `ListenerStatusBanner`; the first-payment card (`Mon(MonFace.idle, size: 120)`, `Waiting for your first payment`, `Pay for anything. It shows up here.`, `Add one by hand`) when access is on and there is no payment (plan 4b adds its `Set up later` part and the waiting rows to this condition); the `Spent today` card (`displayLarge` amount, `+ RM 50.00 received`, `No payments yet today.`, the note strip and one line per category; tap label `Open Activity` → Activity with the week); the `This week` and `This month` rows (subtitle, total, `+ RM` received; tap → Activity, the week row with the current week); `Latest this week` with up to 5 `ExpenseListCard(timePattern: 'EEE HH:mm')`; the gold `Add payment` button bottom right; snackbar for the `PaymentClosed.message` that comes back. List bottom padding 112.

- [ ] **Step 1: Write the failing tests.** `now` = Fri 13 Nov 2026 12:00.

```dart
// home_view_model_test.dart
test('the summaries cover today, this week and this month', ...);
test('a new day at refresh moves Today on', ...); // payment at 13 Nov; now → 14 Nov 00:01; refresh → today.total 0
test('select activity with the week shows this month and this week', ...);
  // activitySelection.value: month YearMonth(2026, 11), weekStart Mon 9 Nov 00:00 ms, categoryFilter null

// home_screen_test.dart
testWidgets('Home shows the date and the three totals', ...);
  // 'Today', 'Fri, 13 Nov', 'Spent today', 'RM 12.50', 'This week', 'Mon 9 Nov – Sun 15 Nov', 'This month', 'November 2026'
testWidgets('with no payment today Home says so', ...); // 'No payments yet today.'
testWidgets('money received today shows under the total', ...); // '+ RM 50.00 received'
testWidgets('tracking off shows the banner and Turn on opens the access settings', ...);
  // listener isAccessGranted false → 'Tracking is off'; tap 'Turn on' → listener.calls has 'openAccessSettings'
testWidgets('the first payment card shows only with access and no payment', ...); // 'Waiting for your first payment'
testWidgets('a failed import shows that the data is safe', ...);
  // importResult ImportFailed(['owed_items'], 'x') → find.text(importFailedMessage)
testWidgets('Latest this week shows at most 5 payments with the day and time', ...); // 6 payments → 5 rows, 'Fri 12:00 · Food & Dining'
testWidgets('This week sets the Activity selection to the current week and selects the Activity tab', ...);
  // tap 'This week' → activitySelection.value.weekStart == Mon 9 Nov 00:00; HomeShellState tab == KobanTab.activity
testWidgets('Add payment saves a payment and Home says Expense added', ...);
  // tap 'Add payment', keys '1' '2' '.' '5', 'Save payment', settle → snackbar 'Expense added', 'RM 12.50' under 'Spent today'
testWidgets('a resume reads the access again', ...);
  // access false → banner; set answer true; tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed) → 'Tracking on'
testWidgets('Home meets the tap target guidelines and works at text scale 1.3', ...);
```

- [ ] **Step 2: Run.** `flutter test test/screens/home_*` → FAIL.
- [ ] **Step 3: Implement.** The screen calls `refresh` from an `AppLifecycleListener(onResume:)`.
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (14 new tests).
- [ ] **Step 5: Commit.** "Add the Home screen".

### Task 8: Activity

**Files:**
- Create: `koban/lib/screens/activity/activity_screen.dart`, `koban/lib/screens/activity/activity_view_model.dart`, `koban/lib/screens/activity/activity_sheets.dart` (category filter sheet, month sheet)
- Modify: `koban/lib/app/home_shell.dart` (Activity tab body)
- Test: `koban/test/screens/activity_screen_test.dart`, `koban/test/screens/activity_view_model_test.dart`

**Interfaces:**
- Consumes: `ExpenseRepository` (`watchTotalForRange`, `watchReceivedForRange`, `watchInRange`, `weekSummariesForMonth`, `watchCategoryBreakdown`, `watchAllActive`, `watchMonthlySummaries`), `ActivitySelection`, `donutSlices`, `CategoryDonut`, `expensesByDay`, `MonthNav`, `PeriodCalculator`.
- Produces:
  - `class ActivityViewModel extends ChangeNotifier { ActivityViewModel(AppServices s); ActivityUiState get state; List<ActivityMonthGroup>? get allMonths /* null while loading or in the Month view */; FilterTotals get filterTotals; List<MonthSummary> get sheetMonths; List<Category> get categories; void previousMonth(); void nextMonth(); void pickMonth(YearMonth m); void toggleWeek(int weekStart); void setCategoryFilter(String? f); void setShowAll(bool v); String categoryNameFor(Expense e); }` with `ActivityUiState`, `ActivityMonthGroup`, `FilterTotals` as in `ActivityViewModel.kt` (the header totals follow the list range; the list watches the full Monday-to-Sunday span; stepping months keeps the category filter; `sheetMonths` adds the current month when it has no payment).
  - `ActivityScreen` — layout of `ActivityScreen.kt`: `LargeTopBar(title: 'Activity', actions: [Filter button, label 'Filter by category'])`; `SegmentedControl(['Month', 'All'])`; the filter chip (`Filtered by $name. Clear filter`); the month bar (`Previous month`, `Pick a month`, `Next month`; Next off at the current month); the chart card (ring, `Spent` or `Spent, 9 Nov – 15 Nov`, the total, `+ RM … received`); the week strip (`Whole month` and one chip per week, `9 Nov – 15 Nov`); the list by day; empty texts `No payments in this category.`, `No payments in this week.`, `No payments in November 2026.`, `No payments yet.`; the All view with one sticky header per month (label and spent total); sheets `Show one category` (`All categories` first, `—` with label `No spending` for 0) and `Pick a month`; the `Add payment` button; tap on a row → `openPaymentEdit`; the returned message as a snackbar.

- [ ] **Step 1: Write the failing tests.** Port the cases of `MonthNavTest.kt` only where the screen adds a rule (the rules are already tested in `koban/test/rules/periods_test.dart`).

```dart
// activity_view_model_test.dart
test('the month view lists the month payments, newest first', ...);
test('a week toggle filters the list and the header total, and a second tap clears it', ...);
test('stepping months keeps the category filter', ...);
test('next month stops at the current month', ...); // state.canGoNext false in November 2026; previousMonth → true
test('the All view groups every payment by month with the month totals', ...);
test('the filter sheet uses all-time totals in the All view', ...);
test('the month sheet adds the current month when it has no payment', ...);

// activity_screen_test.dart
testWidgets('payments show by day under Today, Yesterday and the date', ...);
testWidgets('a week chip shows Spent with the week dates', ...); // 'Spent, 9 Nov – 15 Nov'
testWidgets('This week on Home opens Activity on the current week', ...); // in HomeShell: tap 'This week' → 'Spent, 9 Nov – 15 Nov'
testWidgets('an empty month says No payments in November 2026.', ...);
testWidgets('Next month is off at the current month', ...);
testWidgets('the category sheet filters the list and the chip clears it', ...);
  // 'Filter' → 'Show one category' → 'Food & Dining' → only food rows; chip label 'Filtered by Food & Dining. Clear filter' → tap → all rows
testWidgets('the All view shows a header for each month', ...); // 'November 2026', 'October 2026'
testWidgets('a tap on a payment opens it in the payment sheet', ...); // 'Payment', 'Save changes'
testWidgets('Activity meets the tap target guidelines and works at text scale 1.3', ...);
```

- [ ] **Step 2: Run.** `flutter test test/screens/activity_*` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (17 new tests).
- [ ] **Step 5: Run the debug build once.** `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk` exists. Do not install it.
- [ ] **Step 6: Check the Kotlin app is untouched.** `git diff --stat main -- app/ gradle/` → empty.
- [ ] **Step 7: Commit.** "Add the Activity screen".

## Known limits

- The People tab is empty until plan 4c. Home has no Settings button and no waiting-payments row until plan 4b.
- The 0.1.1 auto-open on app start (onboarding, payment apps, Check payments) comes in plan 4b Task 7.
- `inGroups` is always false, so `Count in group totals` never shows until milestone 5.
- Rows written by the capture isolate do not refresh the UI streams yet; plan 4b Task 2 adds that.
