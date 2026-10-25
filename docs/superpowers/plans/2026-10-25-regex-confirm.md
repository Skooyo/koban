# Regex Capture and Swipe Confirm Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Gemini auto-save with strict regex rules that store waiting payments, confirmed one by one on a swipe screen, with a payment-apps picker and an optional user-keyed Gemini pre-fill.

**Architecture:** A pure `PaymentRules` object turns (package, text) into a match. The listener stores matches in a new `pending_payments` table (Room v9), never in `expenses`. A `PendingPaymentRepository` owns dedup, drop markers, the 4-second hold, and the commit into `expenses` through `ExpenseRepository.saveConfirmed`. A new `check` route shows the swipe stack; Home shows a live count banner.

**Tech Stack:** Kotlin, Jetpack Compose M3, Navigation Compose, Hilt, Room, DataStore, JUnit 4 (JVM unit tests only).

**Spec:** `docs/superpowers/specs/2026-10-25-regex-confirm-design.md`

## Global Constraints

- No instrumented tests. JVM unit tests only (`app/src/test`). No new test libraries (no Robolectric, no coroutines-test).
- No new runtime dependencies.
- Tests and code comments use made-up merchants and names only. Never copy a real notification from the owner's phone.
- Money is `BigDecimal`, stored as TEXT; use `AmountFormatter.toMoney` for every stored amount.
- Do not run `git commit`. Each task ends by staging its files (`git add`). The owner commits.
- Build and test command (PowerShell, repo root): `$env:JAVA_HOME="C:\Users\daven\AppData\Local\Temp\claude\d--Projects-Expense-Tracker\783d92a6-f61a-4a33-bbf4-ccfcdb48ee2a\scratchpad\jdk\jdk-17.0.20.1+1"; .\gradlew.bat assembleDebug testDebugUnitTest -q`
- Known packages: Maybank `com.maybank2u.life`, Touch 'n Go `my.com.tngdigital.ewallet`, Google Wallet `com.google.android.apps.walletnfcrel` (known, no rules).
- Undo window: 4 seconds. Drop markers expire after 30 days. Waiting payments never expire.
- Gemini pre-fill is off by default in every build.
- Copy: banner "N payments to check" ("1 payment to check" for one); stamps "SAVE" and "NOT A PAYMENT"; tags "Unknown format" and "Likely promotion"; Settings entry "Payment apps"; disposition label "Waiting for check".

## Review Focus

1. A notification Android posts twice (same key, or same amount within 30 minutes) must give one card, not two. Pinned on the phone in Task 7, step 3.
2. A swipe right on a card whose payment already exists as an expense (for example, typed in by hand on the add page) must save nothing and say so. Pinned in Task 7, step 4.
3. A swipe followed at once by closing the app must still commit. Pinned in Task 7, step 5.
4. A Maybank promotion with "RM" and a payment word ("Pay RM1 and win…") must not match. Pinned in Task 1, test `maybank_promotionWithPaymentWord_noMatch`.
5. A merchant that ends in a date ("KEDAI CONTOH 20/10/2026") must be stored without the date. Pinned in Task 1, test `clean_stripsTrailingDate`.

---

## File Structure

