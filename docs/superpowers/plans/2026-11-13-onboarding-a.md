# Onboarding A and gold theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** New users get a 5-step setup (Welcome, notification access with "Android blocked this" help, payment apps, keep Koban running, ready), and the app switches its main color from blue to gold.

**Architecture:** One new route `onboarding` holds the whole flow; the step lives in an `OnboardingViewModel`, and the pure rules (who sees it, when the blocked help shows, the next step) live in `OnboardingRules` with unit tests. The payment apps step reuses `PaymentAppsScreen`. The auto-open logic in `ExpenseTrackerNavHost` opens onboarding before anything else. Mon, the mascot, is a set of vector drawables.

**Tech Stack:** Kotlin, Jetpack Compose Material 3, Hilt, DataStore Preferences, Room, JUnit 4.

**Spec:** `docs/DESIGN.md` (rules, tokens, words, Mon) and the "Onboarding idea A" row of the canvas https://claude.ai/artifact/W2zD25fDueRejkhK8bGVoJ (screens A1 to A7). The screen copy below is copied from that row.

## Global Constraints

- Words: "payment", "Shop", "Spent / Received", "Save payment". Sentence case. No "Oops", no apology.
- Money is written `RM 12.50`.
- One gold main action per screen. Red (`colorScheme.error`) only for errors and destructive buttons.
- Tap targets 48dp or more. Every icon-only button has a `contentDescription`. Mon is decoration (`contentDescription = null`) when text next to it says the same thing.
- minSdk 26, targetSdk 35. `POST_NOTIFICATIONS` is already in the manifest; it needs a runtime request on API 33+.
- No new dependency.
- Run checks with JDK 17: `./gradlew.bat testDebugUnitTest assembleDebug` from the repo root.
- Commits: one per task on branch `feature/onboarding`. No Claude attribution in commit messages.

## Review Focus

