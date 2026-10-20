# Add / Edit Payment Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the add/edit expense popup with a full page: big amount, on-page number pad, Expense/Income switch, Category/Date/Shop/Note cards, one big bottom button.

**Architecture:** A pure `AmountInput` object holds the number-pad rules (unit-tested). A new nav route `payment/...` hosts `PaymentScreen` with its own Hilt `PaymentViewModel`, which reads the payment id from `SavedStateHandle` and saves through the existing `ExpenseRepository.addManualExpense` / `updateExpense`. Both list screens navigate to the route; the popup and the editing state in their view models are deleted.

**Tech Stack:** Kotlin, Jetpack Compose Material 3, Navigation Compose, Hilt, Room, JUnit 4.

**Spec:** `docs/superpowers/specs/2026-10-20-add-payment-page-design.md`

## Global Constraints

- Save exactly the data the popup saves today; no schema change, no new dependency.
- Copy: "Expense", "Income", "Category", "Date", "Shop", "Note", "Optional", "Uncategorized" (`DefaultCategories.UNCATEGORIZED_NAME`), "✓ Add expense", "✓ Add income", "Save", "Split this bill", "A new category also applies to past payments from this shop", "Today", "Yesterday", other dates as `EEE, d MMM` (e.g. "Mon, 12 Oct").
- Both themes via `MaterialTheme.colorScheme` and `LocalMoneyColors`: Income amount, "+RM" and selected Income pill use `received`; bottom button and caret use `gold` with `Ink`-style dark text; category dot uses `categoryColor(id)`.
- Expense = `TransactionType.WITHDRAW`, Income = `TransactionType.RECEIVE`.
- No future dates (reuse `PastDatePickerDialog`).
- Touch targets ≥ 48dp; amount, cards and keys have content descriptions / readable text for TalkBack.
- No instrumented tests. JVM tests under `app/src/test`.

## Review Focus

1. Double tap on the bottom button or "Split this bill" must save once — `PaymentViewModel` guards with a `saving` flag; reviewer checks it.
2. Editing a payment that no longer exists (deleted/dismissed meanwhile) — the page closes instead of showing a blank form or crashing.
3. Amount edge input ("." first, "0" then digits, 3rd decimal, very long numbers, backspace to empty) — pinned by `AmountInputTest` in Task 1.
4. Editing an auto-captured payment keeps its amount exactly (e.g. "12.50" stays "12.50", not "12.5") — pinned by `AmountInputTest.fromAmount_keepsTwoDecimals`.
5. The merchant-category rule still runs on add and edit — Task 2 must call the same repository methods; reviewer checks no logic was copied.

---

