# Add / edit payment page: design

Status: draft for owner review. Date: 2026-10-20.

## Intent

Adding an expense or income by hand uses a small popup today (`ui/components/EditExpenseDialog.kt`). It has plain text fields, a "Type" dropdown with the words "Withdraw" / "Receive", and the phone keyboard covers half of it. The owner wants a full page that is fast and pleasant to use, modeled on a reference screen they supplied (layout "A" in the mockups).

## Goals

1. One full-screen page replaces the popup for both adding (the + button) and editing (tap a payment row).
2. A large amount at the top, typed with an on-page number pad. The phone keyboard does not open for the amount.
3. An Expense / Income switch at the top, instead of the "Type" dropdown.
4. Category, Date, Shop, and Note as tappable cards between the amount and the number pad.
5. One large bottom button: "Add expense" / "Add income" when adding, "Save" when editing.

## Non-goals (owner's decision)

- Budgets or "left to spend" lines.
- A "Paid with" (cash / card / e-wallet) field.
- A Transfer type.
- Scan (receipt camera) and Say (voice) input.
- Any change to the data saved: the page saves exactly what the popup saves today.

## Anti-goals

- A page that is slower than the popup for a simple entry. A typical entry is: type amount, pick category, tap Add.
- Losing any feature the popup has today (listed below).

## Layout (owner chose mockup A)

Top to bottom, in Koban's theme (dark default and Banknote light; `MaterialTheme.colorScheme` and `LocalMoneyColors`; Bricolage Grotesque):

1. Top row: a round ✕ close button, then a two-part switch "Expense" | "Income". Selected Expense is a neutral filled pill; selected Income uses `received` green.
2. Amount: very large and bold, centered, "RM" in a smaller muted size before the digits, with a gold caret while the number pad is active. Income shows "+RM" and the digits in `received` green. Expense digits use the normal text color.
3. Cards (rounded surface cards, a small round icon, a small label above the value):
   - Category, full width, with a colored dot or icon from `categoryColor()` and a chevron. Tapping opens a bottom sheet listing "Uncategorized" plus all categories, each with its color.
   - Date and Shop, side by side. Date shows "Today", "Yesterday", or "Mon, 12 Oct". Tapping opens the existing `PastDatePickerDialog` (no future dates).
   - Note, full width.
   Empty Shop and Note show "Optional" in muted text.
4. Number pad: 1–9, ".", 0, backspace, as large rounded keys.
5. Bottom button: gold, full width, "✓ Add expense" / "✓ Add income" / "Save".
6. When editing an expense: a "Split this bill" text button above the bottom button (only for Expense, as today).

The approved mockup is layout A in `add-page.html` from the brainstorm session (not in the repo); this section is the binding description.

## Behavior

- Adding opens with amount empty, Expense selected, Uncategorized, date now, Shop and Note empty.
- Editing opens with every value filled in from the payment.
- Amount input: at most 2 digits after ".", only one ".", and a sensible upper limit (builder's call, e.g. 9 digits before the point). Backspace removes one character.
- The bottom button is disabled while the amount is empty or 0. The popup's error "Enter an amount above 0" is no longer needed.
- Shop and Note use the normal phone keyboard. While either is focused the number pad hides; tapping the amount brings the pad back and hides the keyboard. (Owner's designer call.)
- The Shop card keeps today's hint, in a small line under the card when the category changes: "A new category also applies to past payments from this shop". Exact placement is the builder's call; it must stay visible somewhere on the page when editing.
- Save behaves exactly as `ExpensesViewModel.saveEdit` today: `addManualExpense` when adding, `updateExpense` when editing, the same merchant-category rule, and protection against a double tap adding twice.
- ✕ and system Back close the page without saving. No "discard changes?" prompt (builder's call; add one only if cheap).
- After saving, the page closes and returns to the screen that opened it.
- "Split this bill" first saves the page's edits (same path as Save), then closes the page and opens the split editor for that payment. The split editor loads the payment from the database, so it sees the new amount. "Split this bill" is disabled while the amount is empty or 0. (Designer's call: today's popup drops unsaved edits here; on a full page that would lose a just-typed amount.)

## Where it is used

- `ExpensesScreen`: the + button and row taps.
- `FilteredExpensesScreen`: row taps.
- Any other caller of `EditExpenseDialog` must move to the page. After the change, `EditExpenseDialog` is deleted, but `PastDatePickerDialog` stays (the contact book's `PersonDialogs.kt` uses it); move it to its own file if the dialog file goes away.

## What exists today (for the builder)

- `EditExpenseDialog(expense, categories, onDismiss, title, onSplit, onSave(amount, merchant, postTime, categoryId, notes, transactionType))`.
- `ExpensesViewModel`: `editingExpense` state, `startAdding()` (a blank `ExpenseEntity` with id `""`), `isAdding()`, `saveEdit(...)`, `clearEditing()`.
- `ExpenseRepository.addManualExpense(...)` and `updateExpense(...)`.
- `TransactionType.WITHDRAW` = expense, `RECEIVE` = income.
- Navigation: `ui/navigation/Routes.kt` and `ui/ExpenseTrackerNavHost.kt`. The bottom navigation bar shows only on top-level routes, so a new route hides it automatically.
- `AmountFormatter.parseInput` and `formatGrouped`.

## Left to the builder

- Whether the page is a nav route with its own view model (reading the payment id from the route) or keeps using `ExpensesViewModel`; a route with its own view model is preferred so both list screens share it.
- Icons for the cards, exact sizes and spacing, and the bottom sheet style.
- Whether the amount shows thousands grouping while typing.

## Testing

- JVM unit tests for the amount input rules (digits, one ".", 2 decimals, backspace, limit, zero disables Save).
- No instrumented tests. The owner checks the page on the phone.
