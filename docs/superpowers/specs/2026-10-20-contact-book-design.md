# Contact book: design

Status: draft for owner review. Date: 2026-10-20.

## Intent

Friends send their payment QR (DuitNow or e-wallet) in a chat. When the owner later owes them money, they scroll back through the chat or ask for the QR again. The owner pays by saving the QR picture and picking it from the gallery inside their bank or e-wallet app.

The contact book keeps each person's payment QR in Koban, one tap from "save to gallery", and shows the money between the owner and each person in both directions, reduced to one net amount: who pays whom, and how much, to settle everything.

Example: Jun Wei owes the owner RM 23.31 from a split bill, and the owner owes Jun Wei RM 18.00 for a lunch. The contact book says "Jun Wei pays you RM 5.31".

## Goals

1. Save a payment QR picture for each person, and replace it later.
2. One tap saves that QR to the phone gallery, so the owner can pick it in a bank app.
3. Record money the owner owes a person by hand (what, amount, date), and mark each item paid.
4. Show each person's net balance, combining split-bill debts (they owe the owner) and hand-entered items (the owner owes them).
5. "Settle up" closes every open item with that person, in both directions, in one step.
6. When a received payment notification equals a person's net amount owed to the owner, suggest settling up, the way "Who owes me" suggests repayments today.
7. The contact book replaces the "Who owes me" screen. Everything about people and money is in one place.

## Non-goals

- Reading or decoding the QR content. The QR is stored and shown as a picture only. No QR library.
- Paying from inside Koban, deep links into bank apps, or sharing the QR to a bank app.
- Matching the owner's outgoing transfers to items the owner owes. (Designer's call, not the owner's: incoming suggestions only, as today.)
- Contacts sync with the phone's address book.
- Cloud backup of QR pictures.

## Anti-goals

- QR thumbnails in the people list. The owner rejected them as redundant; the list shows people only.
- Losing a saved QR when the original chat picture is deleted. Koban keeps its own copy.
- A second, separate list of people. Split billing and the contact book use the same people.

## What exists today (for the builder)

- Room DB version 6, `exportSchema = false`, explicit migrations in `data/DatabaseMigrations.kt`.
- People: `split_people` (`SplitPersonEntity`: id, name, lastUsedAt). Created from the split editor's people step.
- Debts the owner is owed: `split_debts` (`SplitDebtEntity`: billId, personId, amount, status OPEN/PAID, repaymentExpenseId, suggestedRepaymentExpenseId, paidAt).
- `SplitRepository`: `observeOpenDebts`, `markPaid`, `confirmSuggestion`, `dismissSuggestion`, `suggestRepayment(receive)` (called when a RECEIVE expense is saved), `repaymentCandidates`.
- `RepaymentMatcher.match(amount, senderName, openDebts)`: picks the subset of one person's debts that sums to the amount, sender name breaks ties.
- "Who owes me": `ui/screens/DebtsScreen.kt` + `DebtsViewModel`, route `Routes.DEBTS`, opened from the Expenses screen button "Who owes me (N)". It also lists "Past splits", which open the split editor.

## Decided by the owner

- **List layout:** option A from the mockups, without QR thumbnails. Screen title "People", subtitle "Their payment QRs, and what you owe them" (wording may be tightened to cover both directions), a search box, people grouped as "You owe" first, then "Everyone else". Each row: a colored initial avatar, the name, one status line. An "Add person" button bottom right.
- **Person screen:** the QR inside a gold "koban" frame (white card, gold ring), then one primary button "Save QR to gallery", then the hint "Then open your bank app and pick it from the gallery". Below: the money with that person.
- **Owing items:** added by hand inside the contact book ("+ Add what I owe"), each resolved with "Mark paid".
- **Both directions plus a net line**, and the net says who pays whom ("Jun Wei pays you RM 5.31").
- **Replaces "Who owes me".**
- **Incoming settle suggestion:** accepted ("that works").

## Behavior

### Net balance

- `owedToMe` = sum of the person's OPEN `split_debts`.
- `iOwe` = sum of the person's OPEN hand-entered items.
- `net = owedToMe - iOwe`.
  - `net > 0`: "[Name] pays you RM net".
  - `net < 0`: "You pay [Name] RM |net|". The "Save QR to gallery" button is the next thing under this line.
  - `net = 0` with open items on both sides: "You're even". Settle up still closes everything.
  - No open items: "All paid".
- BigDecimal money with scale 2, as the rest of the app.

### List status line (one line per row)