### Task 1: AmountInput rules

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/ui/components/AmountInput.kt`
- Test: `app/src/test/java/com/expensetracker/app/ui/components/AmountInputTest.kt`

**Interfaces:**
- Produces: `object AmountInput { fun press(text: String, key: Char): String; fun backspace(text: String): String; fun toAmount(text: String): BigDecimal?; fun fromAmount(amount: BigDecimal): String; const val MAX_WHOLE_DIGITS = 9 }`. `text` is the raw typed string (no "RM", no grouping). `toAmount` returns null when empty or zero; otherwise scale 2 via `AmountFormatter.parseInput`.

- [ ] **Step 1: Write the failing tests** (JUnit 4, `assertEquals` on exact values):
  - `press("", '5') == "5"`; `press("", '.') == "0."`; `press("0", '7') == "7"`; `press("0", '0') == "0"`
  - `press("12.", '.') == "12."` (second dot ignored); `press("12.34", '5') == "12.34"` (3rd decimal ignored)
  - `press("123456789", '1') == "123456789"` (limit); `press("123456789", '.') == "123456789."`
  - `backspace("12.5") == "12."`; `backspace("1") == ""`; `backspace("") == ""`
  - `toAmount("") == null`; `toAmount("0.") == null`; `toAmount("0.00") == null`; `toAmount("12.5") == BigDecimal("12.50")`
  - `fromAmount_keepsTwoDecimals`: `fromAmount(BigDecimal("12.50")) == "12.50"`; `fromAmount(BigDecimal("0.00")) == ""` (new payments start empty)
- [ ] **Step 2: Run** `.\gradlew.bat testDebugUnitTest --tests "*AmountInputTest*" -q` — expect FAIL (unresolved reference).
- [ ] **Step 3: Implement `AmountInput`** in the file above to pass the tests.
- [ ] **Step 4: Run** the same command — expect PASS.
- [ ] **Step 5: Commit** `Add amount input rules for the payment page`.

### Task 2: Payment route, view model and screen

**Files:**
- Modify: `app/src/main/java/com/expensetracker/app/ui/navigation/Routes.kt`
- Modify: `app/src/main/java/com/expensetracker/app/data/ExpenseRepository.kt` (add `suspend fun getById(id: String): ExpenseEntity? = expenseDao.getById(id)`)
- Create: `app/src/main/java/com/expensetracker/app/ui/viewmodel/PaymentViewModel.kt`
- Create: `app/src/main/java/com/expensetracker/app/ui/screens/PaymentScreen.kt`
- Create: `app/src/main/java/com/expensetracker/app/ui/components/PastDatePickerDialog.kt` (move `PastDatePickerDialog`, `localDateAsUtcMillis`, `withDate` out of `EditExpenseDialog.kt` unchanged; update imports in `EditExpenseDialog.kt` and `PersonDialogs.kt`)

**Interfaces:**
- Consumes: `AmountInput` (Task 1); `ExpenseRepository.addManualExpense(amount, merchant, postTime, categoryId, notes, transactionType)`, `updateExpense(id, amount, merchant, postTime, categoryId, notes, transactionType)`; `CategoryRepository.observeAll()`; `PastDatePickerDialog(time, onDismiss, onPicked)`.
- Produces:
  - `Routes.PAYMENT_NEW = "payment/new"`, `Routes.PAYMENT_EDIT = "payment/edit/{expenseId}"`, `fun paymentEdit(id: String) = "payment/edit/${Uri.encode(id)}"`.
  - `data class PaymentForm(val amountText: String, val type: TransactionType, val categoryId: String?, val postTime: Long, val merchant: String, val notes: String)` and `PaymentViewModel` exposing `form: StateFlow<PaymentForm?>` (null while loading), `isEditing: Boolean`, `categories: StateFlow<List<CategoryEntity>>`, `events: Flow<PaymentEvent>` where `sealed interface PaymentEvent { data object Close; data class OpenSplit(val expenseId: String) }`, and actions `press(key: Char)`, `backspace()`, `setType(t)`, `setCategory(id: String?)`, `setDate(time: Long)`, `setMerchant(s)`, `setNotes(s)`, `save()`, `saveAndSplit()`.
  - `PaymentScreen(onClose: () -> Unit, onSplit: (expenseId: String) -> Unit, viewModel: PaymentViewModel = hiltViewModel())`.

- [ ] **Step 1: Routes + repository `getById` + move `PastDatePickerDialog`** (build must stay green).
- [ ] **Step 2: `PaymentViewModel`.** Reads `savedStateHandle["expenseId"]`; null → new form (amount "", WITHDRAW, null category, now, "", ""); id → load once with `getById`, fill via `AmountInput.fromAmount`; if not found emit `Close`. `save()`/`saveAndSplit()` do nothing when `AmountInput.toAmount` is null or a `saving` flag is set; otherwise set `saving`, call the repository (blank merchant/notes → null, as `saveEdit` does today), then emit `Close` or `OpenSplit(id)`. Use a `Channel` for events.
- [ ] **Step 3: `PaymentScreen`** per the spec's Layout section (top row, amount, cards, number pad, bottom button, "Split this bill" only when editing and type is WITHDRAW, enabled only when the amount is valid). Category card opens a `ModalBottomSheet` listing "Uncategorized" plus categories with `categoryColor` dots. Date card opens `PastDatePickerDialog`. Shop/Note are `BasicTextField`/`TextField` inside cards; when either has focus the number pad is hidden; tapping the amount clears focus (`LocalFocusManager.clearFocus()`) and shows the pad. Show the merchant-rule hint under the cards only when editing and the category differs from the loaded one. `BackHandler` is not needed beyond default nav back. Collect `events` in a `LaunchedEffect` and call `onClose` / `onSplit`.
- [ ] **Step 4: Register the routes** in `ExpenseTrackerNavHost.kt`: `PAYMENT_NEW` and `PAYMENT_EDIT` (String arg `expenseId`) both render `PaymentScreen(onClose = { navController.popBackStack() }, onSplit = { id -> navController.popBackStack(); navController.navigate(Routes.splitNew(id)) })`.
- [ ] **Step 5: Run** `.\gradlew.bat assembleDebug testDebugUnitTest -q` — expect exit 0.
- [ ] **Step 6: Commit** `Add full-page payment editor`.

### Task 3: Use the page everywhere and delete the popup

**Files:**
- Modify: `ui/screens/ExpensesScreen.kt`, `ui/screens/FilteredExpensesScreen.kt`, `ui/viewmodel/ExpensesViewModel.kt`, `ui/viewmodel/FilteredExpensesViewModel.kt`, `ui/ExpenseTrackerNavHost.kt`
- Delete: `ui/components/EditExpenseDialog.kt`

**Interfaces:**
- Consumes: `Routes.PAYMENT_NEW`, `Routes.paymentEdit(id)` (Task 2).
- Produces: `ExpensesScreen(onSplit, onPeople, onAddPayment: () -> Unit, onEditPayment: (expenseId: String) -> Unit, ...)`; `FilteredExpensesScreen(onBack, onEditPayment: (expenseId: String) -> Unit, ...)` (its `onSplit` parameter is removed if nothing else uses it).

- [ ] **Step 1:** FAB calls `onAddPayment`; row `onEdit` calls `onEditPayment(expense.id)` in both screens. Remove `EditExpenseDialog` usage and the `editingExpense` / `startAdding` / `startEditing` / `isAdding` / `saveEdit` / `clearEditing` members and `NEW_EXPENSE_ID` from both view models (keep everything else, e.g. `dismiss`, `delete`, filters).
- [ ] **Step 2:** Wire the new callbacks in `ExpenseTrackerNavHost.kt` to `Routes.PAYMENT_NEW` / `Routes.paymentEdit(id)`. Delete `EditExpenseDialog.kt`.
- [ ] **Step 3: Run** `.\gradlew.bat assembleDebug testDebugUnitTest -q` — expect exit 0, and `git grep -n "EditExpenseDialog\|saveEdit\|startAdding"` prints nothing under `app/`.
- [ ] **Step 4: Commit** `Open the payment page from the expense lists`.

### Task 4: Phone check (controller)

- [ ] Back up the phone DB (`run-as com.expensetracker.app`, all `databases/*` and `files/datastore/*`) to `D:\Projects\expense-tracker-backup-2026-10-20-pre-payment-page`, `adb install -r`, open the app, confirm no crash. The owner tries add and edit on the phone.
