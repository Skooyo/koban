# App Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every existing Koban screen look like its artboard in the "Koban screens redesign" canvas, with the words and rules of `docs/DESIGN.md`.

**Architecture:** First, one task aligns the theme with the design tokens and adds a small set of shared Compose parts (list group, row, section heading, money text, top bar). Then one task per screen area rebuilds the screen layouts with those parts. ViewModels, repositories, navigation routes and data stay as they are; this is a UI and words change.

**Tech Stack:** Kotlin, Jetpack Compose Material 3, Hilt, Room. No new dependencies.

**Spec:** `docs/DESIGN.md` (rules, tokens, words, checklist) and the canvas artboards. The artboards are rendered as PNG files in the plan workspace: `.superpowers/sdd/2026-11-13-app-redesign/boards/<Name>.png` (390 px wide, 1 px = 1 dp). The canvas itself: https://claude.ai/artifact/W2zD25fDueRejkhK8bGVoJ (owner only).

## Global Constraints

- Change UI and words only. Keep every existing feature, button action, ViewModel function, route and stored value. If the current screen has a feature the board does not show, keep it and give it the board's style.
- Do not build a feature that needs new data, new storage, a new network call or a new ViewModel state source. If a board shows such a thing, leave it out and list it under "Left out" in your report. Building it from data the ViewModel already exposes is allowed.
- Colors only from `MaterialTheme.colorScheme` and `LocalMoneyColors`. No `Color(0x...)` literals in screen files.
- One gold (primary) filled action per screen. Second actions use the tonal style: `primaryContainer` fill with `onPrimaryContainer` text.
- Lists sit in one group: `surfaceContainer` fill, 16 dp corners, `outlineVariant` 1 dp dividers between rows. Do not put each row in its own card.
- Every tap target is 48 dp or more. A list row is 56 dp tall or more.
- Money text: `RM 12.50` (space after RM, two decimals), tabular figures (`fontFeatureSettings = "tnum"`). Received money: `+ RM 12.50` in `LocalMoneyColors.current.received`. Spent money uses the normal text color, never red.
- Words: use the Words table in `docs/DESIGN.md` (payment, Spent / Received, Shop, Check payments, Not a payment, Save payment, split). Sentence case. Buttons are a verb and an object.
- Icons: `Icons.Default` filled; `Icons.AutoMirrored.Filled` for back and list icons. No emoji.
- Mon (the coin) only on empty screens, finished screens, the tracking-off status and first start. At most one Mon on a screen. Use `ui/components/Mon.kt`.
- Every `Icon` and `IconButton` that has no visible text label gets a `contentDescription`.
- The 192 existing unit tests must pass: `./gradlew testDebugUnitTest`. The build must pass: `./gradlew assembleDebug`.
- Gradle needs JDK 17: `export JAVA_HOME="C:/Users/daven/AppData/Local/Temp/claude/53d8fdfabfa70e96/2e7b5920-daa2-4156-a4f8-ab5ee5ffc7b4/scratchpad/jdk/jdk-17.0.21+9"`.
- Source root: `app/src/main/java/com/expensetracker/app/`. Paths below are relative to it.

## Review Focus

1. Light theme: every screen must stay readable in light mode (the phone setting). Tokens give both values; no screen may hard-code a dark color.
2. Large font scale (1.3x): long shop names and amounts must not overlap; rows grow, amounts stay on one line.
3. Empty data: every list screen must still show its empty state (no payments, no people, no groups).
4. Lost actions: a redesign that drops a button that exists today (for example a delete, a long-press option, a debug entry) is a defect.
5. Back and Discard: screens with typed data must still ask "Discard changes?" before they close.

---

### Task 1: Theme tokens and shared parts

**Files:**
- Modify: `ui/theme/Theme.kt`
- Create: `ui/components/Kit.kt`
- Modify: `ui/ExpenseTrackerNavHost.kt` (bottom bar only)