- "You pay RM X", "Pays you RM X", "You're even", "All paid", or "No QR saved yet" when nothing is open and no QR is saved.
- Grouping (builder's call on exact names): people with net < 0 first ("You owe"), then net > 0, then the rest.
- Search filters by name.

### Settle up

- One button on the person screen when anything is open.
- Marks every OPEN split debt and every OPEN hand-entered item for that person PAID, with `paidAt = now`, in one transaction.
- Split debts closed by Settle up have no `repaymentExpenseId`, unless settle up came from an accepted suggestion (then the RECEIVE expense id is stored on them, like `confirmSuggestion`).
- A split bill locks once any of its debts has a repayment (existing rule). Settle up must follow the same rule the existing `markPaid` follows.

### Settle suggestion (incoming)

- When a RECEIVE expense arrives and `RepaymentMatcher` finds no subset match, check each person whose net > 0: if the amount equals the net exactly, and either only one person qualifies or the sender name matches that person (same word rule as the matcher), suggest "Settle up" on that person's screen: "Possible settle up: RM 5.31 from JUN WEI, 20 Oct" with "Confirm" and "Not this".
- Confirm runs Settle up and links the RECEIVE expense. Not this hides the suggestion.
- Existing per-debt suggestions keep working and show on the person screen.

### Hand-entered items ("You owe [Name]")

- Add: what (text, required), amount (> 0), date (defaults to today, date picker like the edit-expense dialog).
- Each item: what, date, amount, "Mark paid". Edit and delete an open item (builder's call on gesture).
- Marking paid does not create an expense. The owner's real bank transfer is logged by the notification listener as usual.
- Spending (owner's decision): hand-entered items never count as spending. Only the owner's real bank transfer counts. Accepted gap: an amount cancelled out by netting in a Settle up never counts as spending.

### People

- Add person: name (required), QR (optional). Names must be unique, case-insensitive, trimmed; adding an existing name opens that person instead.
- People created in the split editor appear in the contact book automatically, and people added here appear in the split editor's people list.
- Rename on the person screen.
- Delete a person: only when they have no open items in either direction; it removes their QR copy and their PAID hand-entered items. Split-bill history keeps their name (builder decides how: keep the row hidden, or keep it and filter).

### QR picture

- Pick with the Android Photo Picker (`PickVisualMedia`, images only, no storage permission).
- Koban copies the picked image into app-internal storage (`filesDir/qr/<personId>.<ext>`) and stores the path on the person. Replace overwrites; delete person deletes the file.
- Shown full width in the koban frame on the person screen; tap opens it full screen at max brightness for scanning from another phone (builder's call whether to include; small).
- "Save QR to gallery": writes a copy to `Pictures/Koban/` through MediaStore, named `koban-<name>-qr.jpg` (overwrite or new file: builder's call). On API 26–28 this needs `WRITE_EXTERNAL_STORAGE`, requested at the moment of the first save; minSdk is 26.
- After saving, a snackbar: "Saved to gallery. Open your bank app and pick it."
- No QR yet: the frame shows an empty state "Add their payment QR" that opens the picker.

### "Past splits"

- Moves from the old Who owes me screen to the bottom of the People list (builder may choose a better spot, for example the Expenses screen). They still open the split editor.

### Navigation

- Expenses screen: the "Who owes me (N)" button becomes "People", with a count of people who have anything open (builder's call on the badge).
- New routes: people list, person detail (`people/{personId}`). `Routes.DEBTS`, `DebtsScreen` and `DebtsViewModel` are removed or folded in.

## Data changes

- DB version 7 with a migration from 6:
  - `split_people`: add `qrPath TEXT NULL`.
  - New table for hand-entered items, for example `owed_items` (id, personId, description, amount TEXT, createdAt, itemDate, status OPEN/PAID, paidAt NULL), index on personId.
  - A place to store the settle suggestion (for example on the person row: `suggestedSettleExpenseId`) — builder's call.
- The migration must keep all existing data. Back up the phone database before installing (owner's standing rule).

## Visual design

- Same tokens as the app: Bricolage Grotesque; dark theme default and Banknote light theme, both supported.
- The one bold element is the koban QR frame: white card, 4dp gold ring (`gold` token), soft outer gold glow ring. Everything else stays quiet: plain rows, hairline dividers, no cards around list rows.
- Money colors: amounts the owner pays use `gold`; amounts paid to the owner use the `received` token (green). Text stays in text colors; colors sit on the amount only.
- Primary button "Save QR to gallery": gold fill, ink text, 50dp tall, full width.
- Mockups: brainstorm session file `contact-book.html` (option A + person screen), kept in the session scratchpad.

## Constraints

- No new dependency for QR decoding. Photo Picker comes from AndroidX Activity, already present.
- No instrumented tests. Unit-test the net balance, list grouping and settle-suggestion matching as pure functions; test the migration SQL by review.
- Sample data only in any screenshot or demo.
- No commits without the owner asking in that request.

## Designer's calls (from the builder check)

- **Currency:** Koban is MYR-only. Net sums assume RM; no currency column on owed items.
- **People added in the contact book:** `lastUsedAt = now` at creation, so they show at the top of the split editor's list.
- **Delete:** a person can be deleted only with no open items. Deletion sets an `archived` flag (new column in v7) rather than removing the row, so split history keeps the name. Archived people are hidden from the contact book and the split editor. Adding or using the same name again revives the archived row.
- **Names:** uniqueness is enforced in app logic (trim, case-insensitive), not by a DB index. The migration does not merge existing near-duplicates. New inserts trim the name.
- **Settle up confirmation:** Settle up shows a confirm dialog that lists what it closes and says that split bills it touches become locked. No undo, same as today's Mark paid.
- **Settle suggestion lifecycle:** stored on the person row. Cleared when any open item of that person changes, when a per-debt suggestion for the same expense is confirmed, or on "Not this". Confirm re-checks that the RECEIVE amount still equals the current net, and refuses with a message if not.
- **Settle up from a suggestion:** the RECEIVE expense id is stored on the closed split debts only; hand-entered items get no link.
- **QR files:** live in `filesDir/qr`. They survive app updates (`install -r`); losing them on uninstall is accepted.

## Left to the builder

Gestures for edit/delete of items, exact group names, badge style, empty-state copy beyond what is written, whether the full-screen QR view ships, and file naming of gallery copies.
