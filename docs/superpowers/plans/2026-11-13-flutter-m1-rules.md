# Flutter milestone 1: project, tokens and rules — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the Flutter project `koban/`, put the Koban design tokens in it, and port all pure Kotlin rule code to pure Dart with every one of its test cases passing.

**Architecture:** One Flutter project in `koban/` at the repository root, next to the Kotlin app in `app/` (which does not change). Rule code goes in `koban/lib/rules/` as pure Dart (no Flutter import), one Dart file per Kotlin file, with the same names and the same behavior. Tests in `koban/test/rules/` repeat the Kotlin test cases one to one.

**Tech Stack:** Flutter stable (the newest stable on the day Task 1 runs), Dart, package `decimal` (exact money math, replaces `java.math.BigDecimal`), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-13-flutter-migration-design.md` (sections 6.1, 6.2 and 6.7 step 1).

**Later milestones:** 2 (database and import), 3 (Android capture), 4 (screens and components), 5 (online parts), 6 (Android switch release) and 7 (iPhone sideload test) each get their own plan when the milestone before them is done.

## Global Constraints

- Work on branch `feature/flutter-m1`, made from `main`.
- Commits: only when the owner allowed commits for this plan run. Without that permission, stage the files (`git add`) at each "Commit" step and leave the commit to the owner.
- `koban/lib/rules/` and `koban/lib/theme/tokens.dart` import no `package:flutter` and no `dart:io`, `dart:ui` or `dart:html`. They must run on Android, iPhone and the Dart VM.
- Money is `Decimal` from package `decimal`, never `double`. Scale and rounding match the Kotlin code exactly (for example `AmountFormatter.toMoney` = 2 decimal places, `RoundingMode.HALF_UP`).
- Each Kotlin `@Test` becomes one Dart `test()` with the same inputs and the same expected values. Test names: the Kotlin method name in words (for example `weekStartsOnMonday` → `'week starts on Monday'`). Do not drop, merge or change a case. If a case cannot pass in Dart, stop and report it; do not edit the expected value.
- Kotlin regex flags do not exist in Dart: `(?i)` becomes `RegExp(..., caseSensitive: false)`, `\p{...}` needs `unicode: true`, `RegexOption.MULTILINE` becomes `multiLine: true`. Check every pattern for inline flags.
- Time: `Calendar.getInstance()` and `LocalDate.now()` default to the phone's local time in Kotlin; use local `DateTime` in Dart. Group periods use Malaysia time (`ZONE` in `GroupRepository.kt`): UTC+8, no daylight saving, so use a fixed +8 hour offset, not a time zone package.
- Do not change anything under `app/`.
- Doc comments and test names in ASD-STE100 Simplified Technical English.
- The machine has limited resources: run at most one Gradle or Flutter build at a time.

## Review Focus

1. Amounts with thousands separators and no decimals (`RM1,234`, `RM 1,234.5`) — must parse to the same `Decimal` as Kotlin (`1234.00`, `1234.50`). Pinned in Task 2.
2. Notification text with mixed case and non-ASCII characters (`Pembayaran`, `é`, emoji, non-breaking space `\u00a0`) — must match the same rules as Kotlin; Dart `RegExp` differs on case flags and Unicode. Pinned in Task 4.
3. Split shares that do not divide evenly (RM 10.00 shared by 3) — the cents must be given out exactly as `SplitMath.shares` does, and the shares must add up to the total. Pinned in Task 6.
4. A week or month boundary at local midnight (Sunday 23:59 vs Monday 00:00) — `PeriodCalculator.range` must put a payment in the same period as Kotlin. Pinned in Task 7.
5. A Dart file in `lib/rules/` that imports Flutter by mistake — the iPhone and background parser need pure Dart. Pinned in Task 1.

---

### Task 1: Flutter project, tokens and the purity check

**Files:**
- Create: `koban/` (from `flutter create`), `koban/analysis_options.yaml`, `koban/lib/theme/tokens.dart`, `koban/assets/fonts/BricolageGrotesque.ttf` (copy of `app/src/main/res/font/bricolage_grotesque.ttf`), `koban/test/theme/tokens_test.dart`, `koban/test/rules/purity_test.dart`, `.github/workflows/flutter.yml`
- Modify: `.gitignore` (add Flutter build output: `koban/build/`, `koban/.dart_tool/`)

**Interfaces:**
- Produces: `class KobanColors` with `static const dark` and `static const light`, each a `KobanPalette` with one `int` field (no Flutter `Color` type) per token in `docs/DESIGN.md` "Tokens > Colors" (`night`, `surface`, `surface2`, `line`, `ink`, `muted`, `gold`, `onGold`, `goldSoft`, `goldText`, `received`, `error`, `review`, `catFood`, `catTransport`, `catShopping`, `catBills`, `catHealth`, `catFun`, `catCustom`, `catOther`, `coinRim`, `coinShade`, `coinShine`), as `0xFFrrggbb` ints; `class KobanType` with one `KobanTextStyle(size, lineHeight, weight, tracking)` per style in "Tokens > Type"; `class KobanSpace` (`s4, s8, s12, s16, s24, s32`) and `class KobanRadius` (`r8, r12, r16, r24, full = 999`). Milestone 4 turns these into a Flutter `ThemeData`.

- [ ] **Step 1: Install the tools.** Install Flutter stable to `D:\flutter` and a JDK 17 to `D:\jdk-17` (the JDK in the session scratchpad is temporary). Run `flutter config --android-sdk D:\Android --jdk-dir D:\jdk-17`, then `flutter doctor`. Expected: "Flutter" and "Android toolchain" are green. Xcode and Chrome lines may be red; that is fine.
- [ ] **Step 2: Create the project.** From the repository root: `flutter create --org io.github.skooyo --project-name koban --platforms android,ios koban`. Add `decimal` to `dependencies`. Add `flutter_lints` rules in `analysis_options.yaml` (keep the default set).
- [ ] **Step 3: Write the failing tests.**

```dart
// koban/test/theme/tokens_test.dart
test('dark and light palettes use the DESIGN.md values', () {
  expect(KobanColors.dark.night, 0xFF141B2B);
  expect(KobanColors.light.night, 0xFFF6F7FA);
  expect(KobanColors.dark.gold, 0xFFF2C94C);
  expect(KobanColors.light.goldText, 0xFF7A5D00);
  expect(KobanColors.dark.catOther, 0xFF8A96A8);
});
test('type scale uses the DESIGN.md values', () {
  expect(KobanType.displayLarge.size, 57);
  expect(KobanType.displayLarge.lineHeight, 64);
  expect(KobanType.displayLarge.weight, 700);
  expect(KobanType.labelSmall.size, 11);
});
test('spacing and radius use the DESIGN.md values', () {
  expect(KobanSpace.s16, 16);
  expect(KobanRadius.r24, 24);
  expect(KobanRadius.full, 999);
});

