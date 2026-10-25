# Regex capture with a swipe confirm step

Date: 2026-10-25. Status: reviewed; waiting for the owner's approval.

## Why

- Gemini auto-save still lets promotions through as expenses, and it puts the date of spending into the merchant name. The owner finds these mistakes only later, in the totals.
- The owner may publish Koban. A published app must not depend on an LLM: no API key in the app, no cost per notification, no notification text sent to Google.

## What changes, in one paragraph

Notifications from allowlisted apps are read by regex rules, not by Gemini. A match is stored as a **waiting payment**. It does not count in any total. When the owner opens Koban and at least one payment waits, a swipe screen opens: swipe right saves it as an expense, swipe left drops it. Gemini becomes an optional setting, off by default, with the user's own API key. When it is on, it only pre-fills the waiting card. Nothing is saved without a swipe right.

## Goals

1. No expense is saved from a notification without the owner's yes.
2. No real payment from an allowlisted app is lost, even in a message form the rules do not know. (Changed by the owner on 2026-10-25: promotions with an amount may reach the swipe screen; the owner drops them.)
3. Other banks and wallets still work, through a generic rule, with their cards marked "Unknown format".
4. The default build makes no network call to parse a notification.
5. Clearing 8 waiting payments takes a few seconds.

## Non-goals

- User-made rules (a screen to build a regex from a sample). Not now.
- Learning: auto-saving a pattern after N approvals. Not now.
- Receipt scanning for split bills. It still uses Gemini. See "Gemini setting" for how it gets its key.
- Changes to existing saved expenses. They stay as they are.

## Anti-goals (a failure even if it works)

- A waiting payment that leaks into Home, Activity, category totals, or repayment matching before the swipe.
- A swipe right that saves a duplicate of an expense that already exists.
- A real payment lost because the owner swiped by mistake (Undo must cover this).
- A real notification text from the owner's phone in the repo, tests, or docs. Tests use made-up merchants only.

## Capture flow

