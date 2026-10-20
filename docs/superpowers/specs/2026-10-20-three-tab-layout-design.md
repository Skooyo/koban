# Three-tab layout (option C): design

Status: draft for owner review. Date: 2026-10-20. Builds on the payment page (branch `feature/payment-page`).

## Intent

Home shows numbers but offers no actions; the owner must switch to the Expenses tab to add a payment, and People hides as a small pill there. Expenses and History are two tabs for one job (look at payments over time), and Settings takes a full tab though it is rarely opened. Each row also has a trash icon, so one mis-tap removes a payment.

The owner chose option C after seeing a storyboard of 6 tasks: three tabs, Home / Activity / People, with Settings as a gear on Home.

## Goals

1. Bottom bar: **Home**, **Activity**, **People** (in this order). No other tabs.
2. **Home** (today's content stays): tracking status line, Today hero, This week and month rows, "Latest this week". New: a gear button at the top right (opens Settings) and a gold "＋ Add" floating button (opens the payment page).
3. **Activity** replaces the Expenses and History tabs and the filtered-expenses screen:
   - Title "Activity".
   - Month bar: ‹ previous month, the month name with ▾ (tap opens a "Pick a month" bottom sheet), › next month (disabled on the current month).
   - Under it: the month total (spending, as History shows it), then a strip of that month's weeks with their totals (as History's week screen shows them). Tapping a week shows only that week; tapping it again shows the whole month.
   - Category filter chips, as on Expenses today.
   - The payments of the selected month (or week), grouped by day with day totals, as on Expenses today, newest first.
   - Gold "＋ Add" floating button.
   - The "Pick a month" sheet lists the months that have payments, newest first, each with its total and a bar, as the History tab does today.
4. **People** tab: today's People screen (from the contact book), without its back arrow. A "Split a bill" button sits at the top of it (moved from Expenses).
5. **Settings**: today's Settings screen, opened as a full page from the Home gear, with a back arrow. Bottom bar hidden.
6. **No trash icon on rows.** The payment page (editing) gets a "Delete payment" text button under "Split this bill"; it asks first ("Delete this payment?" / "It will no longer count in your totals." / "Delete" / "Cancel"), then closes the page and the list shows a "Payment deleted" snackbar. Delete does what the row's trash icon does today.
7. After adding a payment, the screen that opened the page shows an "Expense added" / "Income added" snackbar.

## Navigation from Home

- "Today" and "This week" rows open Activity on the current month with the current week selected.
- The month row opens Activity on the current month, whole month.
- Tapping a row in "Latest this week" opens the payment page for it (today it does nothing or opens edit; make it edit).

## Non-goals

- No change to how totals are computed, to the payment page fields, to the split editor, or to the People/Person screens beyond the tab change and the "Split a bill" button.
- No new settings.
- No change to the data model.

## Anti-goals

- Losing a feature: everything reachable today stays reachable (History months and weeks, category filter, split a bill from scratch, notification log via Settings, People, delete).
- Swipe-to-delete or any other one-gesture delete.

## Builder notes (what exists)

- Tabs and routes: `ui/ExpenseTrackerNavHost.kt` (`BottomNavItem` list, `topLevelRoutes`), `ui/navigation/Routes.kt`.
- Screens to merge into Activity, then delete: `ExpensesScreen` (+ `ExpensesViewModel`), `HistoryMonthsScreen`/`HistoryWeeksScreen` (+ view models), `FilteredExpensesScreen` (+ view model). Data: `ExpenseRepository.observeMonthlySummaries()`, `weekSummariesForMonth(year, month)`, `observeInRange(start, end)`, category filter helper `matchesCategory`.
- Row delete today: `ExpenseItem`'s `onDelete` → view model `dismiss`/`delete` → `ExpenseRepository.dismissExpense`.
- People screen: `PeopleScreen(onBack, onOpenPerson, onOpenSplit)`.

## Designer's calls (settled after the builder check; owner can override)

1. **Weeks across a month edge** are full Monday–Sunday weeks, as History shows them today (`PeriodCalculator.weeksInMonth`, `weekSummariesForMonth`). A week chip shows the full-week total. Selecting a week lists all 7 days, including days of the neighbor month. So "This week" on Home and the selected week in Activity show the same number.
2. **Stepping months** (‹ ›, or picking from the sheet) clears the week selection to "whole month".
3. **Empty months:** ‹ can step into any earlier month, and › stops at the current month. A month with no payments shows "No payments in [Month Year]." The sheet lists the months that have payments, plus the current month even when it is empty.
4. **Messages after the payment page closes:** the page returns a one-line message to the screen under it ("Expense added", "Income added", "Payment deleted"). Use the previous back-stack entry's `savedStateHandle`. That screen shows the message as a snackbar. Delete has no Undo, because it already asks first.
5. **Trash icon removed everywhere** `ExpenseItem` is used; drop its `onDelete` parameter. Every payment row in Home, Activity and Person opens the payment page in edit mode. Income, split and notification-captured payments can all be edited and deleted there, as today.
6. **Activity state:** Home's rows set Activity's month and week, then switch to the Activity tab. Pressing the Activity tab shows the last selection. On a cold start it shows the current month, whole month. The payment page and Settings hide the bottom bar.
7. **Filtered list route removed:** only Home and History used `Routes.expensesFilter`, and both now go to Activity. Delete the route and `FilteredExpensesScreen`.

## Left to the builder

- Activity view model shape; how the selected month/week is held (survive rotation).
- The week strip's exact look (from the storyboard: small chips with date range and total, the selected one outlined in gold).
- Whether the Home FAB and Activity FAB share one composable.
- Icons for tabs and the gear (Material icons already in the project).

## Testing

- JVM unit test for any new pure month/week stepping logic (previous/next month across a year boundary; next disabled on the current month).
- No instrumented tests. The owner checks on the phone.