**Interfaces:**
- Produces, in `ui/components/Kit.kt`:
  - `@Composable fun ListGroup(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit)` — `surfaceContainer` fill, 16 dp corners, draws an `outlineVariant` divider between children (use a `ListGroupScope` or a `Divider` helper; your choice).
  - `@Composable fun KobanRow(title: String, modifier: Modifier = Modifier, subtitle: String? = null, subtitleColor: Color = Color.Unspecified, leading: (@Composable () -> Unit)? = null, trailing: (@Composable () -> Unit)? = null, showChevron: Boolean = false, onClick: (() -> Unit)? = null, minHeight: Dp = 56.dp)`
  - `@Composable fun SectionHeading(text: String, modifier: Modifier = Modifier)` — `titleSmall`, `onSurfaceVariant`, 8 dp below.
  - `@Composable fun MoneyText(text: String, modifier: Modifier = Modifier, style: TextStyle = MaterialTheme.typography.titleMedium, color: Color = Color.Unspecified)` — applies `fontFeatureSettings = "tnum"`.
  - `@Composable fun CategoryDot(color: Color, size: Dp = 10.dp)`
  - `@Composable fun LargeTopBar(title: String, modifier: Modifier = Modifier, subtitle: String? = null, actions: @Composable RowScope.() -> Unit = {})` — the big left title of the top-level tabs (Home "Today", Activity, People, Groups), `headlineLarge`.
  - `@Composable fun TonalButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, icon: ImageVector? = null, enabled: Boolean = true)` — `primaryContainer` fill, `onPrimaryContainer` text, full radius.

- [ ] **Step 1: Align the color schemes with `docs/DESIGN.md` tokens.** Dark: `background` and `surface` = night `#141B2B`; `surfaceContainer` = surface `#1C2539`; `surfaceContainerHigh` = surface-2 `#243049`; `outlineVariant` = line `#2F3B57`; `onBackground`/`onSurface` = ink `#EDF0F7`; `onSurfaceVariant` = muted `#A2ACC2`; `error` = `#FF7B6B`; `primaryContainer` = gold-soft `#3A3420`. Light: `background`/`surface` = `#F6F7FA`; `surfaceContainer` = `#FFFFFF`; `surfaceContainerHigh` = `#EEF1F6`; `outlineVariant` = `#D9DEE8`; `onSurface` = `#161D2B`; `onSurfaceVariant` = `#5A6478`; `error` = `#C8372A`; `primaryContainer` = `#FBF1CF`; `onPrimaryContainer` = `#7A5D00`. Set the other `surfaceContainer*` steps between their neighbors. Check `MoneyColors.received` matches `#6FD3A0` dark / `#16804A` light and `review` `#F0B060` / `#A85A00`.
- [ ] **Step 2: Write `ui/components/Kit.kt`** with the interfaces above. Match the row on `boards/People.png` and `boards/Settings.png`: 16 dp side padding, title `titleMedium`, subtitle `bodyMedium` in `onSurfaceVariant`, 24 dp leading icon in `onSurfaceVariant`, chevron in `onSurfaceVariant`.
- [ ] **Step 3: Bottom bar.** In `ExpenseTrackerNavHost.kt`, give `NavigationBar` `containerColor = surfaceContainer` and each `NavigationBarItem` `indicatorColor = primaryContainer` (gold-soft pill, `boards/Main.png`). Keep the People badge.
- [ ] **Step 4: Run** `./gradlew testDebugUnitTest assembleDebug`. Expected: BUILD SUCCESSFUL, 192 tests, 0 failures.
- [ ] **Step 5: Commit** `git commit -m "Align theme colors with the design tokens and add shared list parts"`

### Task 2: Home

**Files:** Modify `ui/screens/HomeScreen.kt`, `ui/components/ListenerStatusBanner.kt`, `ui/components/SpendingPeriodSection.kt` as needed.
**Boards:** `Main.png`, `HomeTrackingOff.png`, `UpdateDialog.png` (the Home behind it).
**Interfaces:** Consumes Task 1 parts.

