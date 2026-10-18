# Split Billing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Photograph a receipt, get its items from Gemini, assign items to people, record only the owner's share as spending, and track who owes the owner until repaid.

**Architecture:** Pure Kotlin money rules (`SplitMath`), receipt JSON parsing (`ReceiptParser`) and repayment matching (`RepaymentMatcher`) carry all the logic and all the unit tests. Room stores bills, items, people, shares and debts (database v6). Totals already count spending only (received money adds 0; see commit "Count spending only in totals"). Every spending total switches from `amount` to `COALESCE(countedAmount, amount)`, so a linked card payment counts as the owner's share. A confirmed repayment gets `countedAmount` = 0, which marks it as used (it already never counts in totals).

**Tech Stack:** Kotlin 2.0, Jetpack Compose + Material 3, Hilt, Room 2.6 (KSP), OkHttp + org.json, Gemini `generateContent` with inline image data.

**Spec:** `docs/superpowers/specs/2026-10-18-split-billing-design.md`

## Global Constraints

- No new dependencies. Camera = `ActivityResultContracts.TakePicture` + `FileProvider`; gallery = `ActivityResultContracts.PickVisualMedia`.
- Money is `BigDecimal` everywhere; store with the existing `BigDecimalConverters` (TEXT, 2 decimals, half-up).
- "Me" is the fixed person id `"me"` (`ME_ID`); it is never stored in `split_people`.
- Database goes from version 5 to 6 with a migration. `fallbackToDestructiveMigration` is forbidden: the owner has 379 real expenses on the phone.
- Reuse `GeminiClient` (same `.env` key, same primary/secondary model fallback). Without a key, or on failure, open the item editor empty.
- UI follows the existing theme (`ui/theme/Theme.kt`) and components (`MoneyAmount`, `ExpenseListCard`, `PeriodTotalRow`, `categoryFill`). Sentence case copy, no all-caps labels.
- Work on branch `feature/split-billing`. Commit at the end of each task with the owner's git identity and no AI attribution lines. Do not push; the controller pushes.
- Build/test from PowerShell with `$env:JAVA_HOME = 'C:\Users\daven\AppData\Local\Temp\claude\d--Projects-Expense-Tracker\783d92a6-f61a-4a33-bbf4-ccfcdb48ee2a\scratchpad\jdk\jdk-17.0.20.1+1'` (no JDK is installed on this PC).
- Unit test command: `.\gradlew.bat testDebugUnitTest --tests "<class>"`. Instrumented tests (`connectedAndroidTest`) are forbidden: AGP uninstalls the app afterwards and would delete the owner's data.

## Review Focus

1. Wrong payment linked (card amount smaller than what friends owe) → owner's spending clamps to RM 0.00, never negative. Test: Task 1 `ownerSpending_neverNegative`.
2. Gemini returns amounts as strings ("RM 12.50", "1,234.00"), nulls, a negative discount, or broken JSON → parser keeps what it can and returns `null` only for unreadable JSON; never crashes. Tests: Task 2.
3. An item nobody is assigned to → the Assign step blocks "Next" and highlights it; `SplitMath.shares` refuses it. Tests: Task 1 `unassignedItemIndexes_findsEmptyItems`, `shares_rejectsUnassignedItem`.
4. Two friends owe the same amount and the transfer's sender name matches neither → no suggestion (owner links by hand). Test: Task 3 `match_ambiguousWithoutName_returnsEmpty`.
5. All items priced 0.00 but a service charge exists → charges split evenly, no divide-by-zero. Test: Task 1 `shares_zeroSubtotal_splitsChargesEvenly`.

---

