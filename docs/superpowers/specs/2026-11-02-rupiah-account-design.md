# Rupiah account

Date: 2026-11-02. Status: owner answered a design interview on 2026-11-02; builder check done; waiting for the owner's approval.

## Why

- The owner makes regular trips to Indonesia and pays there with OVO (`ovo.id`) and myBCA (`com.bca.mybca.omni.android`). Today Koban reads only RM/MYR amounts, so Indonesian spending is lost or read wrong ("Rp 25.000" either does not parse or becomes 25.00).
- The owner does not want rupiah mixed into the ringgit budget. The model is **two accounts in one app**: an RM account and an Rp account. The owner looks at one account at a time and switches when they want.
- The owner must not miss payments in the account that is not on screen. When the app opens, the cards to check come from both accounts.

## What changes, in one paragraph

Every money row belongs to one account, RM or Rp. All screens (Home, Activity, People, splits, categories) show only the active account. A setting switches the active account; the app remembers the last one. Notification capture decides the account from the currency in the text. The Check payments screen is the one place that shows both accounts at once. Rp amounts are whole rupiah, shown as "Rp 25.000". Split billing in the Rp account can scan Indonesian receipts with a second rule set, tested on a public Indonesian receipt dataset. Top-ups from a bank to the owner's own wallet stop counting as spending, in both accounts.

## Goals

1. An OVO or myBCA payment in rupiah becomes a card, and after the swipe it is in the Rp account only.
2. RM totals, categories, People and splits do not change when Rp data exists. Rp totals never include RM, and RM totals never include Rp.
3. The owner can switch accounts in Settings in two taps. The app opens on the last account used.
4. A card for either account is visible on the Check payments screen, whatever account is active.
5. A bank-to-own-wallet top-up (BCA to OVO, Maybank to TNG) is not counted as spending.
6. An Indonesian receipt photo in an Rp split gives items in whole rupiah, with the same safety rule as the RM reader: no wrong read accepted without a flag.

## Non-goals

- No exchange rates, no conversion, no combined total across accounts.
- No trip grouping.
- No third currency. Build for exactly RM and Rp; do not build a general currency system.
- No shared contacts between accounts (see Accounts).
- BCA mobile (`com.bca`) is not watched in this version.

## Anti-goals (a failure even if it works)

- A payment lands in the wrong account without the owner seeing it. When the account is unclear, the app asks.
- Any RM screen, total or debt changes value after the upgrade.
- An Rp amount shows with decimals, or an RM amount loses its decimals.
- Two real Rp payments of the same amount from two different apps are merged as one by the duplicate check (the reason BCA mobile is not watched).

## Accounts