- [ ] **Step 1:** Rebuild Home to `Main.png`: `LargeTopBar("Today", subtitle = date)` with the settings icon; a status line (green dot + "Tracking on" text) when tracking works; the "N payments to check" row when payments wait (uses the existing waiting count); the "Spent today" card with the big amount (`displayLarge`, one per screen), the received line, the category bar and the category rows; then one `ListGroup` with "This week" and "This month". The add button is an extended FAB "Add payment" with the add icon, bottom right.
- [ ] **Step 2:** Tracking off (`HomeTrackingOff.png`): replace the red banner with the card that has Mon (WORRY face), "Tracking is off", the reason, and a "Turn on" text button that does what the banner button does today. Keep every other status the banner shows today, in the same card style.
- [ ] **Step 3:** Keep the first-payment card (`after-7-home` look from PR #42) and the "Set up later" row; restyle them with the Task 1 parts.
- [ ] **Step 4:** Run `./gradlew testDebugUnitTest assembleDebug`. Expected: BUILD SUCCESSFUL, 0 failures.
- [ ] **Step 5:** Commit `"Redesign Home"`.

### Task 3: Check payments

**Files:** Modify `ui/screens/CheckPaymentsScreen.kt`, `ui/screens/CheckPaymentCard.kt`.
**Boards:** `CheckPayments.png`, `CheckEditSheet.png`, `CheckDone.png`.

- [ ] **Step 1:** Card to `CheckPayments.png`: source line (app initials avatar, app name, time), the amount `displayMedium`, Spent/Received segmented control, `ListGroup` of Shop / Category / Date rows with chevrons, the quoted notification text in a `surfaceContainerHigh` box, the hint line, and the two bottom buttons: outlined "Not a payment" with a close icon and filled "Save payment" with a check icon. The "1 of 3" counter in the top bar. Keep swipe right/left.
- [ ] **Step 2:** Field edit (`CheckEditSheet.png`): keep the current edit mechanism; style it as the "Change payment" sheet if it is already a sheet or dialog. Do not change how editing works.
- [ ] **Step 3:** All checked (`CheckDone.png`): Mon HAPPY, "All checked", the saved/not-a-payment count if the ViewModel has it, "Back to Home" filled button.
- [ ] **Step 4:** Run tests and build. Expected: 0 failures.
- [ ] **Step 5:** Commit `"Redesign Check payments"`.

### Task 4: Payment screen (add and edit)

**Files:** Modify `ui/screens/PaymentScreen.kt`, `ui/components/AmountInput.kt` (UI part only), `ui/components/DiscardChangesDialog.kt`, `ui/components/PastDatePickerDialog.kt` if needed.
**Boards:** `AddPayment.png`, `EditPayment.png`, `CategorySheet.png`, `DiscardChanges.png`.

- [ ] **Step 1:** Add payment to `AddPayment.png`: close X, Spent/Received segmented control at the top, the big amount with "Tap a number to change it", a `ListGroup` with Category / Date / Shop / Note rows (Note shows "Optional" in muted text when empty), the keypad in `surfaceContainerHigh` keys with 12 dp corners, and the full-width "Save payment" button. Keep the `AmountInput` logic functions unchanged.
- [ ] **Step 2:** Edit payment to `EditPayment.png`: title "Payment", red delete icon top right (existing delete), the amount with "Spent · date, time", the same row group, the "Count in group totals" toggle row only if the screen has that setting today, "Split this bill" tonal button only if the screen has a split entry today, "Save changes" button.
- [ ] **Step 3:** Category picker to `CategorySheet.png` (a modal bottom sheet with 24 dp top corners, dot + name rows, a gold check on the chosen one, "New category" text button if category creation exists here today). Discard dialog to `DiscardChanges.png` (title, body "Your changes are not saved.", "Keep editing" and red "Discard").
- [ ] **Step 4:** Run tests and build. Expected: 0 failures.
- [ ] **Step 5:** Commit `"Redesign the payment screen"`.

### Task 5: Activity

**Files:** Modify `ui/screens/ActivityScreen.kt`, `ui/components/ExpenseItem.kt`, `ui/components/PeriodSelector.kt`, `ui/components/CategoryCharts.kt`.
**Boards:** `Activity.png`, `FilterSheet.png`, `MonthSheet.png`, `ActivityUndo.png`.

- [ ] **Step 1:** `LargeTopBar("Activity")` with an outlined "Filter" button if a category filter exists today. Month/All segmented control if both views exist today. The month row with previous/next arrows. The chart card: donut + "Spent" + big amount + received line. The week chips row if weeks exist today. Payment rows grouped by day under `SectionHeading` ("Today", "Wed, 11 Nov"), each a `ListGroup` of rows: category dot, shop, "time · category", amount on the right. A payment that waits for a check shows a small "Check" badge in `review` color.
- [ ] **Step 2:** Filter and month pickers as bottom sheets (`FilterSheet.png`, `MonthSheet.png`) if those pickers exist today in any form; restyle, do not add new ones.
- [ ] **Step 3:** After a delete, keep the existing undo behavior; style the snackbar as `ActivityUndo.png`.
- [ ] **Step 4:** Run tests and build. Expected: 0 failures.
- [ ] **Step 5:** Commit `"Redesign Activity"`.

### Task 6: People and one person

**Files:** Modify `ui/screens/PeopleScreen.kt`, `ui/screens/PersonScreen.kt`, `ui/screens/PersonDialogs.kt`.
**Boards:** `People.png`, `Person.png`, `OwedItemDialog.png`, `SettleUpDialog.png`.

- [ ] **Step 1:** People to `People.png`: `LargeTopBar("People", subtitle = "Payment QRs, and what you owe each other")`, search field, "Split a bill" tonal button, sections "Owes you" / "You owe" / "Everyone else" as `ListGroup`s with initials avatars and colored subtitles (owes you = `received`), extended FAB "Add person".
- [ ] **Step 2:** Person to `Person.png`: QR in a gold-framed white box, "Save QR to gallery" tonal button with its hint, the balance card with "Settle up" filled button, the possible-repayment card if it exists today, "Aina owes you" list with "Mark paid", text buttons "Add what X owes me" / "Add what I owe". Keep the overflow menu actions.
- [ ] **Step 3:** Dialogs to `OwedItemDialog.png` and `SettleUpDialog.png`: 24 dp corners, fields in `surfaceContainerHigh`, text buttons bottom right.
- [ ] **Step 4:** Run tests and build. Expected: 0 failures.
- [ ] **Step 5:** Commit `"Redesign People"`.

### Task 7: Split a bill

**Files:** Modify `ui/screens/SplitEditorScreen.kt`, `ui/screens/SplitEditorSteps.kt`.
**Boards:** `SplitReceipt.png`, `SplitItems.png`, `SplitPeople.png`, `SplitAssign.png`, `SplitPayment.png`, `SplitSummary.png`.

- [ ] **Step 1:** A step header on every step: a segmented progress bar (gold done, `surfaceContainerHigh` to do) and "Step N of M · Name" in `labelLarge`, like the onboarding header in `OnboardingScreen.kt` (reuse it if it can be shared without a behavior change). Use the existing step count; do not add or remove steps.
- [ ] **Step 2:** Restyle each existing step to its board: receipt (Mon, "Start with the receipt", Take photo filled, Choose from gallery outlined, "Type items instead" text), items (place field, item rows with quantity, amount and delete icon, the mismatch warning card in `review` outline, charges group, totals), people (chips with check icons, new person field + tonal Add), who had what (one card per item with person chips; the error outline and "Pick at least one person" in `error`), payment (radio rows), summary (Mon HAPPY, per-person rows, total, "Share summary" tonal, "Edit items" text, red "Delete split" text). The bottom button says "Next" (or the existing label) full width.
- [ ] **Step 3:** Run tests and build. Expected: 0 failures.
- [ ] **Step 4:** Commit `"Redesign Split a bill"`.

### Task 8: Groups

**Files:** Modify `ui/screens/GroupsScreen.kt` (and any group detail file it uses).
**Boards:** `GroupsSignedOut.png`, `GroupsOnlineOff.png`, `Groups.png`, `Group.png`, `MakeGroupDialog.png`.

- [ ] **Step 1:** Each existing state to its board: signed out (explainer card with the two check/lock lines, "Sign in with Google" filled), online features off (Mon sleeping face if `MonFace` has one, else IDLE; "Turn on online features" filled), group list (`ListGroup` rows with initials, "1 request" badge, "Make a group" filled + "Join a group" outlined), one group (Week/Month segmented control, "You spent this week" card, join requests card with Decline/Approve, member rows with category bars, group code card with "Share code" tonal), make group dialog.
- [ ] **Step 2:** Run tests and build. Expected: 0 failures.
- [ ] **Step 3:** Commit `"Redesign Groups"`.

### Task 9: Settings, notification log, payment apps, update dialog

**Files:** Modify `ui/screens/SettingsScreen.kt`, `ui/screens/NotificationDebugScreen.kt`, `ui/screens/PaymentAppsScreen.kt`, `ui/components/UpdateDialog.kt`.
**Boards:** `Settings.png`, `NotificationLog.png`, `PaymentApps.png`, `UpdateDialog.png`.

- [ ] **Step 1:** Settings to `Settings.png`: sections with `SectionHeading` (Tracking, Appearance only if a theme setting exists today, Categories, Online, Background, About), each a `ListGroup` of `KobanRow`s with 24 dp leading icons. Categories: one row per category with its dot and "Built in" / "Your own", delete icon on own categories; "New category" field + tonal "Add". Keep every setting and button that exists today, including the invite code field and the debug entries.
- [ ] **Step 2:** Notification log to `NotificationLog.png`: status card, filter chips if filters exist today, one card per notification with an outlined status badge.
- [ ] **Step 3:** Payment apps to `PaymentApps.png`: hint text, search field if it exists today, `ListGroup` of app rows with initials avatar and checkbox, full-width "Save N apps" button (keep the existing label logic if it differs).
- [ ] **Step 4:** Update dialog to `UpdateDialog.png`.
- [ ] **Step 5:** Run tests and build. Expected: 0 failures.
- [ ] **Step 6:** Commit `"Redesign Settings and system screens"`.

### Task 10: Phone check, report and PR (controller)

- [ ] **Step 1:** Install the before app (`feature/groups` at 76e5e75) and the after app on the phone; capture the same screens in both, with no personal data.
- [ ] **Step 2:** Check light theme and font scale 1.3 on Home, Activity and Settings.
- [ ] **Step 3:** Push `feature/redesign`, open the PR against `feature/groups`, attach the pr-report. Do not merge.
