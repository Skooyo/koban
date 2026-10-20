# Three-Tab Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the four tabs (Home / Expenses / History / Settings) with Home / Activity / People, Settings behind a gear on Home, and delete moved from row trash icons into the payment page.

**Architecture:** A pure `MonthNav` helper (unit-tested) handles month stepping. A Hilt `@Singleton ActivitySelection` holds the selected month and week as a `StateFlow`, so Home can set it before switching to the Activity tab. `ActivityScreen`/`ActivityViewModel` merge the old Expenses list, History months/weeks and the filtered list. The payment page gains Delete and returns a one-line message through the previous back-stack entry's `savedStateHandle`.

**Tech Stack:** Kotlin, Compose Material 3, Navigation Compose, Hilt, Room, java.time (minSdk 26), JUnit 4.

**Spec:** `docs/superpowers/specs/2026-10-20-three-tab-layout-design.md` (read "Goals", "Navigation from Home" and "Designer's calls").

## Global Constraints

- No data model or total-calculation change; reuse `ExpenseRepository` methods and `PeriodCalculator` (full Mon–Sun weeks, unclipped).
- Tabs exactly: "Home", "Activity", "People", in this order.
- Copy: "Activity", "Pick a month", "No payments in [Month Year].", "Split a bill", "Settings", "＋ Add", "Delete payment", "Delete this payment?", "It will no longer count in your totals.", "Delete", "Cancel", "Expense added", "Income added", "Payment deleted".
- Delete = today's row delete (`ExpenseRepository.dismissExpense`). No Undo, no swipe delete.
- Both themes via `MaterialTheme.colorScheme` / `LocalMoneyColors`; gold FAB with dark ink text (as the payment page button); touch targets ≥ 48dp; TalkBack labels on icon-only buttons ("Settings", "Previous month", "Next month").
- No instrumented tests; JVM tests under `app/src/test`.

## Review Focus

1. A feature that was reachable before becomes unreachable (History weeks, category filter, Split a bill from scratch, notification log, People, delete) — reviewer walks every old route.
2. Home's "This week" on the 1st–6th of a month: Activity must show the same week and total Home shows (full week, current month).
3. Month stepping across a year boundary and "next" disabled on the current month — pinned by `MonthNavTest`.
4. The result message shows exactly once on the screen under the payment page (not again after rotation or returning to the tab).
5. Bottom bar shows only on the 3 tab routes; Settings, payment page, Person, split editor hide it; system Back from a tab behaves as today.

---

### Task 1: MonthNav

**Files:** Create `app/src/main/java/com/expensetracker/app/data/MonthNav.kt`; Test `app/src/test/java/com/expensetracker/app/data/MonthNavTest.kt`.

**Interfaces:** Produces `object MonthNav { fun previous(m: YearMonth): YearMonth; fun next(m: YearMonth, current: YearMonth): YearMonth?; fun label(m: YearMonth): String }` — `next` returns null when `m >= current`; `label` is "October 2026" (English full month name, year).

- [ ] **Step 1: Failing tests:** `previous(2026-01) == 2025-12`; `next(2025-12, current=2026-10) == 2026-01`; `next(2026-10, current=2026-10) == null`; `next(2026-11, current=2026-10) == null`; `label(2026-10) == "October 2026"`.
- [ ] **Step 2:** `.\gradlew.bat testDebugUnitTest --tests "*MonthNavTest*" -q` → FAIL.
- [ ] **Step 3:** Implement with `java.time.YearMonth`.
- [ ] **Step 4:** Same command → PASS.

### Task 2: Activity tab

**Files:**
- Create `data/ActivitySelection.kt`: `@Singleton class ActivitySelection @Inject constructor() { val state: StateFlow<Selection>; fun show(month: YearMonth, weekStart: Long? = null); }` with `data class Selection(val month: YearMonth, val weekStart: Long?)`, initial = current month, no week.
- Create `ui/viewmodel/ActivityViewModel.kt`, `ui/screens/ActivityScreen.kt`.
- Modify `data/ExpenseRepository.kt` only if a needed query is missing (prefer existing `observeMonthlySummaries`, `weekSummariesForMonth`, `observeInRange`).

**Interfaces:**
- Consumes `MonthNav`; `PeriodCalculator.rangeForMonth/weeksInMonth`; `ExpenseRepository`; `CategoryRepository.observeAll()`; `matchesCategory`; `ExpenseListCard`/day-grouped list code from today's `ExpensesScreen`.
- Produces `ActivityScreen(onAddPayment: () -> Unit, onEditPayment: (String) -> Unit, message: String?, onMessageShown: () -> Unit, viewModel: ActivityViewModel = hiltViewModel())`.

