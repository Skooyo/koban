# Flutter milestone 6: the switch release (plan)

**Goal:** friends with Koban 0.1.1 (Kotlin) update to the Flutter version through the normal update, and keep every payment, setting and sign-in.

**Spec:** `docs/superpowers/specs/2026-11-13-flutter-migration-design.md`, sections 6.4 (import), 6.6 (updates), 6.7 step 6 (owner uses it 1 week, then friends). **Runbook:** `docs/RELEASING.md`. **Open items:** `.superpowers/sdd/carry-over.md` ("Before milestone 6", "Milestone 6 inputs", "Owner hands-on list").

## Rules that bind this milestone

- App ID stays `io.github.skooyo.koban`. The release APK uses the release key `~/.koban/koban-release.jks` (never the debug key) and a `versionCode` above 2.
- No `--split-per-abi` (it changes `versionCode` and breaks the `koban-<versionCode>.apk` updater rule).
- The import never deletes the 0.1.1 database: it renames it to `expense_tracker.db.pre-flutter`.
- Android cannot go back to 0.1.1 after the switch. A bad release is fixed forward. So the owner's data is backed up before the switch.
- Never print or commit a password, a key or `~/.koban` content.

## Phase A: make the release build (code; an agent, about 5 hours)

1. **Release signing.** `koban/android/app/build.gradle.kts` reads `~/.koban/release-signing.properties`, the same as 0.1.1. If the file is missing, the release build fails with a clear message (it never falls back to the debug key).
2. **Version.** `pubspec.yaml` `version: 0.2.0+3` (versionName 0.2.0, versionCode 3). Settings "App version" shows 0.2.0.
3. **Release build checks** (carry-over list): `flutter build apk --release` builds; fix R8 "Missing class" for the ML Kit options with `-dontwarn` if needed; the `sqlite3_flutter_libs` stub packages run; record the APK size (0.1.1: about 65 MB); `apksigner` SHA-1 equals the release line in `~/.koban/oauth-sha1.txt`; the APK is not debuggable.
4. **Import safety (must before real data):**
   - Retry the settings import after `ImportDone.settingsError`, so the payment-app list is not lost (capture would stop).
   - After a successful import, delete the 0.1.1 `datastore/secrets.preferences_pb` (it keeps the device token).
   - If app start fails, show a one-line error page instead of a frozen splash.
   - The import error log writes the error type only (no paths or data).
5. **Robustness carry-overs:** view-model streams get `onError` (a failed first load shows the error text, not an empty screen); Home `refresh()` catches the platform error; the "RM 0 in Change amounts" case (owner decision D3).
6. **Runbook:** update `docs/RELEASING.md` for Flutter (commands from `koban/`, `flutter build apk --release`, APK path, the checks in step 3).
7. Tests for each change; `flutter analyze` clean; full suite; Kotlin unit tests (`:app:testDebugUnitTest`).

## Phase B: device proofs with test data (owner, about 1.5 hours)

These use the debug apps only (`io.github.skooyo.koban.debug`), so no real data is at risk. They were never done.

1. **Update path (M3, 5 steps):** install a 0.1.1 debug build, add test data, update to the Flutter debug build; notification access stays on; a real payment is captured while Koban is closed; it survives a phone restart; logcat shows no errors.
2. **Screens (M4, 6 checks)** from `docs/superpowers/plans/2026-11-14-flutter-m4c-people-splits.md`.
3. **Online (M5, 7 checks)** from `docs/superpowers/plans/2026-11-14-flutter-m5c-updater.md`: Google sign-in, session restored from 0.1.1, a real receipt read, the update download.

## Phase C: the switch on the owner's phone (real data; owner, about 1 hour, then 1 week)

1. **Back up first.** Note today's reference numbers: Home this month, Activity payment count, People balances, Settings (payment apps, invite code, dark mode). Make a local backup of Koban with the phone's own backup (Settings › About phone › Back up and restore). Check that the backup lists Koban with its data. A dry run with `adb backup` shows whether it contains data; on Android 12+ it is expected to be empty for 0.1.1.
2. **Install the release APK over 0.1.1** by USB (`adb install -r koban-3.apk`). Same key and a higher versionCode, so Android keeps the data and starts the import.
3. **Check the import** against the reference numbers: 466 payments, the same totals, the same categories, the payment-app list, the invite code, dark mode, notification access still on, group sign-in restored (or one Google sign-in, as the spec allows), the update check.
4. **If a count does not match,** the import rolls back and keeps the old file; Koban shows "Koban could not move your data. Your data is safe." Stop, read the notification log, fix forward with a new versionCode.
5. **Use it for 1 week** (spec 6.7 step 6): capture, Check payments, splits, groups. Fix what breaks with patch releases (0.2.1, versionCode 4, ...).

## Phase D: release to friends (owner and agent, about 30 minutes)

1. Tag `v0.2.0`, create the GitHub release as a draft with `koban-3.apk` and STE notes (the update dialog shows the first 500 characters).
2. Publish. 0.1.1 checks once a day and offers the update. This is the first real proof that the 0.1.1 updater installs the Flutter APK, so roll out to 1 friend first (owner decision D4), check that friend's import, then tell the others.
3. Keep `expense_tracker.db.pre-flutter` in this release; a later release deletes it.

## Owner decisions (made 2026-11-16)

- **D1 Version:** 0.2.0 (versionCode 3).
- **D2 Backup:** the phone's own local backup of Koban plus the reference numbers, before the switch.
- **D3 RM 0 in Change amounts:** the person leaves the split (keep today's behavior; no code change, add a test that pins it).
- **D4 Rollout:** 1 friend first, check their import, then the others.

## Order and time

Phase A (about 5 hours, agent) and Phase B (about 1.5 hours, owner) can run in parallel. Phase C needs A done and B passed. Phase D comes after the 1 week in Phase C.