### Task 1: Money rules

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/data/SplitMath.kt`
- Test: `app/src/test/java/com/expensetracker/app/data/SplitMathTest.kt`

**Interfaces:**
- Produces:
  - `const val ME_ID = "me"`
  - `data class SplitItemInput(val price: BigDecimal, val sharedBy: Set<String>)`
  - `data class SplitCharges(val serviceCharge: BigDecimal = ZERO, val tax: BigDecimal = ZERO, val discount: BigDecimal = ZERO, val rounding: BigDecimal = ZERO)` — `discount` is positive and subtracts; `rounding` is signed.
  - `object SplitMath`:
    - `fun computedTotal(items: List<SplitItemInput>, charges: SplitCharges): BigDecimal` = Σprice + service + tax − discount + rounding, scale 2.
    - `fun shares(items: List<SplitItemInput>, charges: SplitCharges): Map<String, BigDecimal>` — always contains `ME_ID`; values sum exactly to `computedTotal`; throws `IllegalArgumentException` if any item has an empty `sharedBy`.
    - `fun unassignedItemIndexes(items: List<SplitItemInput>): List<Int>`
    - `fun ownerSpending(linkedAmount: BigDecimal, othersOwe: BigDecimal): BigDecimal` = max(0.00, linked − others).

- [ ] **Step 1: Write the failing tests** (keys `"me"`, `"a"`, `"b"`)

```kotlin
// Receipt: Nasi lemak 12.00 (me), Teh tarik 3.00 (a), Satay 10.00 (me,a,b); service 2.50, SST 1.65
@Test fun computedTotal_example() = assertEquals(BigDecimal("29.15"), SplitMath.computedTotal(example, exampleCharges))
@Test fun shares_example() = assertEquals(mapOf("me" to BigDecimal("17.88"), "a" to BigDecimal("7.38"), "b" to BigDecimal("3.89")), SplitMath.shares(example, exampleCharges))
// 10.00 shared by me,a,b, no charges
@Test fun shares_leftoverCentGoesToMe() → me 3.34, a 3.33, b 3.33
// me 20.00, a 10.00; discount 3.00, rounding -0.02 → total 26.98
@Test fun shares_discountAndRoundingInProportion() → a 8.99, me 17.99
// one item 0.00 shared me,a; service 2.00
@Test fun shares_zeroSubtotal_splitsChargesEvenly() → me 1.00, a 1.00
@Test fun shares_rejectsUnassignedItem() → assertThrows<IllegalArgumentException> with second item sharedBy = emptySet()
@Test fun unassignedItemIndexes_findsEmptyItems() → listOf(1)
@Test fun ownerSpending_subtractsFriends() → ownerSpending(120.00, 80.00) == 40.00
@Test fun ownerSpending_neverNegative() → ownerSpending(50.00, 80.00) == 0.00
```

- [ ] **Step 2: Run** `.\gradlew.bat testDebugUnitTest --tests "com.expensetracker.app.data.SplitMathTest"` — expected: compilation FAIL (`SplitMath` unresolved).

- [ ] **Step 3: Implement `SplitMath.kt`.** Algorithm `shares`:
  1. Per person exact subtotal = Σ(price / N) over items they share (`divide(N, 10, HALF_UP)`).
  2. `charges = service + tax − discount + rounding`. If Σsubtotals > 0, each person gets `subtotal + charges × subtotal / Σsubtotals`; else charges split evenly over everyone who appears in any item (no items at all → all to `ME_ID`).
  3. Round every person except `ME_ID` to 2 decimals, `HALF_UP`. `ME_ID` = `computedTotal − Σ(others)`.

- [ ] **Step 4: Run the same command** — expected: 9 tests PASS.

---

### Task 2: Receipt reading

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/parser/ReceiptParser.kt`
- Create: `app/src/main/java/com/expensetracker/app/parser/ReceiptReader.kt`
- Modify: `app/src/main/java/com/expensetracker/app/parser/GeminiClient.kt` (extract the model-fallback loop)
- Test: `app/src/test/java/com/expensetracker/app/parser/ReceiptParserTest.kt`