- Two accounts, fixed: **RM** (MYR, 2 decimals) and **Rp** (IDR, 0 decimals). All data that exists today belongs to RM.
- **Separate per account:** payments (expenses), waiting cards, totals and the Activity screen, categories, the merchant-to-category memory, the contact list (People), owed items, splits and debts.
- **Contacts are not shared.** A friend who owes both RM and Rp is two entries, one in each account (owner's decision).
- **Account key (builder's call, settled):** the account is the currency code, "MYR" or "IDR". Tables that already have a `currency` column use it as the account. The other money tables get the account from their parent row or a new column (builder's choice). Old rows already hold "MYR".
- **Categories (builder's call, settled):** the database upgrade copies the RM category list (names and colors) into the Rp account, so the Rp list exists before any Rp card arrives. After that the two lists change separately. The merchant-to-category memory starts empty for Rp. A card's category picker and suggestion always use the card's own account.
- **Switch:** a control in Settings selects the active account. The choice persists across restarts; the app opens on it. Every screen that shows money reflects the active account. The Home screen shows which account is active (builder's call how; the owner should never wonder which account the totals are for).
- **Check payments:** shows waiting cards from both accounts. Each card shows its currency in its amount ("RM 12.50", "Rp 25.000"). The waiting count on Home counts both accounts.

## Capture

- **Account from the currency in the text.** A text with an RM/MYR amount goes to RM; a text with an Rp/IDR amount goes to Rp. The app that posted it does not decide.
- **No currency in the text:** the card gets a "Pick account" tag and cannot be saved until the owner picks RM or Rp on the card. (Example: "Pembayaran berhasil 25.000".) Swiping it away works as for any card. Picking the account clears the card's category and runs the category suggestion again from that account's memory.
- **Watched apps:** OVO and myBCA join the known payment apps, so the payment-apps screen offers them. BCA mobile is not offered as known.
- **No known samples yet.** The exact OVO and myBCA notification texts are not public. Version 1 reads any "Rp"/"IDR" amount from any watched app with the catch-all reader, and those cards carry the existing "Unknown format" tag. Strict per-app rules for OVO and myBCA come later, written from real notifications the owner collects in the notification log on the next trip.
- **Language:** rules match the words the notification itself uses (Indonesian or English). Do not translate.
- **Rp amount format:** "." is the thousands separator ("Rp 25.000" is 25,000). A "," followed by exactly two digits at the end is a decimal part ("Rp 25.000,00" is 25,000); a decimal part other than ",00" is dropped by rounding to whole rupiah (builder may choose the rounding rule; it must not silently turn 25.000 into 25). "IDR 25,000.00" (English style) must also read as 25,000.
- **Duplicate check (builder's call, settled):** two payments in different currencies are never duplicates. The amount-window queries filter by currency. The dedup key includes the currency only for IDR, so every stored RM key stays valid and no migration rewrites keys. In RM the current rules apply unchanged. **In Rp (owner's decision):** the same app, the same amount and a different merchant are two payments, in both the dedup key and the amount window; the same merchant within the window is still one payment. Owner accepts the risk that one payment whose two notifications name the merchant differently becomes two cards.
- **Top-ups:** a transfer from the owner's bank to the owner's own wallet is not spending. The bank-side notification (myBCA "to OVO", Maybank "to TNG"/reload) makes no card. It appears in the notification log as "Top-up", where the existing "Add as payment" button can still save it. The wallet's own "top-up received" notice also makes no card where its wording is known (TNG). For OVO the wording is unknown, so this wallet-side rule waits for real samples, like the strict payment rules; until then an OVO top-up notice can make an "Unknown format" card, which the owner swipes away. The wallet's later payment counts as normal. The top-up rule applies only to new notifications: existing RM rows do not change. Detection is by wording and wallet name; the builder writes the rules from the existing Maybank/TNG samples and must not drop a real payment to a merchant whose name only contains "OVO" or "TNG".
- **Gemini pre-fill:** must accept Rp amounts and return IDR as the currency; it never changes the account a card was given.

## Display and input

- **One rounding rule:** Rp amounts round to whole rupiah with the same rule everywhere (parser, add page, Gemini, receipts, split shares).
- **Rp format:** "Rp 25.000": no decimals, "." between thousands, a space after "Rp". RM stays "RM 1,234.50".
- **Add/edit payment page:** opens on the active account. A small RM/Rp switch on the page changes the account of this one payment. In Rp the number pad has no decimal key, and the amount is whole rupiah. Editing an existing payment shows its own account.
- **Every hard-coded "RM"** in the UI (the fact list below) must use the payment's or the active account's currency.

## Split billing and People in Rp

- Splits, debts, owed items and repayments in the Rp account work the same as in RM, in whole rupiah. Shares that do not divide evenly round to whole rupiah with the existing "last person takes the remainder" style (builder: keep whatever SplitMath does now, at 0 decimals).
- A repayment links only to a payment in the same account.

## Receipt scanning in Rp

- The Rp split flow keeps "Take photo", "Choose from gallery" and "Type items instead". A receipt photographed in the Rp account is read with an **Indonesian rule set**, not the Malaysian one.
- Indonesian receipts write amounts as "25.000" or "25,000" (no cents), and their charges differ from Malaysia: service charge (often 5–10%), PB1 restaurant tax (10%), PPN/VAT (11–12%), and rounding. The check against the printed total stays the core idea: when items plus charges equal the printed total, the read is accepted; otherwise the existing mismatch warning shows.
- **Test set:** the public CORD dataset (Naver Clova, about 1,000 Indonesian restaurant and shop receipts, with labeled totals). Run ML Kit on the owner's phone over the images, as done with SROIE, and keep the OCR output git-ignored next to `receipt-bench/`. Do not commit the third-party images or OCR output.
- **Gate (owner's decision):** wrong-and-not-flagged must be 0 on the CORD benchmark, and accepted-correct must be at least 50% on CORD restaurant receipts. If scanning misses this gate, the release splits: the Rp account ships without Rp scanning (Rp splits use "Type items instead" and "Take photo" is hidden in Rp), and Rp scanning ships later when it passes.
- A final check with the owner's own receipts happens on the next trip; it is not a release blocker.

## Constraints

- Kotlin, Compose M3, Hilt, Room. The database changes (version 10 to 11 or later). Migration must keep every existing row and put it in the RM account. Back up the phone database before installing the build, as with every DB change.
- BigDecimal money everywhere; Rp at scale 0, RM at scale 2.
- No new network use. ML Kit stays on-device.
- No real or personal data in the repo, tests or docs. Test notification texts are made up or anonymized.
- JVM tests only (no instrumented tests). The CORD benchmark test skips when the data folder is absent, like the SROIE one.

## Facts the builder needs (code survey, 2026-11-02)

- Currency columns exist on `expenses`, `pending_payments` and `split_bills`. They do not exist on `split_items`, `split_debts`, `owed_items`, `split_people`, `categories` or `merchant_category_map`. Values written today are hard-coded "MYR" (manual payment, owed bill, split draft) or come from the parsers ("MYR").
- No total groups or filters by currency: `ExpenseDao` week/month/day/category/monthly totals, `PeopleMath`, `SplitRepository`, `RepaymentMatcher`, `SplitMath` (scale 2).
- `AmountFormatter` is the partly central formatter (scale 2, Locale.US "#,##0.00"); "RM" is hard-coded outside it in about 15 places (PeopleMath, SpendingPeriodSection, PaymentScreen, PersonScreen, SplitEditorScreen, SplitEditorSteps, SplitEditorViewModel, NotificationDebugViewModel, the listener).
- `NotificationParser` and `PaymentRules` match only RM/MYR and strip "," as thousands; `DedupKeyGenerator` has no currency. `AmountInput` caps the fraction at 2 digits. `ReceiptRules` requires ".dd" amounts.
- `SettingsRepository` (DataStore) holds a flat allowlist; it has no per-account or currency setting yet.

## Left to the builder

- The schema shape (an account column on each money table, or another layout), the migration, and how the active account flows through repositories and view models.
- How Home shows the active account; the exact Settings control.
- The exact top-up wording rules, from existing samples.
- The Indonesian receipt rule details and the readings for calculated charges, from the CORD data.
- Build order. Suggested: accounts and migration first, then capture and display, then splits/People, then Rp receipt scanning (about half the work).

## Owner's decisions (from the interview)

| Topic | Decision |
|---|---|
| Model | Two separate accounts, switch the view; no conversion |
| Check payments | Cards from both accounts |
| Account of a notification | Currency in the text decides |
| No currency in the text | "Pick account" tag on the card |
| Categories | Separate lists; Rp starts as a copy of RM |
| People and splits | Separate per account; separate contact lists |
| Switch | In Settings; app opens on the last account used |
| Add page | Active account, with an RM/Rp switch |
| Rp format | "Rp 25.000", no decimals |
| Rp receipt scanning | In version 1 if it passes the gate (0 silent wrong, at least 50% of CORD restaurant receipts); otherwise a later release |
| Top-ups | Not spending, in both accounts |
| Unknown OVO/myBCA texts | Catch-all reader + "Unknown format"; strict rules later |
| BCA mobile | Not watched; myBCA only |
| Same app, same amount in Rp | Different merchant = two payments |
| Receipt test data | CORD, same zero-silent-wrong rule |