// koban/test/rules/purity_test.dart
test('rule files import no Flutter and no platform library', () {
  final bad = RegExp(r"import\s+'(package:flutter|dart:io|dart:ui|dart:html)");
  final files = Directory('lib/rules').listSync(recursive: true).whereType<File>()
      .followedBy([File('lib/theme/tokens.dart')]);
  final offenders = [for (final f in files) if (bad.hasMatch(f.readAsStringSync())) f.path];
  expect(offenders, isEmpty);
});
```

- [ ] **Step 4: Run them.** `cd koban && flutter test`. Expected: FAIL, `KobanColors` not defined.
- [ ] **Step 5: Write `koban/lib/theme/tokens.dart`** with every token from `docs/DESIGN.md` "Tokens" (colors, type, spacing, radius), exact values. Create an empty `koban/lib/rules/` folder with a `README.md` that says "Pure Dart only. See docs/superpowers/plans/2026-11-13-flutter-m1-rules.md."
- [ ] **Step 6: Run the tests.** `flutter test` → PASS. `flutter analyze` → "No issues found!".
- [ ] **Step 7: Add CI.** `.github/workflows/flutter.yml`: on push and pull request when `koban/**` changes; `ubuntu-latest`; `subosito/flutter-action` with `channel: stable`; `working-directory: koban`; run `flutter pub get`, `flutter analyze`, `flutter test`.
- [ ] **Step 8: Build once.** `flutter build apk --debug`. Expected: `koban/build/app/outputs/flutter-apk/app-debug.apk` exists. Do not install it on a phone (milestone 3 sets the app ID).
- [ ] **Step 9: Commit.** `git add .gitignore .github/workflows/flutter.yml koban` → message "Create the Flutter project with Koban tokens".

### Task 2: Money and basic types

**Files:**
- Create: `koban/lib/rules/amount_formatter.dart`, `koban/lib/rules/types.dart`, `koban/lib/rules/parsed_expense.dart`
- Test: `koban/test/rules/amount_formatter_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `types.dart`: `enum TransactionType`, `enum ParseConfidence`, `enum ExpenseStatus`, `enum CaptureFormat { known, unknown }` with the same members as `data/TransactionType.kt`, `data/ParseConfidence.kt`, `data/ExpenseStatus.kt`, `parser/PaymentRules.kt` (Dart lowerCamel names; `.name` maps back to the Kotlin name in milestone 2 with an explicit table).
  - `parsed_expense.dart`: `class ParsedExpense` with the fields of `parser/ParsedExpense.kt` (`Decimal` for amounts).
  - `amount_formatter.dart`: `abstract final class AmountFormatter` with `static Decimal toMoney(Decimal v)`, `static String formatDisplay(Decimal v)`, `static String formatGrouped(Decimal v)`, `static String currencySymbol(String currency)`, `static Decimal? parseInput(String raw)`.

- [ ] **Step 1: Port the 5 cases of `app/src/test/java/com/expensetracker/app/parser/AmountFormatterTest.kt`** to `amount_formatter_test.dart`. Add the Review Focus 1 case:

```dart
test('input with thousands separators parses like Kotlin', () {
  expect(AmountFormatter.parseInput('1,234'), Decimal.parse('1234'));
  expect(AmountFormatter.toMoney(Decimal.parse('1234.5')).toString(), '1234.50');
});
```

- [ ] **Step 2: Run.** `flutter test test/rules/amount_formatter_test.dart` → FAIL (not defined).
- [ ] **Step 3: Write the 3 files**, porting `parser/AmountFormatter.kt` line by line. `toMoney`: 2 places, half up (`Decimal.round(scale: 2)` rounds half away from zero, which equals HALF_UP for these values; confirm with a negative case from the Kotlin test).
- [ ] **Step 4: Run.** → PASS (6 tests).
- [ ] **Step 5: Commit.** "Port the money formatter and basic types to Dart".

### Task 3: Shop names and duplicate keys

**Files:**
- Create: `koban/lib/rules/merchant_normalizer.dart`, `koban/lib/rules/dedup_key_generator.dart`
- Test: `koban/test/rules/merchant_normalizer_test.dart`, `koban/test/rules/dedup_key_generator_test.dart`

**Interfaces:**
- Produces: `MerchantNormalizer.clean(String? raw) → String?`; `DedupKeyGenerator.generate(...)` with the same parameters as `parser/DedupKeyGenerator.kt` (Dart named parameters, same names), returning the same `String`; `DedupKeyGenerator.dedupLookbackMs() → int`.

- [ ] **Step 1: Port the 6 cases of `MerchantNormalizerTest.kt` and the 3 cases of `DedupKeyGeneratorTest.kt`.** The dedup key must be byte-for-byte the same string as Kotlin's, because milestone 2 imports old rows and compares keys. Add one test that checks a key from a fixed input against a literal string produced by the Kotlin code (run the Kotlin test once with a print to get it).
- [ ] **Step 2: Run** → FAIL. **Step 3: Port both files.** If the Kotlin code hashes, use the same algorithm and the same text encoding (UTF-8) from package `crypto`. **Step 4: Run** → PASS (10 tests). **Step 5: Commit** "Port shop name cleanup and duplicate keys to Dart".

### Task 4: Notification parser and payment rules

**Files:**
- Create: `koban/lib/rules/notification_parser.dart`, `koban/lib/rules/payment_rules.dart`
- Test: `koban/test/rules/notification_parser_test.dart`, `koban/test/rules/payment_rules_test.dart`

**Interfaces:**
- Consumes: Task 2 (`ParsedExpense`, `TransactionType`, `CaptureFormat`), Task 3 (`MerchantNormalizer`).
- Produces: `NotificationParser.parse(String body) → ParsedExpense?`, `detectTransactionType(String) → TransactionType`, `isDirectionClear(String) → bool`, `findAllAmounts(String) → List<Decimal>`, `normalizeAmount(String) → Decimal?`, `extractMerchantFromBody(String body, Decimal amount) → String?`; `sealed class RuleMatch` with the same subclasses and fields as `parser/PaymentRules.kt`; `PaymentRules.match(String packageName, String text) → RuleMatch`.

- [ ] **Step 1: Port the 16 cases of `NotificationParserTest.kt` and the 32 cases of `PaymentRulesTest.kt`.** Add the Review Focus 2 case, with the expected results taken from running the same inputs through the Kotlin code once:

```dart
test('text with a non-breaking space and mixed case parses like Kotlin', () {
  final r = NotificationParser.parse('Pembayaran RM\u00a012.50 kepada KEDAI Café berjaya');
  // Expected values: run the same input through the Kotlin NotificationParser once and copy its
  // result (amount, merchant, or null). Do not guess them.
  expect(r?.amount, /* Kotlin result */);
});
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Port both files.** Convert every Kotlin pattern with the regex rules in Global Constraints. Keep the rule order of `PaymentRules` exactly. **Step 4: Run** → PASS (49 tests). **Step 5: Commit** "Port the notification parser and payment rules to Dart".