**Interfaces:**
- Produces:
  - `data class ReceiptItemDraft(val name: String, val quantity: Int, val price: BigDecimal)` — `price` is the line total.
  - `data class ReceiptDraft(val merchant: String?, val dateMillis: Long?, val items: List<ReceiptItemDraft>, val serviceCharge: BigDecimal, val tax: BigDecimal, val discount: BigDecimal, val rounding: BigDecimal, val printedTotal: BigDecimal?)`
  - `object ReceiptParser { fun parseModelContent(content: String): ReceiptDraft?; fun parseGenerateContentBody(body: String): ReceiptDraft? }`
  - `GeminiClient.fun <T : Any> generate(systemPrompt: String, userParts: JSONArray, callTimeoutSeconds: Long = 20, parse: (String) -> T?): T?` — tries primary then secondary with the existing cooldown rules; a body that `parse` rejects counts as a failed attempt.
  - `@Singleton class ReceiptReader @Inject constructor(@ApplicationContext context: Context, geminiClient: GeminiClient) { suspend fun read(imageUri: Uri): ReceiptDraft? }`

Model JSON contract (pinned; put it in the prompt):
```json
{"merchant": "string|null", "date": "YYYY-MM-DD|null",
 "items": [{"name": "string", "quantity": 1, "price": 12.50}],
 "serviceCharge": 0, "tax": 0, "discount": 0, "rounding": 0, "total": 0}
```

- [ ] **Step 1: Write the failing tests**

```kotlin
@Test fun parse_fullReceipt() // 3 items, serviceCharge 2.50, tax 1.65, total 29.15 → items.size 3, items[2] == ReceiptItemDraft("Satay", 10, BigDecimal("10.00")), printedTotal 29.15, merchant "KK Super Mart"
@Test fun parse_stringAmounts() // "price": "RM 1,234.50" → 1234.50; "tax": "6.00" → 6.00
@Test fun parse_nullChargesBecomeZero() // serviceCharge null, rounding missing → ZERO (scale 2)
@Test fun parse_negativeDiscountStoredPositive() // "discount": -3 → 3.00
@Test fun parse_skipsItemsWithoutNameOrPrice() // {"name":"","price":5}, {"name":"Tea","price":null} → items empty
@Test fun parse_quantityDefaultsToOne() // missing or 0 → 1
@Test fun parse_dateToLocalMidnight() // "2026-10-18" → Calendar(2026, OCTOBER, 18, 0, 0).timeInMillis; "18/10" → null
@Test fun parse_brokenJsonReturnsNull() // "not json" → null
@Test fun parseGenerateContentBody_readsFirstCandidateText() // wraps a valid object in candidates[0].content.parts[0].text
```

- [ ] **Step 2: Run** `.\gradlew.bat testDebugUnitTest --tests "com.expensetracker.app.parser.ReceiptParserTest"` — expected: compilation FAIL.

- [ ] **Step 3: Implement `ReceiptParser`.** Reuse `LlmResponseParser`'s JSON-extraction approach (first `{` to last `}`); numbers via `NotificationParser.normalizeAmount` after stripping `RM`/`MYR` and commas.

- [ ] **Step 4: Run the same command** — expected: 9 tests PASS.

- [ ] **Step 5: Refactor `GeminiClient`.** Move the loop in `parsePaymentNotification` into `generate(...)`; `parsePaymentNotification` becomes `generate(SYSTEM_PROMPT, textParts(text)) { body -> LlmResponseParser.parseGenerateContentBody(body).takeIf { it != LlmParseResult.Failed } } ?: LlmParseResult.Failed`. When `callTimeoutSeconds` ≠ 20, use `httpClient.newBuilder().callTimeout(..).readTimeout(..)`. Keep `generationConfig` (`temperature 0`, `responseMimeType application/json`).