| File | Responsibility |
|---|---|
| `app/src/main/java/com/expensetracker/app/parser/PaymentRules.kt` (new) | Known-app strict rules and the generic fallback. Pure. |
| `app/src/main/java/com/expensetracker/app/parser/MerchantNormalizer.kt` | Also strips dates and times from a merchant. |
| `app/src/main/java/com/expensetracker/app/data/PendingPayment.kt` (new) | `PendingPaymentEntity`, `DroppedNotificationEntity`, `CaptureFormat`, `PendingPaymentDao`. |
| `app/src/main/java/com/expensetracker/app/data/PendingPaymentRepository.kt` (new) | Capture with dedup, list and count flows, edit, hold, undo, commit, drop markers. |
| `app/src/main/java/com/expensetracker/app/data/ExpenseRepository.kt` | `saveConfirmed` replaces `saveFromNotification`. |
| `app/src/main/java/com/expensetracker/app/listener/ExpenseNotificationListener.kt` | Uses `PaymentRules` and the pending repository; no Gemini parse. |
| `app/src/main/java/com/expensetracker/app/ui/screens/CheckPaymentsScreen.kt` (new) + `ui/viewmodel/CheckPaymentsViewModel.kt` (new) | The swipe stack. |
| `app/src/main/java/com/expensetracker/app/ui/screens/PaymentAppsScreen.kt` (new) + `ui/viewmodel/PaymentAppsViewModel.kt` (new) | The installed-apps picker. |
| `app/src/main/java/com/expensetracker/app/data/SettingsRepository.kt` | Picker state, Gemini switch, key storage. |
| `app/src/main/java/com/expensetracker/app/parser/GeminiClient.kt` | Key comes from settings, not only `BuildConfig`. |

---

### Task 1: Payment rules and date-free merchants

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/parser/PaymentRules.kt`
- Modify: `app/src/main/java/com/expensetracker/app/parser/MerchantNormalizer.kt` (`clean`)
- Test: `app/src/test/java/com/expensetracker/app/parser/PaymentRulesTest.kt` (new), `MerchantNormalizerTest.kt` (add)

**Interfaces:**
- Produces:
  - `enum class CaptureFormat { KNOWN, UNKNOWN }` (in `PaymentRules.kt`; Task 2 stores it).
  - `sealed interface RuleMatch { data class Matched(val expense: ParsedExpense, val format: CaptureFormat) : RuleMatch; data object NoMatch : RuleMatch }`
  - `object PaymentRules { val KNOWN_PACKAGES: Set<String>; val PRESELECT_PACKAGES: Set<String>; fun match(packageName: String, text: String): RuleMatch }`
  - `PRESELECT_PACKAGES` = Maybank and Touch 'n Go (not Google Wallet).

- [ ] **Step 1: Write the failing tests** in `PaymentRulesTest.kt`. One test per shape. Each asserts `format == KNOWN`, the exact amount (`BigDecimal`), merchant, and `TransactionType`:

| Test | Package | Text | Amount | Merchant | Type |
|---|---|---|---|---|---|
| `maybank_cardSpend` | Maybank | `You've just spent RM 23.40 at KEDAI RUNCIT AMAN with your Maybank Debit Card Visa ending 1234. View your receipt now.` | 23.40 | `KEDAI RUNCIT AMAN` | WITHDRAW |
| `maybank_qrPayment` | Maybank | `Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.` | 15.00 | `RESTORAN CONTOH` | WITHDRAW |
| `maybank_qrPaymentRefSuffix` | Maybank | `Successful payment of RM 8.00 to KOPI CONTOH. REF: 123456Q.` | 8.00 | `KOPI CONTOH` | WITHDRAW |
| `maybank_m2uPaid` | Maybank | `M2U: You have successfully paid RM12.00 to CONTOH SDN BHD.` | 12.00 | `CONTOH SDN BHD` | WITHDRAW |
| `maybank_transfer` | Maybank | `You've transferred RM 50.00 to ALI BIN ABU. REF: 123456M` | 50.00 | `ALI BIN ABU` | WITHDRAW |
| `maybank_withdrawal` | Maybank | `You've successfully withdrawn RM 100.00 from your account ending 1234.` | 100.00 | `ATM withdrawal` | WITHDRAW |
| `maybank_received` | Maybank | `You've received RM 40.00 from SITI AMINAH. REF: 123456Q` | 40.00 | `SITI AMINAH` | RECEIVE |
| `maybank_receivedToAccount` | Maybank | `You've just received RM 40.00 in your account ending ***1234. REF: 123ABC456` | 40.00 | `null` | RECEIVE |
| `tng_paid` | TNG | `You have paid RM12.50 to CONTOH CAFE.` | 12.50 | `CONTOH CAFE` | WITHDRAW |
| `tng_transferred` | TNG | `RM 30.00 has been successfully transferred to ALI BIN ABU.` | 30.00 | `ALI BIN ABU` | WITHDRAW |
| `tng_transferredWithPrefix` | TNG | `Transfer Successful. RM 30.00 has been successfully transferred to ALI BIN ABU.` | 30.00 | `ALI BIN ABU` | WITHDRAW |
| `tng_received` | TNG | `RM 20.00 received from SITI AMINAH.` | 20.00 | `SITI AMINAH` | RECEIVE |