### Task 5: Receipt rules

**Files:**
- Create: `koban/lib/rules/receipt_rules.dart`
- Test: `koban/test/rules/receipt_rules_test.dart`, `koban/test/rules/receipt_scan_test.dart`

**Interfaces:**
- Produces: `class ReceiptItemDraft(name, quantity, price)`, `class ReceiptDraft` (fields of `parser/ReceiptRules.kt`), `class OcrLine(text, left, top, right, bottom, {angle = 0.0})`, `class ReceiptRead(draft, accepted, calculated)`, `ReceiptRules.read(List<OcrLine> lines, {int? now}) → ReceiptRead?` (`now` in milliseconds since epoch; default `DateTime.now().millisecondsSinceEpoch`).

- [ ] **Step 1: Port the 27 cases of `ReceiptRulesTest.kt`** and the cases of `ReceiptTiltScanTest.kt` (2), `ReceiptLevelScanTest.kt` (1) and `ReceiptCloudChoiceTest.kt` (2) into `receipt_scan_test.dart`. Port `ReceiptBenchmarkTest.kt` (1) too, with the same skip rule: skip when the git-ignored `receipt-bench` folder is missing.
- [ ] **Step 2: Run** → FAIL. **Step 3: Port `parser/ReceiptRules.kt`** (395 lines) line by line. **Step 4: Run** → PASS (33 tests, the benchmark skipped if the folder is missing). **Step 5: Commit** "Port the receipt rules to Dart".