- [ ] **Step 6: Implement `ReceiptReader.read`.** On `Dispatchers.IO`: decode with `inSampleSize` so the longest side is ≤ 1600 px, JPEG quality 80, `Base64.NO_WRAP`; user part = `{"inline_data":{"mime_type":"image/jpeg","data":...}}` plus `{"text":"Read this receipt."}`; `callTimeoutSeconds = 60`; parse with `ReceiptParser.parseGenerateContentBody`. Return `null` if not configured or every model fails.

- [ ] **Step 7: Run all unit tests** `.\gradlew.bat testDebugUnitTest` — expected: all PASS (existing `LlmResponseParserTest` proves the refactor kept notification parsing).

---

### Task 3: Repayment matching

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/data/RepaymentMatcher.kt`
- Test: `app/src/test/java/com/expensetracker/app/data/RepaymentMatcherTest.kt`

**Interfaces:**
- Produces:
  - `data class OpenDebtRef(val debtId: String, val personId: String, val personName: String, val amount: BigDecimal)` — callers pass oldest first.
  - `object RepaymentMatcher { fun match(amount: BigDecimal, senderName: String?, openDebts: List<OpenDebtRef>): List<String> }` — returns debt ids to close, or empty.

Rules: per person, find a subset of that person's open debts whose sum equals `amount` exactly (fewest debts wins; ties → earliest in list). Never mix people. One person with a subset → return it. Several → keep those whose name matches the sender (any word of the person's name with ≥ 3 letters appears as a word in `senderName`, case-insensitive); exactly one left → return it; otherwise empty. Search at most the 12 oldest open debts per person (`// ponytail:` comment: 2^12 subsets; switch to DP if people keep more open debts).

- [ ] **Step 1: Write the failing tests**

```kotlin
@Test fun match_singleDebtExact()            // a: 7.38; amount 7.38 → [d1]
@Test fun match_severalWholeDebtsSamePerson() // a: 7.38, 12.00; amount 19.38 → [d1, d2]
@Test fun match_neverMixesPeople()           // a: 7.38, b: 3.89; amount 11.27 → []
@Test fun match_prefersNameMatch()           // a "Aisyah": 10.00, b "Ben": 10.00; sender "AISYAH NUR RAHMAN" → [a's debt]
@Test fun match_ambiguousWithoutName_returnsEmpty() // same debts, sender null → []
@Test fun match_noSubset_returnsEmpty()      // a: 7.38; amount 7.00 → []
```

- [ ] **Step 2: Run** `.\gradlew.bat testDebugUnitTest --tests "com.expensetracker.app.data.RepaymentMatcherTest"` — expected: compilation FAIL.
- [ ] **Step 3: Implement `RepaymentMatcher.match`.**
- [ ] **Step 4: Run the same command** — expected: 6 tests PASS.

---