Also, each asserting `RuleMatch.NoMatch`:
- `maybank_transferLimit_noMatch`: `Your new transfer limit of RM 5000.00 for Interbank Transfer will be reflected after 12 hour(s). Not you? Call Maybank now.`
- `maybank_rateOffer_noMatch`: `Get eIFD-i rates up to 3.85% via FPX.`
- `maybank_promotionWithPaymentWord_noMatch`: `Pay RM1 and win a trip! Spend RM 50 at any partner to join.`
- `tng_goldPromo_noMatch`: `Harga emas turun hari ini. Miliki emas mulai RM10 saja dengan TNG eWallet!`
- `tng_discountPromo_noMatch`: `Kamu kebagian akses ke Payday Flash Deals! Klaim diskon RM50 buat tiket pesawat.`
- `googleWallet_cardTap_noMatch`: package Google Wallet, `MYR23.40 with Maybank Visa Platinum Debit ••1234`

Generic rule:
- `unknownApp_genericMatch`: package `com.example.bank`, `You spent RM 14.23 at Contoh Mart` → `format == UNKNOWN`, 14.23, `Contoh Mart`, WITHDRAW.
- `unknownApp_noAmount_noMatch`: package `com.example.bank`, `Your statement is ready` → `NoMatch`.

- [ ] **Step 2: Add to `MerchantNormalizerTest.kt`:**
  - `clean_stripsTrailingDate`: `clean("KEDAI CONTOH 20/10/2026") == "KEDAI CONTOH"`
  - `clean_stripsDateAndTime`: `clean("KEDAI CONTOH on 20 Oct 2026, 12:45") == "KEDAI CONTOH"`
  - `clean_keepsNumbersInName`: `clean("99 SPEEDMART 1234") == "99 SPEEDMART 1234"`

- [ ] **Step 3: Run the tests to see them fail.** Run the build command. Expected: compile failure, `PaymentRules` unresolved.

- [ ] **Step 4: Implement `PaymentRules`.** One list of `Regex` per known package, each with named groups `amount` and optional `merchant`, plus a fixed `TransactionType` and an optional fixed merchant (`ATM withdrawal`). The merchant group is passed through `MerchantNormalizer.clean`. A known package tries only its own list; Google Wallet has an empty list. An unknown package uses `NotificationParser.parse` and returns `UNKNOWN`. Amounts go through `AmountFormatter` parsing, as `NotificationParser` does today. Confidence is `HIGH` for KNOWN and the parser's value for UNKNOWN.

- [ ] **Step 5: Extend `MerchantNormalizer.clean`** to remove date patterns (`d/m/yyyy`, `d-m-yyyy`, `d MMM yyyy` with an optional leading "on"), time patterns (`HH:mm`), and the separators left around them. Keep digits that are part of a name.

- [ ] **Step 6: Run the tests to see them pass.** Expected: all `PaymentRulesTest`, `MerchantNormalizerTest` and old tests PASS.

- [ ] **Step 7: Stage.** `git add app/src/main/java/com/expensetracker/app/parser app/src/test/java/com/expensetracker/app/parser`

---

