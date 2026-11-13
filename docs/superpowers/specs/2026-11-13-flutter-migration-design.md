# Move Koban to Flutter for Android and iPhone

Date: 13 November 2026. Status: design, waiting for the owner's approval.
Related issues: #20 (map), #23 (framework), #24 (iPhone without payment notifications), #21 and #22 (earlier research).

## 1. Intent

Koban runs only on Android today. Some of the owner's friends use iPhones. The owner wants one codebase that runs on Android and iPhone, and chose Flutter.

Success: every Android friend gets the Flutter version as a normal update and keeps all data, and 1 or 2 technical iPhone friends can test a real iPhone build, installed free by sideloading, and record payments with little typing.

## 2. Goals, non-goals, anti-goals

Goals:
1. Rebuild the whole app in Flutter, with the same features and the same look as Koban 0.1.1 on Android.
2. Ship the Flutter app on Android as an update over today's app: same app ID, same signing key, all data kept.
3. Give 1 or 2 iPhone friends a test build by sideloading (AltStore or SideStore, free Apple ID), with manual entry, receipt reading, groups, bill splits, and iPhone Shortcuts that send Apple Pay and bank SMS payments to Koban.

Non-goals:
- No new features during the move. Personal budgets (#33) and the rupiah account come after the switch.
- No App Store, TestFlight or Play Store. Android stays on GitHub Releases. The iPhone test build is an unsigned `.ipa` on GitHub Releases. The paid Apple membership (USD 99 a year) and TestFlight are a later decision, only if iPhone use grows.
- No change to the Supabase backend.

Anti-goals (a failure even if the app works):
- A friend loses payments, people, splits, categories, the invite link (device token) or the group sign-in after the update.
- A friend must uninstall and install again, or enter the invite code again.
- Payment capture on Android gets less reliable than in 0.1.1 (missed notifications, or capture only while the app is open).

## 3. Today's app (what must move)

- Kotlin, Jetpack Compose (Material 3), Room, Hilt, DataStore. About 16,200 lines: screens 10,200, data 2,800, listener 1,200, parser 1,000, groups 450, updater 300. 192 unit tests in 25 files.
- Screens (15 files): Home, Activity, People, Person, Groups, Payment (add and edit, opens as a sheet), Check payments (swipe to save or skip), Split editor (steps), Settings, Payment apps picker, Onboarding, Notification log (debug).
- Database `expense_tracker.db`, Room version 11, 11 tables: `expenses`, `categories`, `merchant_category_map`, `pending_payments`, `dropped_notifications`, `split_bills`, `split_items`, `split_people`, `split_item_shares`, `split_debts`, `owed_items`.
- Settings: 8 keys in 2 Preferences DataStore files (plain, not encrypted). File `settings`: `payment_app_allowlist` (the chosen payment apps; the listener needs it), `payment_apps_chosen`, `onboarding_done`, `dark_mode`, `online_features`, `last_update_check`. File `secrets`: `device_token`, `group_session` (JSON with the Supabase access token, refresh token and user ID). Source: `data/SettingsRepository.kt`.
- Android-only parts: a NotificationListenerService with keep-alive service, watchdog, reconnect scheduler and boot receiver; OEM battery helper; ML Kit document scanner and text recognition; the self-updater (GitHub Releases, `koban-<versionCode>.apk`, package installer).
- Pure rule code with no Android dependency: `NotificationParser`, `PaymentRules`, `ReceiptRules`, `MerchantNormalizer`, `DedupKeyGenerator`, `AmountFormatter`, `SplitMath`, `PeopleMath`, `RepaymentMatcher`.
- The online receipt read goes app → Edge Function `read-receipt` → the owner's receipt server (`server/receipt-service`, Python, runs Claude). The server does not change in this move.
- Online parts: Supabase (Google sign-in with an ID token, RPCs, row-level security), Edge Functions `register`, `read-receipt`, `delete-account`. Design rules: `docs/DESIGN.md`. Release steps: `docs/RELEASING.md`.

## 4. Constraints

- Android app ID `io.github.skooyo.koban`, release key `~/.koban/koban-release.jks`, `versionCode` continues from 2. These never change (`docs/RELEASING.md`, section 1).
- The backend must keep working for 0.1.x apps while friends update (`docs/RELEASING.md`, section 6).
- The owner has no Mac and no iPhone. iPhone builds run on a cloud Mac, and iPhone testing is done by friends.
- Apple: no paid membership. Friends sideload with a free Apple ID: the app stops opening after 7 days unless the helper app (AltStore or SideStore) signs it again; a free Apple ID has at most 3 active sideloaded apps and 10 new app IDs a week; SideStore needs iOS 17.4 or later. Some capabilities are not available to free Apple IDs (for example Sign in with Apple), so the iPhone build uses only what a free Apple ID can sign. Sign in with Apple is required only for App Store apps (Guideline 4.8), so Google sign-in is enough here. Apple does not let apps read other apps' notifications.
- Android: Play Protect blocks file installs of apps with notification access in Malaysia, so first installs go by USB (`docs/RELEASING.md`, section 7). Updates use the in-app updater.
- The repository is public. No keys or server secrets in git.
- Docs and app text in ASD-STE100 Simplified Technical English.

## 5. Approaches

1. **New Flutter app, one switch (chosen by the owner).** Build the app again in Flutter. When it does everything 0.1.1 does on Android, ship it as one update that imports the old data once. The Kotlin app gets only bug fixes until then. Cost: no visible progress for friends during the build (the earlier research estimated 8 to 12 weeks of work). Benefit: one clean change, one data import, and the same app then builds for iPhone.
2. **Screen by screen inside today's app (Flutter add-to-app).** Rejected: Kotlin and Flutter would write the same database for months (high data-loss risk), the APK grows by about 10 MB, and iPhone still needs approach 1 at the end.
3. **Kotlin Multiplatform with Compose Multiplatform.** Reuses about 80% of the code (research in #22), but the owner chose Flutter.

## 6. Design

### 6.1 Repository

- The Flutter project lives in `koban/` at the repository root. The Kotlin app stays in `app/` until the switch release, and is deleted after it.
- Releases keep the same tag and asset rules. The Flutter Android build signs with the same key file and passwords from `~/.koban/`.

### 6.2 Code structure

- **Rules (pure Dart).** Port the pure rule code from section 3 one to one, and port the test cases of all 192 unit tests that test it, with the same inputs and expected values. These ports come first and must pass before any screen work.
- **Data.** SQLite through Drift (the builder may pick another SQLite library if it fits better). The schema has the same 11 tables, columns and meanings as Room version 11, so the import is a copy, not a conversion.
- **Screens.** Material 3 with the Koban tokens and components from `docs/DESIGN.md` (colors, type, spacing, radius, motion). The screen transitions follow 0.1.1: a full-width slide with the screen below moving 30% and darkening; instant tab switches; the payment page rises as a sheet.
- **Online.** `supabase_flutter` against the same project, functions and RPCs.

### 6.3 Android payment capture

- The notification listener and its helpers (keep-alive service, watchdog, reconnect scheduler, boot receiver, battery helper) stay native Kotlin inside the Flutter Android project.
- The Flutter Android build uses `applicationId` `io.github.skooyo.koban` and keeps the Kotlin package `com.expensetracker.app` for these classes. The class names must not change: Android stores the notification access permission by the full component name (`com.expensetracker.app.listener.ExpenseNotificationListener`). A new name means every friend must turn on notification access again. The same holds for `BootCompletedReceiver`, `ListenerWatchdogReceiver`, `ListenerKeepAliveService` and `UpdateInstallReceiver`.
- The parsing rules exist only once, in Dart. Capture must work when the app is closed, as in 0.1.1. The listener hands each notification from a chosen payment app to Dart code that runs without the screen (a background Dart entry point), and that code parses and saves it. The builder picks the mechanism, but these must hold:
  1. no notification from a chosen app is lost when the app is closed or the phone restarts;
  2. the same notification is never saved twice (`dedupKey`, as today);
  3. sure payments save at once and unsure ones go to "Check payments", as today.

### 6.4 Data import (Android, first start of the Flutter version)

1. If `databases/expense_tracker.db` exists and the import is not marked done, open it read-only and copy all 11 tables into the new database in one transaction.
2. Copy all 8 settings. A native Kotlin step reads both DataStore files with the DataStore library and passes the values to Dart, because Dart has no reader for that file format. `payment_app_allowlist` must carry over, or capture stops after the update. The friend does not enter the invite code again.
3. Group sign-in: give the old refresh token from `group_session` to `supabase_flutter` (restore the session from the refresh token). If Supabase refuses it, the friend signs in with Google once more. The invite link and all data stay. (Designer's call.)
4. Check that the row count of each table matches. If a count does not match, roll back, keep the old file, show "Koban could not move your data. Your data is safe. Update again later." and report the table names in the notification log.
5. On success, mark the import done and rename the old file to `expense_tracker.db.pre-flutter`. Do not delete it in this release. A later release deletes it.
6. Test the import on a copy of a real 0.1.1 database (the owner's, 466 payments) before any friend gets the update.

Going back: Android cannot install a lower `versionCode` over a higher one. If the Flutter version has a bug, fix forward with a new release (`docs/RELEASING.md`, section 5). Because the old file stays as `expense_tracker.db.pre-flutter`, a fix release can import it again if needed. (Designer's call.)

### 6.5 iPhone (sideload test)

- **Who:** 1 or 2 technical iPhone friends who agree to the setup and the weekly refresh. At least 1 must agree before the iPhone work starts.
- **Payment capture:** manual entry, receipt scan, and two ready-made Shortcuts automations:
  1. a Wallet transaction automation, which runs when an Apple Pay card is used;
  2. a Message automation, which runs when an SMS from a chosen bank arrives.
  Each automation passes the amount, the shop and the source to Koban through an App Intent (native Swift), without opening Koban. Koban adds the payment to "Check payments". Onboarding on iPhone shows the Shortcuts links and a 3-step guide. E-wallet payments (for example Touch 'n Go) do not start a Shortcut, and the app says so in plain words. Check early (in the first iPhone spike) that a free-Apple-ID build can register the App Intent; if it cannot, fall back to a `koban://add?...` link that opens Koban with the payment filled in.
- **Receipts:** VisionKit document camera and Vision text recognition (the Flutter plugin may wrap these). The online receipt read uses the same `read-receipt` function.
- **Sign-in:** Google sign-in only.
- **Hidden on iPhone:** the payment apps picker, the notification log, the battery and listener settings, and "Check for updates".
- **Build:** a GitHub Actions workflow on a macOS runner (free for this public repository) builds an unsigned `.ipa` (`flutter build ios --no-codesign`, packed as `Payload/Runner.app`) and attaches it to the GitHub release as `koban-<versionCode>.ipa`. No Apple keys are needed.
- **Install guide:** `docs/IPHONE-SIDELOAD.md`, in STE: install AltStore (AltServer on Windows or Mac) or SideStore (pairing file made once on a computer), add the `.ipa`, refresh every 7 days, use a spare Apple ID if possible, and a missed refresh does not delete data.
- **Updates:** the friend installs each new `.ipa` through the helper app. Koban shows no update check on iPhone.
- **Exit to paid:** if more than 2 iPhone friends want Koban, the owner decides on the paid membership and TestFlight. That is a separate spec.

### 6.6 Updates

- Android: port the updater to Dart. The install step (package installer, "Install unknown apps" permission) stays native if no plugin does it well. The rules stay the same: GitHub latest release, asset `koban-<versionCode>.apk`, versionCode check, obeys "Online features".
- iPhone: new `.ipa` builds go through the helper app (section 6.5). Koban shows no update check.

### 6.7 Order of the work

Each milestone ends with tests that pass and a short note in the map issue (#20).

1. Flutter project, tokens and components, rules ported with all test cases.
2. Database (11 tables) and the import, tested on a copy of a real 0.1.1 database.
3. Android capture: listener, background parsing, keep-alive, boot.
4. All screens to parity with 0.1.1, including transitions and dark mode.
5. Online parts: invite, Google sign-in, groups, receipt reading, delete account, updater.
6. Android switch release: the owner uses it for 1 week on a phone with real data, then it ships to friends as the next minor version.
7. iPhone sideload test: cloud build of the unsigned `.ipa`, App Intent and Shortcuts, iPhone receipt scan, install guide, then the first iPhone friend installs and uses it for 2 weeks.

## 7. Owner decisions so far

- Flutter, not Kotlin Multiplatform.
- iPhone records payments by manual entry, receipts and Shortcuts automations.
- The owner has no Mac and no iPhone: Android first, iPhone last, cloud Mac builds, friends test on iPhone.
- No paid Apple account for now: the iPhone version is a sideload test for 1 or 2 technical friends (AltStore or SideStore). TestFlight is a later decision.
- Approach 1: new app, one switch.

## 8. Left to the builder

- The Flutter state management and dependency injection libraries.
- The exact plugins for SQLite, ML Kit, VisionKit and Supabase.
- The mechanism for background Dart parsing on Android, within the rules in section 6.3.
- The Android CI and the macOS CI setup details.