### Task 4: Database v6 and totals that respect splits

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/data/SplitEntities.kt`
- Create: `app/src/main/java/com/expensetracker/app/data/SplitDao.kt`
- Modify: `app/src/main/java/com/expensetracker/app/data/ExpenseEntity.kt` (add `val countedAmount: BigDecimal? = null`)
- Modify: `app/src/main/java/com/expensetracker/app/data/ExpenseDao.kt` (every `SUM`)
- Modify: `app/src/main/java/com/expensetracker/app/data/ExpenseDatabase.kt` (version 6, entities, `DebtStatusConverter`, `splitDao()`)
- Modify: `app/src/main/java/com/expensetracker/app/data/DatabaseMigrations.kt` (add `MIGRATION_5_6`)
- Modify: `app/src/main/java/com/expensetracker/app/data/Converters.kt` (add `DebtStatusConverter`)
- Modify: `app/src/main/java/com/expensetracker/app/di/AppModule.kt` (register migration, provide `SplitDao`)
- Modify: `app/src/main/java/com/expensetracker/app/ui/components/ExpenseItem.kt:180` (day header sum)
- Test: `app/src/test/java/com/expensetracker/app/data/ExpenseEffectiveAmountTest.kt`

**Interfaces:**
- Produces:
  - Entities: `SplitBillEntity(id, merchant: String?, billTime: Long, currency: String, printedTotal: BigDecimal?, serviceCharge, tax, discount, rounding: BigDecimal, linkedExpenseId: String?, createdAt: Long)`, `SplitItemEntity(id, billId, name, quantity: Int, price: BigDecimal, position: Int)`, `SplitPersonEntity(id, name, lastUsedAt: Long)`, `SplitItemShareEntity(itemId, personId)` (composite primary key), `SplitDebtEntity(id, billId, personId, amount: BigDecimal, status: DebtStatus, repaymentExpenseId: String?, suggestedRepaymentExpenseId: String?, paidAt: Long?)`, `enum class DebtStatus { OPEN, PAID }`.
  - `val ExpenseEntity.effectiveAmount: BigDecimal get() = countedAmount ?: amount`
  - `ExpenseDao`: `suspend fun getRecentByType(type: TransactionType, since: Long): List<ExpenseEntity>` (active, `countedAmount IS NULL`, newest first).
  - `SplitDao` with the queries Task 5 needs (bills newest first; items/shares/debts by bill; open debts joined with person name, bill merchant and bill time, oldest first; people by `lastUsedAt` desc; inserts, updates, deletes by `billId`). Builder names them.

Migration SQL (must match Room's generated schema exactly):
```sql
ALTER TABLE expenses ADD COLUMN countedAmount TEXT;
CREATE TABLE IF NOT EXISTS split_bills (id TEXT NOT NULL, merchant TEXT, billTime INTEGER NOT NULL, currency TEXT NOT NULL, printedTotal TEXT, serviceCharge TEXT NOT NULL, tax TEXT NOT NULL, discount TEXT NOT NULL, rounding TEXT NOT NULL, linkedExpenseId TEXT, createdAt INTEGER NOT NULL, PRIMARY KEY(id));
CREATE TABLE IF NOT EXISTS split_items (id TEXT NOT NULL, billId TEXT NOT NULL, name TEXT NOT NULL, quantity INTEGER NOT NULL, price TEXT NOT NULL, position INTEGER NOT NULL, PRIMARY KEY(id));
CREATE INDEX IF NOT EXISTS index_split_items_billId ON split_items (billId);
CREATE TABLE IF NOT EXISTS split_people (id TEXT NOT NULL, name TEXT NOT NULL, lastUsedAt INTEGER NOT NULL, PRIMARY KEY(id));
CREATE TABLE IF NOT EXISTS split_item_shares (itemId TEXT NOT NULL, personId TEXT NOT NULL, PRIMARY KEY(itemId, personId));
CREATE INDEX IF NOT EXISTS index_split_item_shares_personId ON split_item_shares (personId);
CREATE TABLE IF NOT EXISTS split_debts (id TEXT NOT NULL, billId TEXT NOT NULL, personId TEXT NOT NULL, amount TEXT NOT NULL, status TEXT NOT NULL, repaymentExpenseId TEXT, suggestedRepaymentExpenseId TEXT, paidAt INTEGER, PRIMARY KEY(id));
CREATE INDEX IF NOT EXISTS index_split_debts_billId ON split_debts (billId);
CREATE INDEX IF NOT EXISTS index_split_debts_personId ON split_debts (personId);
```
Entity annotations must declare the same indices (`Index("billId")`, `Index("personId")`).

- [ ] **Step 1: Write the failing test** `ExpenseEffectiveAmountTest`: `countedAmount = 40.00, amount = 120.00` → `effectiveAmount == 40.00`; `countedAmount = null` → `120.00`.
- [ ] **Step 2: Run** `--tests "com.expensetracker.app.data.ExpenseEffectiveAmountTest"` — expected: compilation FAIL.
- [ ] **Step 3: Add entities, DAO, converter, migration, DI wiring, `effectiveAmount`.**
- [ ] **Step 4: Replace `amount` with `COALESCE(countedAmount, amount)` inside every `SUM(CASE …)` in `ExpenseDao`** (5 queries: `observeTotalForRange`, `observeTotalsByCategory`, `observeTotalForDay`, `observeMonthlyTotals`, `getTotalForRangeOnce`). Leave `findByAmountInWindow` on `amount` (dedup compares what the bank sent).
- [ ] **Step 5: `DayHeader` in `ExpenseItem.kt` sums `effectiveAmount` of WITHDRAW rows (RECEIVE rows add nothing, as today).**
- [ ] **Step 6: Run** `.\gradlew.bat assembleDebug testDebugUnitTest` — expected: BUILD SUCCESSFUL, all tests PASS. (Room validates the migration only on the device; Task 8 checks it.)

---

### Task 5: Split repository and notification hook

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/data/SplitRepository.kt`
- Modify: `app/src/main/java/com/expensetracker/app/data/ExpenseRepository.kt` (call the hooks)