1. The listener ignores every package that is not in the payment apps list (see the picker below). An empty list ignores everything.
2. The text goes to the rule engine:
   - **Known app** (a package with built-in rules): try its strict rules first. A strict match fills amount, merchant and direction exactly (`format = KNOWN`).
   - **No strict match, or an unknown app** (owner's change after the phone test, 2026-10-25): catch-all. Any text with an `RM` or `MYR` amount becomes a waiting payment with `format = UNKNOWN`. Nothing with an amount is dropped; a promotion becomes a card the owner swipes left. Only a text with no amount is "No rule matched".
   - **Direction:** a payment word decides Spent or Received. When the text shows neither, or both, the card is marked "direction unclear": it shows "Spent or Received?" with both choices, and Save needs a choice first.
3. If Gemini is on (see below), Gemini may pre-fill merchant and category of the waiting payment, and may mark it "likely promotion". It never saves an expense, and it never drops a match from a known-app rule.
4. Dedup runs before a waiting payment is stored: skip it when the same notification key, or a duplicate by today's dedup rules, already exists as an expense, as a waiting payment, or as a dropped marker (see Swipe left). Today's same-amount window check does not compare packages, so one payment reported by both Maybank and Touch 'n Go stays one card; keep that.
5. The notification debug log gets a new disposition, "Waiting for check", in place of "Saved" for this flow.

`NotificationParser` stays as the generic rule. `GeminiClient` stops being a parser in this flow and becomes an optional enricher of a waiting payment.

## Payment apps picker (owner's decision)

The user picks which installed apps are payment apps. Koban listens to those apps only.

1. **First run:** after notification access is on, Koban shows a list of installed apps and asks the user to tick the payment apps. Known apps (Maybank, Touch 'n Go) that are installed show first and start ticked. The other apps follow in alphabetical order, with a search field.
2. **Settings:** a "Payment apps" entry opens the same list, to add or remove apps at any time. It replaces today's package-name text field and the "recent packages" list.
3. **Empty list now means "listen to no app"**, not "every app". With an empty list, Home shows a prompt that opens the picker.
4. **Upgrade:** a user who upgrades with a non-empty allowlist keeps it. A user who upgrades with an empty allowlist (today's "every app") sees the picker the next time they open Koban, so capture does not stop without a word.
5. The list uses a `<queries>` entry for launcher activities (`MAIN` + `LAUNCHER`), not `QUERY_ALL_PACKAGES`, so it is allowed for a Play Store app. Each row shows the app icon and label.

## Built-in rules

Rules were built from the owner's own saved notifications (about 390 messages, all local; none copied into the repo). Each rule gives amount, merchant (or sender), and spent or received. Merchant text stops before card tails ("with your…", ". REF:", ". View your receipt").

Maybank (`com.maybank2u.life`), shapes seen, with made-up merchants:

| Shape | Type |
|---|---|
| `You've just spent RM 23.40 at KEDAI RUNCIT AMAN with your Maybank Debit Card Visa ending 1234. View your receipt now.` | spent |
| `Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.` (also `REF: 123456Q`) | spent |
| `M2U: You have successfully paid RM12.00 to CONTOH SDN BHD.` | spent |
| `You've transferred RM 50.00 to ALI BIN ABU. REF: 123456M` (also `…Q`) | spent |
| `You've successfully withdrawn RM 100.00 from your account ending 1234.` | spent, merchant "ATM withdrawal" |
| `You've received RM 40.00 from SITI AMINAH. REF: 123456Q` | received |
| `You've just received RM 40.00 in your account ending ***1234. REF: …` | received, merchant unknown |

Touch 'n Go (`my.com.tngdigital.ewallet`):

| Shape | Type |
|---|---|
| `You have paid RM12.50 to CONTOH CAFE.` | spent |
| `RM 30.00 has been successfully transferred to ALI BIN ABU.` (also with a `Transfer Successful.` prefix) | spent |
| `RM 20.00 received from SITI AMINAH.` | received |

Google Wallet (`com.google.android.apps.walletnfcrel`) is a known app with **no** rules: its card taps repeat the bank's own notification, so it never creates a waiting payment.

Shapes that must not match (seen in the owner's data): transfer-limit notices, deposit-rate offers, gold-price and referral promotions in Malay and Indonesian, "Klaim diskon RM…".

**Generic rule** (catch-all; used for unknown apps and for known-app texts no strict rule matches): today's `NotificationParser` logic: an `RM` or `MYR` amount plus a payment word decides the amount and type. The merchant uses today's merchant patterns.

**Dates:** a date or time inside the text is never part of the merchant. The transaction date is the notification post time.

## Waiting payments: storage

- A new table, not a new status on `expenses`, so no existing total or list query can count them by accident. Suggested name: `pending_payments`.
- Fields: id, amount, currency, merchant (nullable), transactionType, sourcePackage, rawNotificationText, notificationPostTime, notificationKey, format (`KNOWN` | `UNKNOWN`), suggested categoryId (nullable), likelyPromotion (Gemini only), createdAt.
- A second small table holds the dropped markers.
- Database v8 → v9 migration creates both tables.
- Waiting payments never expire.

## Swipe screen

The owner approved an interactive prototype (larger-text version). Behavior:

1. Opens by itself when Koban comes to the foreground and at least one payment waits. Back closes it; the payments keep waiting.
2. Home shows a banner, for example "3 payments to check", that opens the screen again. No banner when none wait.
3. A stack of cards, oldest first, with a counter ("1 of 3"). Each card shows: app name and time, amount (large), Spent or Received, merchant, category, date, and the full notification text. "Unknown format" or "Likely promotion" shows as a tag when it applies.
4. Drag right past a threshold: save. Drag left: drop. The card tilts and shows a "SAVE" or "NOT A PAYMENT" stamp while dragged. Two round buttons (✕ and ✓) do the same, for accessibility and for users who do not swipe.
5. Tap merchant, category, or date to edit it on the card before the swipe. Amount and Spent/Received are editable too.
6. After each swipe an "Undo" pill shows for 4 seconds. Undo puts the card back on top and reverses the save or drop.
7. Text uses Koban's type scale at the larger sizes of the approved prototype, and follows the system font size.

**Swipe right** saves through a sibling of today's `ExpenseRepository.saveFromNotification`: dedup check, merchant category memory, repayment suggestion for a received payment. Dedup runs again on the card's values as edited, with the window around the notification post time, not "now". If dedup finds the expense already exists, the card is removed and a short message says so. The edited merchant teaches the merchant category memory, as a manual edit does today.

**Swipe left** deletes the waiting payment and keeps a small dropped marker (notification key and dedup key, with a time). Capture checks these markers, so a re-posted or updated notification does not come back. Markers older than 30 days are deleted.

**Commit timing and Undo.** A swipe is held for the 4-second Undo window and then committed. Undo inside the window only puts the card back; nothing was written yet, so no side effect needs reversal. Leaving the screen or the app (on stop) commits all held swipes at once, so closing the app inside the window loses nothing.

**Edits** on a card are written to the waiting row at once, so they survive leaving the screen.

The Home banner count is a live Flow from the database.

## Gemini setting

- Off by default in every build. Settings gets an "Use Gemini to pre-fill" switch and a field for the user's own API key. The key is stored in app-private storage that is excluded from Android backup, and it is never logged.
- The build-time key from `.env` stays supported for the owner's own build, as the default value of that field. The switch still starts off.
- Receipt scanning uses the same key. With no key, receipt scanning shows a message that it needs a Gemini key.
- When on: Gemini runs on each waiting payment and may fill merchant, category, and the "likely promotion" tag. Its merchant must not contain a date. A Gemini failure leaves the regex values as they are.

## Out of the default path

The current auto-save flow is removed. No setting brings it back.

## Testing

- Unit tests for every rule: one made-up example per shape above parses to the exact amount, merchant, and type; every "must not match" shape returns no match for a known app.
- A unit test that a date in the text never lands in the merchant.
- Dedup: a waiting payment is not created twice for one notification, and swipe right on a payment that already exists as an expense saves nothing.
- On the phone, after a database backup: migration v8 → v9 opens with all data; a real Maybank payment shows on the swipe screen; swipe right adds it to Home totals; swipe left leaves totals unchanged; Undo works both ways.
- No instrumented tests (owner rule).

## Left to the builder

- Exact regex text, rule data structure, and where rules live in code.
- The drag threshold, animation timing, and card stack depth.
- How the "opens by itself" trigger is wired (for example, on resume of the main activity).
- Wording of messages, within Koban's existing voice.