1. Existing users (the owner's phone: access on, apps chosen, payments in the database) must never see onboarding. Test: `shouldShow_existingUserWithAccess_isFalse` and `shouldShow_appsChosenBefore_isFalse` (Task 3).
2. A user who finished or left onboarding must not see it again on the next start, even with access turned off later. Test: `shouldShow_doneFlagSet_isFalse` (Task 3).
3. The blocked help must not show on Android 12 and lower, where the block does not exist, and not before the user went to Settings. Tests: `blockedHelp_android12_isFalse`, `blockedHelp_beforeSettings_isFalse` (Task 3).
4. Access granted while the blocked help is open: coming back must go to the payment apps step, not stay on the help. Test: `next_fromBlocked_withAccess_goesToApps` (Task 3).
5. Rotation or returning from Settings must not reset the step to Welcome: the step is saved in `SavedStateHandle` (Task 4, checked on the phone in Task 6).

---

### Task 1: Gold main color, green Entertainment, red Discard

**Files:**
- Modify: `app/src/main/java/com/expensetracker/app/ui/theme/Theme.kt` (MoneyColors, `categoryColor`, both color schemes)
- Modify: `app/src/main/java/com/expensetracker/app/ui/components/DiscardChangesDialog.kt`
- Modify: `docs/DESIGN.md` (section "Where this lives in the code")

**Interfaces:**
- Produces: `MoneyColors.green: Color`, used by `categoryColor("entertainment")`.

- [ ] **Step 1: Add `green` to `MoneyColors`.** Light `0xFF6E9A12`, dark `0xFFA8D45A`. Map `"entertainment" -> c.green` in `categoryColor`. Keep `gold` (other screens use it for accents).
- [ ] **Step 2: Dark scheme primary to gold.** `primary = 0xFFF2C94C`, `onPrimary = 0xFF2A2106`, `primaryContainer = 0xFF3A3420`, `onPrimaryContainer = 0xFFF2C94C`.
- [ ] **Step 3: Light scheme primary to dark gold.** Material uses `primary` for text buttons too, and `#F2C94C` text on white is 1.5:1. So: `primary = 0xFF7A5D00`, `onPrimary = 0xFFFFFFFF`, `primaryContainer = 0xFFF2C94C`, `onPrimaryContainer = 0xFF2A2106`.
- [ ] **Step 4: Discard in red.** In `DiscardChangesDialog`, give the "Discard" `TextButton` `ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)`.
- [ ] **Step 5: Update `docs/DESIGN.md`.** In "Where this lives in the code", replace the two "still differ" bullets with: "Done on 2026-11-13: primary is gold (dark) and `#7A5D00` with white text (light, because Material also uses primary for text buttons); Entertainment uses `MoneyColors.green`."
- [ ] **Step 6: Build and test.** Run `./gradlew.bat testDebugUnitTest assembleDebug`. Expected: BUILD SUCCESSFUL, 173 tests, 0 failures.
- [ ] **Step 7: Commit.** `git add` the 3 files; message `Make gold the main color and Entertainment green`.

### Task 2: Mon, the mascot

**Files:**
- Create: `app/src/main/res/drawable/mon_idle.xml`, `mon_worry.xml`, `mon_happy.xml`
- Create: `app/src/main/java/com/expensetracker/app/ui/components/Mon.kt`

**Interfaces:**
- Produces: `enum class MonFace { IDLE, WORRY, HAPPY }` and `@Composable fun Mon(face: MonFace, size: Dp, modifier: Modifier = Modifier, contentDescription: String? = null)`.

- [ ] **Step 1: Write the 3 vector drawables.** Viewport 100 × 110, width 100dp, height 110dp. Convert the `mon(face)` SVG in `docs/prototypes/app-redesign-mockups.html` (also in `docs/DESIGN.md`, section Mon) exactly: one `<group android:rotation="-12" android:pivotX="50" android:pivotY="58">` holding the coin edge ellipse (`#C99A22`, center 50,58, radii 34×46), the face ellipse (`#F2C94C`, center 50,56), the rim ellipse (stroke `#D9AE35`, 2, radii 28×39.5), the 5 hammer lines (stroke `#E3B93E`, 1.6, round caps), the shine ellipse (`#FFF3C4`, `fillAlpha 0.55`, its own group rotated -20 around 37,31), then the face strokes (`#2A2106`, 2.6, round caps and joins) for that face. Write each ellipse as two arcs: `M(cx-rx),cy a rx,ry 0 1,0 (2rx),0 a rx,ry 0 1,0 -(2rx),0`. Filled eye dots of `worry` are `fillColor` paths without stroke.
- [ ] **Step 2: Write `Mon`.** `Image(painterResource(...), contentDescription, Modifier.size(width = size, height = size * 1.1f))`, the drawable picked by `face`.
- [ ] **Step 3: Build.** `./gradlew.bat assembleDebug`. Expected: BUILD SUCCESSFUL (aapt2 rejects a bad vector here).
- [ ] **Step 4: Commit.** Message `Add Mon, the mascot, as vector drawables`.

### Task 3: Onboarding rules and the done flag

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/ui/viewmodel/OnboardingRules.kt`
- Modify: `app/src/main/java/com/expensetracker/app/data/SettingsRepository.kt`
- Test: `app/src/test/java/com/expensetracker/app/ui/viewmodel/OnboardingRulesTest.kt`

**Interfaces:**
- Produces:
  - `enum class OnboardingStep { WELCOME, ACCESS, BLOCKED, APPS, RUNNING, READY }`
  - `object OnboardingRules` with:
    - `fun shouldShow(done: Boolean, accessGranted: Boolean, paymentAppsChosen: Boolean): Boolean` = `!done && !accessGranted && !paymentAppsChosen`
    - `fun blockedHelp(sdkInt: Int, openedSettings: Boolean, accessGranted: Boolean): Boolean` = `sdkInt >= 33 && openedSettings && !accessGranted`
    - `fun afterSettings(step: OnboardingStep, sdkInt: Int, accessGranted: Boolean): OnboardingStep`: from ACCESS or BLOCKED, `APPS` when access is granted, `BLOCKED` when `blockedHelp(sdkInt, true, false)`, else unchanged.
    - `fun stepNumber(step: OnboardingStep): Int?`: ACCESS and BLOCKED 1, APPS 2, RUNNING 3, READY 4, WELCOME null.
  - `SettingsRepository.onboardingDone: Flow<Boolean>` (key `onboarding_done`, default `false`) and `suspend fun setOnboardingDone()`.

- [ ] **Step 1: Write the failing tests** in `OnboardingRulesTest`:

```kotlin
@Test fun shouldShow_newUser_isTrue() = assertTrue(OnboardingRules.shouldShow(done = false, accessGranted = false, paymentAppsChosen = false))
@Test fun shouldShow_existingUserWithAccess_isFalse() = assertFalse(OnboardingRules.shouldShow(false, accessGranted = true, paymentAppsChosen = true))
@Test fun shouldShow_appsChosenBefore_isFalse() = assertFalse(OnboardingRules.shouldShow(false, accessGranted = false, paymentAppsChosen = true))
@Test fun shouldShow_doneFlagSet_isFalse() = assertFalse(OnboardingRules.shouldShow(done = true, accessGranted = false, paymentAppsChosen = false))
@Test fun blockedHelp_android13_afterSettings_isTrue() = assertTrue(OnboardingRules.blockedHelp(33, openedSettings = true, accessGranted = false))
@Test fun blockedHelp_android12_isFalse() = assertFalse(OnboardingRules.blockedHelp(32, openedSettings = true, accessGranted = false))
@Test fun blockedHelp_beforeSettings_isFalse() = assertFalse(OnboardingRules.blockedHelp(35, openedSettings = false, accessGranted = false))
@Test fun next_fromAccess_withAccess_goesToApps() = assertEquals(OnboardingStep.APPS, OnboardingRules.afterSettings(OnboardingStep.ACCESS, 35, accessGranted = true))
@Test fun next_fromAccess_blockedOn14_goesToBlocked() = assertEquals(OnboardingStep.BLOCKED, OnboardingRules.afterSettings(OnboardingStep.ACCESS, 34, accessGranted = false))
@Test fun next_fromAccess_noAccessOn12_staysOnAccess() = assertEquals(OnboardingStep.ACCESS, OnboardingRules.afterSettings(OnboardingStep.ACCESS, 31, accessGranted = false))
@Test fun next_fromBlocked_withAccess_goesToApps() = assertEquals(OnboardingStep.APPS, OnboardingRules.afterSettings(OnboardingStep.BLOCKED, 34, accessGranted = true))
@Test fun next_fromRunning_isUnchanged() = assertEquals(OnboardingStep.RUNNING, OnboardingRules.afterSettings(OnboardingStep.RUNNING, 34, accessGranted = true))
@Test fun stepNumber_blockedSharesAccessStep() = assertEquals(1, OnboardingRules.stepNumber(OnboardingStep.BLOCKED))
@Test fun stepNumber_welcomeHasNone() = assertNull(OnboardingRules.stepNumber(OnboardingStep.WELCOME))
```

- [ ] **Step 2: Run them to see them fail.** `./gradlew.bat testDebugUnitTest --tests "*OnboardingRulesTest"`. Expected: compile failure, `OnboardingRules` unresolved.
- [ ] **Step 3: Implement `OnboardingRules` and `OnboardingStep`** with the signatures above.
- [ ] **Step 4: Add the done flag** to `SettingsRepository`, next to `paymentAppsChosen`, same pattern.
- [ ] **Step 5: Run the tests.** Same command. Expected: 14 tests pass. Then `./gradlew.bat testDebugUnitTest`: 187 tests, 0 failures.
- [ ] **Step 6: Commit.** Message `Add onboarding rules and the done flag`.

### Task 4: The onboarding flow

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/ui/viewmodel/OnboardingViewModel.kt`
- Create: `app/src/main/java/com/expensetracker/app/ui/screens/OnboardingScreen.kt`
- Modify: `app/src/main/java/com/expensetracker/app/ui/navigation/Routes.kt` (add `ONBOARDING = "onboarding"`)
- Modify: `app/src/main/java/com/expensetracker/app/ui/viewmodel/AppViewModel.kt` (add `suspend fun onboardingDue(): Boolean`)
- Modify: `app/src/main/java/com/expensetracker/app/ui/ExpenseTrackerNavHost.kt` (route and auto-open)

**Interfaces:**
- Consumes: `OnboardingRules`, `OnboardingStep`, `SettingsRepository.onboardingDone` / `setOnboardingDone()` / `paymentAppsChosen` (Task 3); `Mon`, `MonFace` (Task 2); `NotificationAccessHelper.isNotificationAccessGranted`, `openNotificationAccessSettings`, `isBatteryOptimizationIgnored`, `openBatteryOptimizationSettings`; `OemBatteryHelper.isXiaomiFamily`, `openManufacturerBackgroundSettings`; `PaymentAppsScreen(onClose)`.
- Produces: `@Composable fun OnboardingScreen(onFinished: () -> Unit, viewModel: OnboardingViewModel = hiltViewModel())`.

`OnboardingViewModel` (Hilt, `SavedStateHandle`): `val step: StateFlow<OnboardingStep>` saved under key `"step"`; `fun next()` (WELCOME→ACCESS, APPS→RUNNING, RUNNING→READY); `fun back()` (one step back; ACCESS and BLOCKED go to WELCOME; RUNNING to APPS); `fun openedSettings()` sets a saved `openedSettings = true`; `fun onResume()` applies `OnboardingRules.afterSettings(step, Build.VERSION.SDK_INT, accessGranted)` only when `openedSettings` is true; `fun finish()` calls `setOnboardingDone()`.

Screens, in order. Top of every step but Welcome: a 4-part progress bar (filled parts in `primary`, others in `surfaceContainerHighest`) and `Step N of 4 · <name>` in `bodySmall`, from `OnboardingRules.stepNumber`. The main button sits at the bottom, full width.

| Step | Content (exact copy) | Buttons |
|---|---|---|
| WELCOME | `Mon(IDLE, 140.dp)`; `displaySmall` "Koban counts your spending for you."; card with 3 rows (icon in `primary`): "Reads payment alerts from the apps you pick.", "You check each payment before it counts.", "Nothing leaves the phone. No account needed." | "Get started" → `next()` |
| ACCESS (step name "Notification access") | `headlineSmall` "Let Koban see payment alerts"; "When your bank or e-wallet sends a payment alert, Koban turns it into a payment for you to check."; rows "Koban reads only the apps you pick next." and "It ignores chats and all other alerts." | "Open settings" → `openedSettings()` then `openNotificationAccessSettings`; caption under it "In the list, tap Koban, then turn on Allow." |
| BLOCKED | `Mon(WORRY, 64.dp)` + `headlineSmall` "Android blocked this" + "Koban was installed from a file, so Android wants one more step."; numbered list: "1 Tap Open app info below", "2 Tap ⋮ at the top right — Then tap Allow restricted settings", "3 Come back and tap Try again"; caption "Android shows this item only after it blocks an app once." | "Open app info" → `Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))`; outlined "Try again" → `openedSettings()` then `openNotificationAccessSettings` |
| APPS | `PaymentAppsScreen(onClose = viewModel::next)` | its own "Save" |
| RUNNING (step name "Keep it running") | `headlineSmall` "Keep Koban running"; "Phones stop apps in the background to save battery. These settings keep tracking on."; rows, each with a check icon in `MoneyColors.received` when done, else a tonal button: **Alerts** "Tell me when tracking stops" → `rememberLauncherForActivityResult(RequestPermission())` for `POST_NOTIFICATIONS` (row shown only on API 33+); **Battery** "No restrictions" → `openBatteryOptimizationSettings` (done = `isBatteryOptimizationIgnored`); **Autostart** "Start Koban after a restart" → `openManufacturerBackgroundSettings` (row shown only when `isXiaomiFamily()`, never shown as done because Android cannot read it). Caption "Only the settings your phone needs show here." Row states refresh on `ON_RESUME`. | "Next" → `next()`; text button "Skip for now" → `next()` |
| READY | `Mon(HAPPY, 140.dp)`; `headlineMedium` "Koban is ready"; "Pay with a card or e-wallet. The payment shows up in Koban within a few seconds." | "Go to Home" → `finish()` then `onFinished()` |

- [ ] **Step 1: Write `OnboardingViewModel`** with the members above. `onResume()` must read access with `NotificationAccessHelper.isNotificationAccessGranted(context)`.
- [ ] **Step 2: Write `OnboardingScreen`** with the table above. Call `viewModel.onResume()` from `LifecycleEventEffect(Lifecycle.Event.ON_RESUME)`. `BackHandler`: on WELCOME call `finish()` then `onFinished()` (leaving the flow ends it for good; Home still shows the "Tracking is off" banner); else `back()`.
- [ ] **Step 3: Add the route.** `composable(Routes.ONBOARDING) { OnboardingScreen(onFinished = { navController.popBackStack(Routes.HOME, inclusive = false) }) }`.
- [ ] **Step 4: Auto-open first.** `AppViewModel.onboardingDue()` = `OnboardingRules.shouldShow(settingsRepository.onboardingDone.first(), NotificationAccessHelper.isNotificationAccessGranted(context), settingsRepository.paymentAppsChosen.first())`. In the auto-open `LaunchedEffect`, check it first: `if (route in topLevelRoutes && appViewModel.onboardingDue()) navigate(Routes.ONBOARDING) { launchSingleTop = true }`, then the existing payment-apps and check branches as `else if`.
- [ ] **Step 5: Build and test.** `./gradlew.bat testDebugUnitTest assembleDebug`. Expected: BUILD SUCCESSFUL, 187 tests, 0 failures.
- [ ] **Step 6: Commit.** Message `Add the onboarding flow for new users`.

### Task 5: Home, waiting for the first payment

**Files:**
- Modify: `app/src/main/java/com/expensetracker/app/data/ExpenseDao.kt`, `ExpenseRepository.kt`
- Modify: `app/src/main/java/com/expensetracker/app/ui/viewmodel/HomeViewModel.kt` (`HomeUiState.hasAnyPayment: Boolean`, default `true`)
- Modify: `app/src/main/java/com/expensetracker/app/ui/screens/HomeScreen.kt`

**Interfaces:**
- Consumes: `Mon(MonFace.IDLE, …)` (Task 2).
- Produces: `ExpenseDao.observeAnyExpense(): Flow<Boolean>` (`SELECT EXISTS(SELECT 1 FROM expenses)`; use the real table name from `ExpenseEntity`), exposed as `ExpenseRepository.observeHasAnyPayment()`.

- [ ] **Step 1: Add the query, the repository function and `hasAnyPayment`** to `HomeUiState`, combined into the existing state flow. The default `true` keeps the card hidden while loading.
- [ ] **Step 2: Add the card to Home.** When `uiState.isAccessGranted && !uiState.hasAnyPayment`, show it above `PeriodHero`. It is a card with `Mon(IDLE, 56.dp)`, the title "Waiting for your first payment", the line "Pay for anything. It shows up here.", and a full-width tonal button "Add one by hand" → `onAddPayment`. Below it, a "Set up later" title and one row "Online features" / "Read receipts, join groups" with a chevron → `onOpenSettings`.
- [ ] **Step 3: Build and test.** `./gradlew.bat testDebugUnitTest assembleDebug`. Expected: BUILD SUCCESSFUL, 187 tests, 0 failures. No Room migration: a query only.
- [ ] **Step 4: Commit.** Message `Show a first-payment card on an empty Home`.

### Task 6: Phone check, push, PR with report

- [ ] **Step 1: Install the debug build on the phone** (`io.github.skooyo.koban.debug` is a separate app, so the owner's data is safe): `adb install -r app/build/outputs/apk/debug/app-debug.apk`.
- [ ] **Step 2: Walk the flow and take pictures.** Welcome → Open settings → come back without access (expect the blocked help on Android 13+, or ACCESS again on older) → grant access → apps → Save → keep running → Ready → Home with the first-payment card. Rotate on the ACCESS step: the step must stay. Then force-stop and start again: no onboarding. Also take a picture of one old screen in blue (before, from `feature/groups`) and gold (after).
- [ ] **Step 3: Uninstall the debug app** when done: `adb uninstall io.github.skooyo.koban.debug`.
- [ ] **Step 4: Push and open the PR** to `feature/groups`, then attach the before-and-after report with the `pr-report` skill.
