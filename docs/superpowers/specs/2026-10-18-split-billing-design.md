# Split billing: design

Date: 2026-10-18
Status: reviewed by a builder check; waiting for owner approval

## Why

The owner often pays the whole bill at a meal (card or e-wallet) and then
collects money from friends. Today the tracker records the full payment as
the owner's spending, and repayments arrive later as separate "Receive"
transactions. The owner wants to:

1. Photograph the receipt and get every item listed without typing.
2. Assign each item to the people who had it.
3. See what each person owes, including their fair share of service charge
   and tax.
4. Have the tracker count only the owner's own share as spending.
5. Track who still owes money until they pay.

## Goals

- Receipt photo to an editable list of items in one step.
- Assign items to people fast: tap an item, tap names.
- Correct per-person totals, with service charge, SST, discounts and
  rounding split in proportion to each person's item subtotal.
- The linked card payment counts only the owner's share in Today, This week,
  This month, History, and category totals.
- A list of open debts ("who owes me"), with a way to mark each one paid.
- Share a plain-text summary (for WhatsApp) through the Android share sheet.

## Non-goals (v1)

- Tracking money the owner owes to others (bills someone else paid).
  Owner's call needed if this matters; see "Open questions".
- Sending payment requests, DuitNow QR, or any payment integration.
- Syncing people or bills between phones. Everything stays on the phone.
- Multiple currencies on one receipt. A receipt is in one currency (MYR by
  default).
- Unequal splits of one item (for example 70/30). Shared items split evenly.

## Anti-goals (would make it a failure even if it works)

- Spending totals that count the same money twice. Example: the owner's share
  is RM 40 of a RM 120 bill, and then a friend's RM 40 repayment also lowers
  spending. Totals must stay correct when repayments arrive.
- Losing a split because the AI read failed. The owner must always be able to
  type or fix items by hand.
- Slow assignment. Assigning 8 items to 4 people must not need more than
  about 20 taps.

## Constraints

- Existing app: Kotlin, Jetpack Compose, Material 3, Hilt, Room (database
  version 5 today), DataStore, OkHttp. Follow the existing code style and the
  "Ringgit notes" theme (Theme.kt, components in ui/components).
- AI: use the existing Gemini client (GeminiClient.kt, same API key from .env,
  same primary/secondary model fallback on rate limits). Send the photo as
  inline image data with a JSON response schema. If there is no API key or the
  call fails, open the editor with an empty item list so the owner can type.
- Camera: use the system camera (ActivityResultContracts.TakePicture) and the
  system photo picker. No new camera library.
- The database migration from version 5 must keep all existing data. The
  owner's real data (379 expenses) lives on the phone; a backup exists at
  D:\Projects\expense-tracker-backup-2026-10-18.
- Debug builds only, installed by USB. No Play Store.

## How it works (decided)

### Entry point

A "Split a bill" button on the Expenses screen, and a "Split this bill" action
in the edit dialog of an existing expense (this pre-links that expense).

### Flow

1. **Photo.** Take a photo or pick one from the gallery.
2. **Read.** Gemini returns: merchant name, date if printed, line items
   (name, quantity, line price), service charge, tax (SST), discount,
   rounding, and the printed total. Show a loading state while it reads.
3. **Check items.** An editable list. The owner can rename, change price,
   delete, or add an item, and edit the charges. Show the sum of items plus
   charges next to the printed total, and flag a mismatch clearly.
4. **People.** "Me" is always included. Add people by name; names used
   before are offered first (most recent first).
5. **Assign.** Tap an item, then tap each person who shared it. An item with
   no one assigned blocks the next step and is highlighted.
6. **Link payment.** Suggest recent expenses (last 3 days) whose amount equals
   the bill total, newest first. The owner picks one or chooses "Not paid yet
   / paid in cash". Linking is optional.
7. **Summary.** Each person's total. Buttons: "Share summary" (plain text to
   the Android share sheet) and "Done".

### Money rules

- Item split: an item shared by N people costs each person price / N.
- Charges (service charge, SST, discount, rounding) split in proportion to
  each person's item subtotal.
- Round each person's total to 2 decimals with half-up. Give any leftover
  cent (so the totals add up exactly to the bill total) to "Me".
- Use BigDecimal everywhere, like the rest of the app.

### Bill total and mismatches (builder's questions, settled)

- The shares are computed from the item list plus charges ("computed total").
- If the computed total differs from the printed total, warn and offer
  "Add the difference as rounding". Never block saving. (Claude's call.)
- If a linked expense amount differs from the computed total (tip, wrong
  expense picked), warn but allow it. The owner's spending for that expense =
  linked expense amount minus the sum of the other people's debts. "Me"
  absorbs the difference. (Claude's call.)

### Effect on the tracker

- Today every total subtracts all Receive rows from spending (ExpenseDao
  queries and the day header sum in ExpenseItem.kt). Split billing changes
  this, as below.
- A linked expense counts as the owner's spending as defined above, in every
  spending total and in its category. The expense row shows that amount as the
  main amount, with the full amount paid in smaller text.
- Each other person's share becomes an open debt.
- Repayments (owner's decision): **the app suggests, the owner confirms.**
  When a Receive transaction is saved (from a notification), check open debts.
  If its amount equals one open debt, or the sum of several whole open debts of
  the same person, mark it on those debts as "Possible repayment". Prefer
  matches where the sender name in the notification resembles the person's
  name. The owner confirms with one tap. Until confirmed, the transfer counts
  as normal received money.
- A confirmed repayment does not count in spending totals, so money is not
  counted twice.
- One repayment can close one or more **whole** debts of the same person
  (owner's decision). No part payments or overpayments in v1.
- "Mark paid" by hand: pick a Receive transaction to link (same rules), or
  choose "Cash", which just closes the debt.
- Deleting a split restores the linked expense to its full amount, removes its
  debts, and returns any linked repayments to normal received money.

### Editing after saving (Claude's call)

- A payment can be linked to a split later (the card notification can arrive
  after the split is saved).
- Items, charges and people can be edited until any debt of that split is
  marked paid. After that, only the linked payment can change; to change
  anything else, the owner deletes and redoes the split.

### Where things live in the UI

- A "Who owes me" section: open debts grouped by person, with each bill,
  amount and date. A total per person. Tap a debt to mark it paid.
- A list of past splits, each opening its summary.
- Exact placement (new bottom tab vs a section on Expenses) is the builder's
  call; prefer not to add a fifth tab unless it reads better.

## Left to the builder

- Database schema and migration details (tables for bills, items, people,
  item assignments, debts, and links to expenses).
- Gemini prompt wording and JSON schema, image size and compression before
  upload (keep requests small; receipts are text).
- Whether to keep the receipt photo after reading (default: do not keep it).
- Screen layouts within the existing theme and components.
- How the "Possible repayment" state is shown (badge on the debt, a
  notification, or both), within the existing theme.
- Tests: end-to-end style tests for the money rules (item split, proportional
  charges, rounding to the exact total, linked amount different from computed
  total) and for totals not double counting a confirmed repayment.

## Calls made for the owner (to confirm while reading)

1. v1 tracks only bills the owner paid, not bills others paid for the owner.
2. Shared items always split evenly.
3. Leftover rounding cents go to "Me".
4. Receipt photos are not stored.
5. A printed-total mismatch and a linked-amount mismatch warn but never block.
6. A split can be edited until a debt is marked paid; a payment can be linked
   later at any time.