**Interfaces:**
- Consumes: Task 1 `SplitMath`, `ME_ID`; Task 3 `RepaymentMatcher`, `OpenDebtRef`; Task 4 entities, `SplitDao`, `ExpenseDao.getRecentByType`.
- Produces (`@Singleton class SplitRepository @Inject constructor(db: ExpenseDatabase, splitDao: SplitDao, expenseDao: ExpenseDao)`):
  - `data class DraftItem(val name: String, val quantity: Int, val price: BigDecimal, val sharedBy: Set<String>)`
  - `data class SplitDraft(val billId: String?, val merchant: String?, val billTime: Long, val currency: String, val printedTotal: BigDecimal?, val items: List<DraftItem>, val charges: SplitCharges, val people: List<SplitPersonEntity>, val linkedExpenseId: String?)` — `people` excludes Me.
  - `data class OpenDebtView(val debt: SplitDebtEntity, val personName: String, val billMerchant: String?, val billTime: Long, val suggestedRepayment: ExpenseEntity?)`
  - `suspend fun saveSplit(draft: SplitDraft): String` (bill id)
  - `suspend fun loadDraft(billId: String): SplitDraft?`
  - `suspend fun isLocked(billId: String): Boolean` (any debt PAID)
  - `suspend fun linkPayment(billId: String, expenseId: String?)`
  - `suspend fun deleteSplit(billId: String)`
  - `suspend fun paymentCandidates(total: BigDecimal, now: Long): List<ExpenseEntity>` (WITHDRAW, last 3 days, `amount == total`)
  - `suspend fun repaymentCandidates(debtId: String): List<ExpenseEntity>` (RECEIVE since bill time, amount == this debt or == the person's open total)
  - `suspend fun markPaid(debtId: String, repaymentExpenseId: String?)` (null = cash)
  - `suspend fun confirmSuggestion(debtId: String)`, `suspend fun dismissSuggestion(debtId: String)`
  - `suspend fun suggestRepayment(receive: ExpenseEntity)`
  - `suspend fun onExpenseEdited(expenseId: String)`
  - `fun observeOpenDebts(): Flow<List<OpenDebtView>>`, `fun observeBills(): Flow<List<SplitBillEntity>>`, `fun observeRecentPeople(): Flow<List<SplitPersonEntity>>`

Behavior (all writes inside `db.withTransaction`):
- `saveSplit`: throws `IllegalStateException` if `isLocked`. Reuses people by case-insensitive name, sets `lastUsedAt = now`. Replaces the bill's items, shares and debts. Debts = `SplitMath.shares` minus `ME_ID`, zero amounts skipped, status OPEN. Then applies the link (below).
- Link effect: linked expense `countedAmount = SplitMath.ownerSpending(expense.amount, Σ debts)`. Changing/removing the link sets the old expense's `countedAmount = null`.
- `markPaid` with an expense: if its amount equals the person's open total, close all that person's open debts; else it must equal this debt's amount and close only this one. Set the RECEIVE expense `countedAmount = 0.00`, debts `status = PAID`, `repaymentExpenseId`, `paidAt = now`. Cash: close this debt only, no expense change.
- `confirmSuggestion`: same as `markPaid` for every open debt whose `suggestedRepaymentExpenseId` equals this debt's; `dismissSuggestion` clears it on those debts.
- `suggestRepayment`: build `OpenDebtRef`s (open, no current suggestion, oldest first), `RepaymentMatcher.match(receive.amount, receive.merchant, refs)`, store `suggestedRepaymentExpenseId` on the returned debts.
- `deleteSplit`: linked expense and every repayment expense of its debts → `countedAmount = null`; delete bill, items, shares, debts.
- `onExpenseEdited`: if a bill links this expense, recompute its `countedAmount`.
- `ExpenseRepository.saveFromNotification`: after a successful insert of a RECEIVE, call `splitRepository.suggestRepayment(entity)`. `ExpenseRepository.updateExpense`: after update, call `splitRepository.onExpenseEdited(id)`.

- [ ] **Step 1: Implement `SplitRepository` and the two hooks.** The logic is in Tasks 1 and 3; this layer only wires data, so it has no unit test of its own (Room needs a device; see Task 8).
- [ ] **Step 2: Run** `.\gradlew.bat assembleDebug testDebugUnitTest` — expected: BUILD SUCCESSFUL, all tests PASS.

---

### Task 6: Split editor flow

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/ui/viewmodel/SplitEditorViewModel.kt`
- Create: `app/src/main/java/com/expensetracker/app/ui/screens/SplitEditorScreen.kt`
- Create: `app/src/main/res/xml/file_paths.xml` (`<cache-path name="receipts" path="receipts/"/>`)
- Modify: `app/src/main/AndroidManifest.xml` (`androidx.core.content.FileProvider`, authority `${applicationId}.fileprovider`)
- Modify: `app/src/main/java/com/expensetracker/app/ui/navigation/Routes.kt`
- Modify: `app/src/main/java/com/expensetracker/app/ui/ExpenseTrackerNavHost.kt`
- Modify: `app/src/main/java/com/expensetracker/app/ui/screens/ExpensesScreen.kt` (entry buttons)
- Modify: `app/src/main/java/com/expensetracker/app/ui/components/EditExpenseDialog.kt` (`onSplit: (() -> Unit)?`, shown for WITHDRAW only)

**Interfaces:**
- Consumes: Task 2 `ReceiptReader.read`, `ReceiptDraft`; Task 1 `SplitMath`; Task 5 `SplitRepository`, `SplitDraft`, `DraftItem`.
- Produces: `Routes.SPLIT_NEW = "split/new?expenseId={expenseId}"`, `Routes.splitNew(expenseId: String?)`, `Routes.SPLIT_EDIT = "split/{billId}"`, `Routes.splitEdit(billId: String)`.

Steps in one screen, driven by `SplitEditorViewModel.step: Photo | Reading | Items | People | Assign | Link | Summary`:
- **Photo:** "Take photo" and "Choose from gallery" buttons, plus "Type items instead". Photo saved to `cacheDir/receipts/receipt.jpg`, deleted after reading (spec: photos are not kept).
- **Reading:** progress text "Reading receipt…". On `null`: go to Items with an empty list and the message "Couldn't read this receipt. Add the items by hand."
- **Items:** editable rows (name, quantity, price), "Add item", charge fields (service charge, SST, discount, rounding). Footer: computed total vs printed total; on mismatch show the difference and a button "Add RM x.xx as rounding".
- **People:** "Me" fixed chip; recent people as chips (most recent first); text field + "Add".
- **Assign:** each item row shows people chips; tap toggles. Items with no one have an error outline; "Next" disabled while `SplitMath.unassignedItemIndexes` is not empty.
- **Link:** pre-linked expense (from the edit dialog) shown selected; otherwise `paymentCandidates`; "Not paid by card" option. If the linked amount ≠ computed total, show "The payment is RM x, the receipt is RM y. Your share absorbs the difference."
- **Summary:** each person and amount (`MoneyAmount`), "Share summary" (`Intent.ACTION_SEND`, text below), "Done" → `saveSplit`, navigate back.

Share text:
```
{merchant or "Bill"}, {d MMM yyyy}
{name}: RM {amount}      (one line per person, Me last as "Me")
Total: RM {total}
```
Editing an existing bill: if `isLocked`, open Summary read-only with only "Change payment" and "Delete split".

- [ ] **Step 1: Implement the ViewModel, screen, routes, FileProvider, and entry points.**
- [ ] **Step 2: Run** `.\gradlew.bat assembleDebug testDebugUnitTest` — expected: BUILD SUCCESSFUL.

---

### Task 7: Who owes me, past splits, expense row display

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/ui/viewmodel/DebtsViewModel.kt`
- Create: `app/src/main/java/com/expensetracker/app/ui/screens/DebtsScreen.kt`
- Modify: `Routes.kt` (`DEBTS = "debts"`), `ExpenseTrackerNavHost.kt`, `ExpensesScreen.kt` ("Who owes me" button with the open count)
- Modify: `app/src/main/java/com/expensetracker/app/ui/components/ExpenseItem.kt` (`ExpenseListCard`)

**Interfaces:**
- Consumes: Task 5 `observeOpenDebts`, `observeBills`, `markPaid`, `repaymentCandidates`, `confirmSuggestion`, `dismissSuggestion`, `deleteSplit`; Task 4 `effectiveAmount`.

Behavior:
- **Who owes me:** open debts grouped by person; person total with `MoneyAmount`; each debt shows bill merchant, date, amount. A debt with `suggestedRepayment` shows "Possible repayment: RM x from {sender}, {date}" with "Confirm" and "Not this".
- **Mark paid:** dialog listing `repaymentCandidates` plus "Paid in cash".
- **Past splits:** newest first; tap → `Routes.splitEdit(id)`.
- **Empty state:** "Nobody owes you anything. Split a bill from the Expenses tab."
- **`ExpenseListCard`:** when `countedAmount != null` and it differs from `amount`: WITHDRAW shows `effectiveAmount` as the main amount plus a muted "paid RM x" line; RECEIVE with `countedAmount == 0` shows the second line "Repayment" and the amount in `onSurfaceVariant`.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Run** `.\gradlew.bat assembleDebug testDebugUnitTest` — expected: BUILD SUCCESSFUL, all tests PASS.

---

### Task 8: Device check with the owner's data safe

**Files:** none (verification only).

- [ ] **Step 1: Back up the phone data** to `D:\Projects\expense-tracker-backup-<date>-pre-split`: `adb shell am force-stop com.expensetracker.app`, then `cmd /c "adb exec-out run-as com.expensetracker.app cat databases/<file> > <backup>\<file>"` for `expense_tracker.db`, `-wal`, `-shm`, and `files/datastore/settings.preferences_pb`. Expected: sizes equal `adb shell run-as … ls -l`.
- [ ] **Step 2: Verify the backup** with Python `sqlite3` on a copy: `pragma integrity_check` = `ok`, `expenses` count printed.
- [ ] **Step 3: Install** `adb install -r app\build\outputs\apk\debug\app-debug.apk`, start the app, take `adb exec-out screencap`. Expected: Home shows the same Today/This week/This month totals as before the install (migration ran, `countedAmount` is null everywhere). If the app crashes with a Room migration error, read `adb logcat -d -s AndroidRuntime`, fix the SQL, reinstall; the data is untouched because the migration runs in a transaction.
- [ ] **Step 4: Pull the migrated DB** the same way and check: `pragma user_version` = 6, expense count unchanged, `split_bills` exists.
- [ ] **Step 5: Hand the owner a 3-minute script:** split one real bill with a photo, link it, check Today drops to the owner's share, check Who owes me.