### Task 6: Splits, people and repayments

**Files:**
- Create: `koban/lib/rules/split_math.dart`, `koban/lib/rules/people_math.dart`, `koban/lib/rules/repayment_matcher.dart`
- Test: `koban/test/rules/split_math_test.dart`, `koban/test/rules/people_math_test.dart`, `koban/test/rules/repayment_matcher_test.dart`

**Interfaces:**
- Produces: `SplitItemInput(price, sharedBy)`, `SplitCharges` (fields of `data/SplitMath.kt`), `SplitMath.computedTotal`, `SplitMath.shares → Map<String, Decimal>`, `SplitMath.unassignedItemIndexes → List<int>`, `SplitMath.ownerSpending`; `sealed class Balance`, `PeopleMath.normalizedName`, `net`, `balance`, `statusLine`, `headline`, `group`, `settleMatch` (same parameters as `data/PeopleMath.kt`); `OpenDebtRef`, `RepaymentMatcher.match(Decimal amount, String? senderName, List<OpenDebtRef>) → List<String>`.

- [ ] **Step 1: Port the 11 cases of `SplitMathTest.kt`, the 13 of `PeopleMathTest.kt` and the 6 of `RepaymentMatcherTest.kt`.** Add the Review Focus 3 case:

```dart
test('RM 10.00 shared by 3 gives out every cent', () {
  final shares = SplitMath.shares(
    [SplitItemInput(price: Decimal.parse('10.00'), sharedBy: {'a', 'b', 'c'})],
    SplitCharges(),
  );
  expect(shares.values.fold(Decimal.zero, (s, v) => s + v), Decimal.parse('10.00'));
  // The order of the extra cent must match Kotlin: copy the 3 values from the Kotlin result.
});
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Port the 3 files.** Keep Kotlin's iteration order for maps and sets (use `LinkedHashMap`/`LinkedHashSet` order, which is the Dart default). **Step 4: Run** → PASS (31 tests). **Step 5: Commit** "Port split, people and repayment math to Dart".

### Task 7: Periods

**Files:**
- Create: `koban/lib/rules/periods.dart`
- Test: `koban/test/rules/periods_test.dart`

**Interfaces:**
- Produces: `enum SpendingPeriod` (members of `data/SpendingPeriod.kt`); `PeriodCalculator.range(SpendingPeriod, {DateTime? anchor}) → (int startMs, int endMs)`, `rangeForMonth(int year, int month)`, `weeksInMonth(int year, int month) → List<(int, int)>`, `weekLabel`, `monthLabel`, `title`, `label`, `decodeYearMonth(int) → (int, int)`; `MonthNav.previous`, `MonthNav.next(m, current) → YearMonth?`, `MonthNav.label` with a small `YearMonth(year, month)` value class; `GroupPeriodMath.start(...)` and `GroupPeriodMath.daysLeft(Period, {DateTime? today})` ported from the period helpers in `groups/GroupRepository.kt` (Malaysia time, fixed UTC+8).

- [ ] **Step 1: Port the 2 cases of `PeriodCalculatorTest.kt`, the 5 of `MonthNavTest.kt` and the 3 of `groups/PeriodMathTest.kt`.** Labels must be English (`Locale.getDefault()` is English on the owner's phone; use package `intl` with locale `en`). Add the Review Focus 4 case:

```dart
test('Sunday 23:59 is in the old week and Monday 00:00 in the new one', () {
  final sun = DateTime(2026, 11, 15, 23, 59);
  final mon = DateTime(2026, 11, 16, 0, 0);
  final (start, end) = PeriodCalculator.range(SpendingPeriod.week, anchor: sun);
  expect(sun.millisecondsSinceEpoch >= start && sun.millisecondsSinceEpoch < end, isTrue);
  expect(mon.millisecondsSinceEpoch >= end, isTrue);
});
```

  (Check `SpendingPeriod.kt` for whether `end` is inclusive; write the comparison the same way the Kotlin code does.)
- [ ] **Step 2: Run** → FAIL. **Step 3: Port.** **Step 4: Run** → PASS (11 tests). **Step 5: Commit** "Port spending periods and month navigation to Dart".

### Task 8: Parity check and branch finish

**Files:**
- Create: `koban/test/rules/PORTED.md` — one line per Kotlin test file: the Kotlin file, its `@Test` count, the Dart file, its `test(` count.

- [ ] **Step 1: Fill `PORTED.md`.** Expected Kotlin counts: AmountFormatter 5, MerchantNormalizer 6, DedupKeyGenerator 3, NotificationParser 16, PaymentRules 32, ReceiptRules 27, ReceiptTiltScan 2, ReceiptLevelScan 1, ReceiptCloudChoice 2, ReceiptBenchmark 1, SplitMath 11, PeopleMath 13, RepaymentMatcher 6, PeriodCalculator 2, MonthNav 5, PeriodMath 3 = 135. The Dart count is 135, plus 5 added tests (Tasks 2, 3, 4, 6 and 7), plus the 4 tests of Task 1 = 144.
- [ ] **Step 2: Run everything.** `cd koban && flutter analyze && flutter test`. Expected: "No issues found!" and "All tests passed!" with 144 tests (143 if `receipt-bench` is missing).
- [ ] **Step 3: Check the Kotlin app is untouched.** `git diff --stat main -- app/` → empty.
- [ ] **Step 4: Commit and push.** Commit "List the ported tests"; push `feature/flutter-m1` and open a PR into `main` only if the owner allowed it for this run.

The other Kotlin tests (update: ReleaseParser 6, UpdateSchedule 5, ApkCheck 4; screen rules: OnboardingRules 19, AmountInput 11, CacheFile 5, PaymentAppsRules 3, DonutSlices 3, SplitReadNote 1) move with their features in milestones 4 and 5.