- [ ] **Step 1:** `ActivitySelection` + `ActivityViewModel`: month total (spending, as History), week list with full-week totals (as `weekSummariesForMonth`), payments in the selected month range or selected week range, category filter, months-with-payments list plus the current month for the sheet. Actions: `previousMonth()`, `nextMonth()`, `pickMonth(m)` (all clear the week), `toggleWeek(weekStart)`, `setCategoryFilter(id)`.
- [ ] **Step 2:** `ActivityScreen` per spec Goal 3 and the storyboard: title, month bar (‹ / name ▾ / ›, › disabled when `MonthNav.next` is null), total, week strip (selected week outlined gold), category chips, day-grouped list (rows tap → `onEditPayment`), empty text "No payments in [Month Year].", gold "＋ Add" FAB with bottom content padding so the last row is not covered, "Pick a month" `ModalBottomSheet` (rows ≥ 48dp, total + bar as History). Show `message` as a snackbar once, then call `onMessageShown`.
- [ ] **Step 3:** Build `.\gradlew.bat assembleDebug testDebugUnitTest -q` → exit 0 (screen not yet wired into nav; that is Task 4).

### Task 3: Delete on the payment page, rows without trash, Home actions

**Files:** Modify `ui/screens/PaymentScreen.kt`, `ui/viewmodel/PaymentViewModel.kt`, `ui/components/ExpenseItem.kt`, `ui/screens/HomeScreen.kt`, `ui/viewmodel/HomeViewModel.kt` (only if needed), and every caller of `ExpenseListCard`/`ExpenseList` that passed `onDelete`.

**Interfaces:**
- `PaymentEvent.Close` gains `val message: String?` ("Expense added" / "Income added" on add, "Payment deleted" on delete, null on ✕ / edit save / missing id). `PaymentViewModel.delete()` (guarded by `saving`) calls `ExpenseRepository.dismissExpense(id)` then emits `Close("Payment deleted")`.
- `ExpenseListCard`/`ExpenseList`: remove `onDelete` and the trash `IconButton`.
- `HomeScreen(onOpenActivity: () -> Unit, onAddPayment: () -> Unit, onEditPayment: (String) -> Unit, onOpenSettings: () -> Unit, message: String?, onMessageShown: () -> Unit, ...)`. Today/This week rows call `ActivitySelection.show(currentMonth, currentWeekStart)` then `onOpenActivity`; month row calls `show(currentMonth)` then `onOpenActivity`. Gear (contentDescription "Settings") top right of the status line; gold "＋ Add" FAB; "Latest this week" rows → `onEditPayment(id)`.

- [ ] **Step 1:** Payment page: "Delete payment" text button (error color) under "Split this bill", editing only; confirm `AlertDialog` with the exact copy; `delete()`; `Close(message)`.
- [ ] **Step 2:** Remove trash icon + `onDelete` from `ExpenseItem.kt` and all callers.
- [ ] **Step 3:** Home changes above.
- [ ] **Step 4:** Build → exit 0.

### Task 4: Three tabs and routes

**Files:** Modify `ui/ExpenseTrackerNavHost.kt`, `ui/navigation/Routes.kt`, `ui/screens/PeopleScreen.kt`, `ui/screens/SettingsScreen.kt`. Delete `ExpensesScreen.kt`, `HistoryMonthsScreen.kt`, `HistoryWeeksScreen.kt`, `FilteredExpensesScreen.kt` and their view models (`ExpensesViewModel`, `HistoryMonthsViewModel`, `HistoryWeeksViewModel`, `FilteredExpensesViewModel`), plus routes `EXPENSES`, `HISTORY`, `HISTORY_MONTH`, `EXPENSES_FILTER` and their helpers.

**Interfaces:** `Routes.ACTIVITY = "activity"`, `Routes.SETTINGS` stays `"settings"` (no longer a tab). `PeopleScreen(onOpenPerson, onOpenSplit, onSplitBill: () -> Unit, ...)` — `onBack` removed, "Split a bill" button at the top calls `onSplitBill` (→ `Routes.splitNew(null)`). `SettingsScreen(onBack: () -> Unit, onOpenNotificationDebug, ...)` with a top bar back arrow (contentDescription "Back").

- [ ] **Step 1:** Bottom bar items Home / Activity / People (Material icons Home, List or ReceiptLong, People); `topLevelRoutes = setOf(HOME, ACTIVITY, PEOPLE)`; keep today's tab navigation options (saveState/restoreState/launchSingleTop).
- [ ] **Step 2:** Wire Home/Activity callbacks: add → `PAYMENT_NEW`, edit → `paymentEdit(id)`, open activity → navigate to `ACTIVITY` with the same options as a tab tap, settings → `SETTINGS`. Payment routes' `onClose(message)`: set `navController.previousBackStackEntry?.savedStateHandle["paymentMessage"] = message` before the guarded pop. Home and Activity read `entry.savedStateHandle.getStateFlow<String?>("paymentMessage", null)` and clear it in `onMessageShown`.
- [ ] **Step 3:** Delete the old screens, view models and routes. `git grep -n "ExpensesScreen\|HistoryMonths\|HistoryWeeks\|FilteredExpenses\|expensesFilter\|Routes.EXPENSES\|Routes.HISTORY" -- app` prints nothing.
- [ ] **Step 4:** Build → exit 0.

### Task 5: Phone check (controller)

- [ ] Back up the phone DB to `D:\Projects\expense-tracker-backup-2026-10-20-pre-three-tabs`, `adb install -r`, launch, no crash; screenshot Home, Activity, People for the owner.