### Task 2: Waiting payments storage and confirmed save

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/data/PendingPayment.kt`, `app/src/main/java/com/expensetracker/app/data/PendingPaymentRepository.kt`
- Modify: `data/ExpenseDatabase.kt` (version 9, two entities, `pendingPaymentDao()`), `data/DatabaseMigrations.kt` (`MIGRATION_8_9`), `di/AppModule.kt` (register migration, provide DAO), `data/ExpenseRepository.kt` (`saveConfirmed` replaces `saveFromNotification`), `data/Converters.kt` (converter for `CaptureFormat`)

**Interfaces:**
- Consumes: `CaptureFormat`, `ParsedExpense` (Task 1).
- Produces:
  - `@Entity(tableName = "pending_payments", indices = [Index("notificationKey")]) data class PendingPaymentEntity(id: String, amount: BigDecimal, currency: String, merchant: String?, transactionType: TransactionType, sourcePackage: String, rawNotificationText: String, notificationPostTime: Long, notificationKey: String?, dedupKey: String, format: CaptureFormat, categoryId: String?, likelyPromotion: Boolean, createdAt: Long)`
  - `@Entity(tableName = "dropped_notifications") data class DroppedNotificationEntity(@PrimaryKey dedupKey: String, notificationKey: String?, droppedAt: Long)`
  - `PendingPaymentRepository`:
    - `suspend fun capture(parsed: ParsedExpense, format: CaptureFormat, rawText: String, sourcePackage: String, notificationPostTime: Long, notificationKey: String?): String?` returns the new id, or null when it is a duplicate of an expense, a waiting payment, or a dropped marker.
    - `fun observeWaiting(): Flow<List<PendingPaymentEntity>>` oldest first, without the held one.
    - `fun observeCount(): Flow<Int>` same rule.
    - `suspend fun update(payment: PendingPaymentEntity)` (card edits; recomputes `dedupKey`).
    - `fun hold(id: String, save: Boolean)` commits any earlier hold at once, then holds this one for 4 s.
    - `fun undo(): Boolean` releases the hold without writing; returns false when nothing is held.
    - `fun flushHold()` commits the hold now (used on screen leave and app stop).
    - `val lastResult: SharedFlow<ConfirmResult>` with `enum class ConfirmResult { SAVED, ALREADY_SAVED, DROPPED }`.
    - `suspend fun enrich(id: String, merchant: String?, categoryId: String?, likelyPromotion: Boolean)` (Task 6 uses it).
  - `ExpenseRepository.suspend fun saveConfirmed(payment: PendingPaymentEntity): Boolean` true when inserted.

- [ ] **Step 1: Write the entities, DAO and `MIGRATION_8_9`.** The migration SQL must match the entities exactly (Room validates at open): `CREATE TABLE IF NOT EXISTS pending_payments (...)` with `likelyPromotion INTEGER NOT NULL`, `format TEXT NOT NULL`, plus `CREATE INDEX IF NOT EXISTS index_pending_payments_notificationKey ON pending_payments (notificationKey)`, and `CREATE TABLE IF NOT EXISTS dropped_notifications (dedupKey TEXT NOT NULL, notificationKey TEXT, droppedAt INTEGER NOT NULL, PRIMARY KEY(dedupKey))`.

- [ ] **Step 2: Replace `saveFromNotification` with `saveConfirmed`.** Same dedup as today, with these changes: the `findByDedupKeySince` lookback is `payment.notificationPostTime - DedupKeyGenerator.dedupLookbackMs()`, not "now"; the amount window uses the card's edited amount, type and post time. Status `AUTO_SAVED`; `EDITED` when the card's merchant, amount, type, category or date differs from what the rule produced (the repository passes this flag; add `edited: Boolean` as a second parameter). Keep the category lookup (card category wins over merchant memory), `merchantCategoryRepository.saveMapping` when edited, and `suggestRepayment` for RECEIVE.

- [ ] **Step 3: Write `PendingPaymentRepository`.** `capture` skips when any of these finds a row: `expenseDao.findByNotificationKey`, `expenseDao.findByDedupKeySince(key, postTime - lookback)`, `expenseDao.findByAmountInWindow` (same window as `ExpenseRepository`), a waiting payment with the same `notificationKey` or `dedupKey`, a dropped marker with the same `dedupKey` or `notificationKey`. `capture` also deletes drop markers older than 30 days. The hold uses a repository-owned `CoroutineScope(SupervisorJob() + Dispatchers.IO)` and a `Job` that waits 4000 ms then commits. A save commit calls `saveConfirmed`, then deletes the waiting row in both outcomes, and emits `SAVED` or `ALREADY_SAVED`. A drop commit inserts the marker, deletes the row, and emits `DROPPED`. A mutex keeps commits one at a time.

- [ ] **Step 4: Build.** Run the build command. Expected: BUILD SUCCESSFUL, all tests PASS. (The listener still calls the removed method; update its call to `pendingPaymentRepository.capture` only enough to compile. Task 3 finishes the listener.)

- [ ] **Step 5: Stage.** `git add app/src/main/java/com/expensetracker/app/data app/src/main/java/com/expensetracker/app/di app/src/main/java/com/expensetracker/app/listener`

---

### Task 3: Listener captures to waiting payments

**Files:**
- Modify: `listener/ExpenseNotificationListener.kt` (`processForExpense`), `listener/CapturedNotification.kt` (`NotificationDisposition`), `ui/viewmodel/NotificationDebugViewModel.kt` and `ui/screens/NotificationDebugScreen.kt` (label for the new value)
- Delete: `parser/ExpenseNotificationParser.kt`, `parser/ExpenseParseResult.kt` (move `ParseSource` out only if still used; otherwise delete it)

**Interfaces:**
- Consumes: `PaymentRules.match`, `PendingPaymentRepository.capture`.
- Produces: `NotificationDisposition.WAITING` ("Waiting for check"), `NotificationDisposition.SKIPPED_NO_RULE` ("No rule matched"). `SAVED` is removed.

- [ ] **Step 1: Rewrite `processForExpense`:** an empty allowlist or a package not in it → `SKIPPED_ALLOWLIST`; `RuleMatch.NoMatch` → `SKIPPED_NO_RULE`; `capture` returns null → `SKIPPED_DUPLICATE`; otherwise `WAITING` with the summary `"<merchant or Unknown> · RM <amount>"`. Remove every use of `ExpenseNotificationParser` and of the old `llmParsingEnabled` setting from the listener.

- [ ] **Step 2: Fix the other users of the deleted parser.** `SettingsViewModel` reads `isLlmConfigured` and `modelsLabel` from `GeminiClient` directly.

- [ ] **Step 3: Build.** Expected: BUILD SUCCESSFUL, tests PASS, no reference to `ExpenseNotificationParser` left (`git grep ExpenseNotificationParser` prints nothing).

- [ ] **Step 4: Stage.** `git add -A app/src/main`

---

### Task 4: Swipe screen, Home banner, and auto-open

**Files:**
- Create: `ui/screens/CheckPaymentsScreen.kt`, `ui/viewmodel/CheckPaymentsViewModel.kt`
- Modify: `ui/navigation/*` (`Routes.CHECK = "check"`), `ui/ExpenseTrackerNavHost.kt` (route, auto-open), `ui/screens/HomeScreen.kt` + `ui/viewmodel/HomeViewModel.kt` (banner), `MainActivity.kt` (`onStop` → `flushHold()`)

**Interfaces:**
- Consumes: `PendingPaymentRepository` (all of it), `CategoryRepository` for the category names and picker, `PastDatePickerDialog`.
- Produces: `HomeScreen(..., onCheckPayments: () -> Unit)`.

- [ ] **Step 1: ViewModel.** `CheckPaymentsViewModel` exposes `waiting: StateFlow<List<PendingPaymentEntity>>`, `fun swipe(id: String, save: Boolean)`, `fun undo()`, `fun edit(payment: PendingPaymentEntity)`, and `messages` for `ALREADY_SAVED` ("Already saved, so it was not added again."). `onCleared` and the screen's `DisposableEffect` call `flushHold()`.

- [ ] **Step 2: Screen.** Match the approved prototype (`swipe-v3.html`; the spec's "Swipe screen" section lists every element):
  - Title "Check payments" with "N of M" counter.
  - Card stack of up to 3 with depth offset.
  - Drag with tilt (`rotation = dx / 18`), stamps fading in over 90 dp, commit past 100 dp, fly-out animation.
  - Round ✕ and ✓ buttons with content descriptions "Not a payment" and "Save".
  - Undo pill for 4 s.
  - Tap merchant, category, date, amount, or type to edit. Use a bottom sheet with the same fields as the add page; date uses `PastDatePickerDialog`.
  - Tags "Unknown format" and "Likely promotion".
  - Full notification text.
  - When the list is empty, the screen pops itself.
  - Use `MaterialTheme.typography` sizes no smaller than: amount `displaySmall`, fields `bodyLarge`, raw text `bodyMedium`.
  - `semantics` custom actions "Save" and "Not a payment" on the top card for TalkBack.

- [ ] **Step 3: Banner.** `HomeViewModel` adds `waitingCount` from `observeCount()`. `HomeScreen` shows a gold-tinted banner "N payments to check" above Today when the count > 0; tap → `onCheckPayments`.

- [ ] **Step 4: Auto-open.** In `ExpenseTrackerNavHost`, on lifecycle `ON_START` of the activity: if the count > 0, the current route is a top-level tab, and the payment-apps picker is not due (Task 5), navigate to `Routes.CHECK` with `launchSingleTop = true`. Do not auto-open again for the same `ON_START` after the user backs out.

- [ ] **Step 5: Build.** Expected: BUILD SUCCESSFUL, tests PASS.

- [ ] **Step 6: Stage.** `git add -A app/src/main`

---

### Task 5: Payment apps picker

**Files:**
- Create: `ui/screens/PaymentAppsScreen.kt`, `ui/viewmodel/PaymentAppsViewModel.kt`
- Modify: `AndroidManifest.xml` (`<queries>` with intent `android.intent.action.MAIN` + category `android.intent.category.LAUNCHER`), `data/SettingsRepository.kt`, `ui/screens/SettingsScreen.kt` + `ui/viewmodel/SettingsViewModel.kt` (remove the package-name field and the recent-packages list; add a "Payment apps" row), navigation (`Routes.PAYMENT_APPS = "settings/payment_apps"`), `HomeScreen` (empty-list prompt)

**Interfaces:**
- Consumes: `PaymentRules.PRESELECT_PACKAGES`.
- Produces:
  - `SettingsRepository.paymentAppsChosen: Flow<Boolean>`: stored key `payment_apps_chosen`; when unset, true if the allowlist is non-empty (an upgrade keeps a real list), else false.
  - `SettingsRepository.suspend fun setPaymentApps(packages: Set<String>)`: writes the allowlist and sets `payment_apps_chosen = true`.
  - `data class InstalledApp(packageName: String, label: String, icon: ImageBitmap?)`.

- [ ] **Step 1: Picker.** Load launcher apps with `PackageManager.queryIntentActivities` on `Dispatchers.IO`, excluding Koban itself. Sort: installed `PRESELECT_PACKAGES` first, then by label. Show a search field, an icon, a label and a checkbox per row, and a "Save" button. On first open (not chosen yet), the installed `PRESELECT_PACKAGES` start ticked; later, the current allowlist is ticked.

- [ ] **Step 2: First run and upgrade.** In the nav host, when notification access is on and `paymentAppsChosen` is false, navigate to `Routes.PAYMENT_APPS` before the Task 4 auto-open.

- [ ] **Step 3: Empty prompt.** When chosen and the allowlist is empty, Home shows "Koban listens to no app. Choose your payment apps." → the picker.

- [ ] **Step 4: Build.** Expected: BUILD SUCCESSFUL, tests PASS.

- [ ] **Step 5: Stage.** `git add -A app/src/main`

---

### Task 6: Optional Gemini pre-fill with the user's key

**Files:**
- Modify: `data/SettingsRepository.kt`, `parser/GeminiClient.kt`, `parser/ReceiptReader.kt` callers (message when no key), `listener/ExpenseNotificationListener.kt` (enrich after capture), `ui/screens/SettingsScreen.kt` + `SettingsViewModel.kt`, `AndroidManifest.xml` (`android:dataExtractionRules` and `android:fullBackupContent`)
- Create: `app/src/main/res/xml/data_extraction_rules.xml`, `app/src/main/res/xml/backup_rules.xml`

**Interfaces:**
- Consumes: `PendingPaymentRepository.enrich`, `MerchantNormalizer.clean`.
- Produces:
  - `SettingsRepository.geminiPrefillEnabled: Flow<Boolean>` (new key `gemini_prefill_enabled`, default false; the old `llm_parsing_enabled` key is no longer read).
  - `SettingsRepository.geminiApiKey: Flow<String>` from a second DataStore file named `secrets`; default `BuildConfig.GEMINI_API_KEY`.
  - `suspend fun setGeminiApiKey(key: String)`, `suspend fun setGeminiPrefillEnabled(enabled: Boolean)`.
  - `GeminiClient` reads the key through `SettingsRepository.geminiApiKey`; `isConfigured` becomes `suspend fun isConfigured(): Boolean`.

- [ ] **Step 1: Key storage and backup.** Both XML files exclude `datastore/secrets.preferences_pb` from cloud backup and device transfer. Never log the key.

- [ ] **Step 2: Client.** Replace the two `BuildConfig.GEMINI_API_KEY` reads in `GeminiClient` with the settings key. `ReceiptReader` keeps returning null with no key; the split editor shows "Receipt scanning needs a Gemini key. Add one in Settings."

- [ ] **Step 3: Enrich.** After `capture` returns an id and pre-fill is on with a key, call `parsePaymentNotification` off the main thread. `Success` → `enrich(id, MerchantNormalizer.clean(merchant), categoryId from merchant memory, false)`. `NotTransaction` → `enrich(id, null, null, true)`. `Failed` → nothing. `enrich` keeps regex values for null arguments.

- [ ] **Step 4: Settings UI.** Add a "Use Gemini to pre-fill" switch, disabled while the key is blank, and a password-style key field with Save.

- [ ] **Step 5: Build.** Expected: BUILD SUCCESSFUL, tests PASS.

- [ ] **Step 6: Stage.** `git add -A app/src`

---

### Task 7: On-phone check (controller, with the owner's phone)

- [ ] **Step 1: Back up the phone database** (the three `expense_tracker.db*` files through `run-as`, after `am force-stop`). Check `user_version = 8` and `integrity_check = ok` on the copy.
- [ ] **Step 2: Install.** Open Koban. Expected: the database migrates to v9, all data shows, and the picker does not open when the allowlist is non-empty.
- [ ] **Step 3: Ask the owner for one real small payment.** Expected: exactly one card, even if the bank posts twice.
- [ ] **Step 4: Duplicate check:** add the same payment by hand on the add page first, then swipe the card right. Expected: "Already saved, so it was not added again." and an unchanged total.
- [ ] **Step 5: Swipe right, then close Koban within 2 seconds.** Reopen. Expected: the expense is in Home totals and the card is gone.
- [ ] **Step 6: Swipe left, then Undo.** Expected: the card comes back. Swipe left again and wait 5 s. Expected: the totals are unchanged.
- [ ] **Step 7: Report results to the owner.** Do not commit.
