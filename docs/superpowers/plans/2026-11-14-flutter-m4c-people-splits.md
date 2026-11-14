# Flutter milestone 4c: people, person page and the split editor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish milestone 4: the People tab, the person page (payment QR, what each side owes, settle up, repayments) and the split editor at parity with 0.1.1, then check the whole app against 0.1.1 and build it.

**Architecture:** Same as plans 4a and 4b: repositories in `koban/lib/data/`, one `ChangeNotifier` view-model per screen, `AppServices` through `AppScope`, `KobanPageRoute` for every page. `PeopleRepository` and `QrStore` port the Kotlin classes; the QR picture keeps the 0.1.1 place (`<app files>/qr/<personId>.img`), so the paths that the milestone 2 import copied stay valid. The split editor ports every step except the receipt reading, whose two buttons open the milestone-5 placeholder.

**Tech Stack:** Flutter 3.50.0 / Dart 3.14.0; plans 4a and 4b; new pub package `image_picker` (flutter.dev, newest stable 1.x that `flutter pub add` resolves) for the QR pick; `path_provider` becomes a direct dependency (already in `pubspec.lock` through `drift_flutter`).

**Spec:** `docs/superpowers/specs/2026-11-13-flutter-migration-design.md` (sections 6.2 "Screens", 6.7 items 4 and 5).

**Order:** plan 3 of 3. Start on branch `feature/flutter-m4c` from `main` after plan 4b (`2026-11-14-flutter-m4b-capture-screens.md`) is merged. Milestone 5 comes next.

**Decisions (the spec leaves these to the builder):**
1. **QR pick with `image_picker`:** it opens the Android photo picker (the 0.1.1 `PickVisualMedia` contract) and needs no permission. Rejected: a native pick on the device channel (`FlutterActivity` is not a `ComponentActivity`, so it needs the old activity-result plumbing).
2. **QR file place:** `getApplicationSupportDirectory()` is the Android `files/` folder, which 0.1.1 `QrStore` used. Imported `split_people.qrPath` values point there and stay valid after the update.
3. **The picture check:** `ui.instantiateImageCodec` on the picked bytes replaces `BitmapFactory` bounds; a failure gives the 0.1.1 text `That file isn't an image.` and keeps the old QR.
4. **The split editor without receipt reading:** the steps `Reading` and the Claude parts of the mismatch sheet (`Read again with Claude`) are not built. `Take photo` and `Choose from gallery` open `OnlinePlaceholder(OnlineFeature.receiptReading)`; milestone 5 replaces both. A printed total exists only on bills that 0.1.1 read, so the mismatch card still shows for those.
5. **Test seam for the picker:** `AppServices.pickImage` (`Future<String?> Function()`, default `ImagePicker().pickImage(source: ImageSource.gallery)` → path) so widget tests give a file path.

**Not in this plan:** groups and the group page, Google sign-in, the invite code check, receipt reading, delete account, the updater (milestone 5).

## Global Constraints

- All Global Constraints of plan 4a apply (tools, controller commits, one build at a time, analyze and test at the end of each task, `git diff main -- app/ gradle/` empty, 0.1.1 text, money format, `AppServices.now`, accessibility checks, motion, STE).
- Gradle (`cd koban/android && JAVA_HOME=D:/jdk-17 ./gradlew.bat --max-workers=2 :app:testDebugUnitTest`) runs only in Task 5.
- Messages, verbatim from `PeopleRepository.kt`, `PersonViewModel.kt` and `SplitEditorViewModel.kt`: `Enter a name.`, `Someone already has that name.`, `Settle up with them first.`, `Enter what it was for.`, `Enter an amount above zero.`, `No QR saved yet`, `Try again in a moment.`, `Something went wrong. Try again.`, `Saved to gallery. Open your bank app and pick it.`, `Allow storage access to save the QR.`, `That payment no longer matches. Check the amounts and settle up by hand.`, `Couldn't save the split. Try again.`, `Couldn't delete the split. Try again.`
- The repository is public: names and shops in tests are synthetic (`Ali`, `Mei`, `Kedai Contoh`).

## Review Focus

1. A friend's 0.1.1 QR (imported path `/data/user/0/<app>/files/qr/<id>.img`) must show on the person page after the update, and a replace must show the new picture at once, not the cached old one. Pinned in Tasks 1 and 3.
2. A friend picks a file that is not a picture as a QR: the old QR stays and the page says `That file isn't an image.` Pinned in Task 1.
3. Two fast taps on a person action (Settle up, Mark paid, Delete) run one action; the second tap says `Try again in a moment.` Pinned in Task 3.
4. "Split this bill" from an edited payment saves the payment first, so the editor links the new amount; a payment linked to another split is refused with its message, not a crash. Pinned in Task 2.
5. Back on a saved bill opened with "Edit items" asks `Discard changes?`; Back on a viewed bill leaves at once. Pinned in Task 2.

---

### Task 1: People data and the QR store

**Files:**
- Modify: `koban/pubspec.yaml` (`flutter pub add image_picker path_provider`), `koban/lib/app/app_services.dart` (add `qr`, `people`, `pickImage`), `koban/lib/app/home_shell.dart` (People badge)
- Create: `koban/lib/data/people_repository.dart`, `koban/lib/data/qr_store.dart`
- Test: `koban/test/data/people_repository_test.dart`, `koban/test/data/qr_store_test.dart`, `koban/test/app/people_badge_test.dart`

**Interfaces:**
- Consumes: `SplitRepository` (`watchOpenDebts`, `closeAllFor`, `clearSettleSuggestion`, `isUsableRepayment`, `deleteSplit`) and the `split_queries.drift` queries (plan 4a Task 2); `DeviceControl.saveImageToGallery`, `storageAllowed`, `requestStoragePermission` (plan 4b Task 1); `PeopleMath`, `Balance` (milestone 1); `KobanUserError`.
- Produces:
  - `class PersonSummary { final SplitPeopleData person; final Balance balance; final bool hasOpen; }`, `class PersonDetail { person, balance, List<OpenDebtView> owedToMe, List<OwedItem> iOwe, Expense? settleSuggestion }`.
  - `class PeopleRepository { PeopleRepository(KobanDatabase db, {required SplitRepository splits, required QrStore qr, required int Function() now}); Stream<List<PersonSummary>> watchPeople(); Stream<PersonDetail?> watchPerson(String personId); Future<String> addPerson(String name); Future<void> renamePerson(String personId, String name); Future<void> archivePerson(String personId); Future<void> setQr(String personId, String sourcePath); Future<void> saveQrToGallery(String personId); Future<void> addOwedItem(String personId, String description, Decimal amount, int itemDate); Future<void> updateOwedItem(OwedItem item); Future<void> deleteOwedItem(String id); Future<void> markOwedItemPaid(String id); Future<void> addOwedToMe(String personId, String description, Decimal amount, int itemDate); Future<void> updateOwedToMe(String debtId, String description, Decimal amount, int itemDate); Future<void> deleteOwedToMe(String debtId); Future<void> settleUp(String personId); Future<bool> confirmSettleSuggestion(String personId); Future<void> dismissSettleSuggestion(String personId); }` — port of `PeopleRepository.kt`; the gallery name is `koban-${name with each non letter or digit replaced by '-'}-qr.jpg`; `watchPerson` gives null for a missing or archived person.
  - `class QrStore { QrStore({required Future<Directory> Function() filesDir, required DeviceControl device}); Future<String> importQr(String personId, String sourcePath); Future<void> delete(String? path); Future<void> saveToGallery(String path, String displayName); }` — `importQr` checks the bytes with `ui.instantiateImageCodec` (failure → `KobanUserError("That file isn't an image.")`), copies to `qr/<personId>.tmp`, renames it to `qr/<personId>.img`, deletes the temp file in `finally`, evicts `FileImage(target)` from the image cache, and returns the absolute path.
  - `AppServices.pickImage`: `Future<String?> Function()` (Decision 5).
  - People badge: the People tab icon gets `Badge(label: Text('$n'))` with semantics label `$n open` when `n` people have an open balance (`AppViewModel.openPeopleCount`).

- [ ] **Step 1: Write the failing tests.** In-memory database; `filesDir` = a temp folder; device channel mocked; a 1 × 1 PNG test file written by the test.

```dart
test('add person reuses a stored person with the same name and revives an archived one', ...);
test('a blank name is refused', ...); // KobanUserError('Enter a name.')
test('rename to a name that someone has is refused', ...); // 'Someone already has that name.'
test('delete with something open is refused', ...); // 'Settle up with them first.'
test('delete removes paid items and the QR file after the row is cleared', ...);
test('an owed item needs a reason and an amount above zero', ...); // 'Enter what it was for.', 'Enter an amount above zero.'
test('money owed to me without a bill is a manual split with one open debt', ...);
  // addOwedToMe(ali, 'Cash', 20.00, d) → split_bills: manual 1, merchant 'Cash', currency 'MYR'; split_debts: 1 OPEN 20.00
test('an edit of money owed to me drops a repayment suggestion that included it', ...);
test('settle up closes every debt and every item of the person', ...);
test('a stale settle suggestion is cleared and settles nothing', ...); // confirmSettleSuggestion → false, suggestedSettleExpenseId null
// Review Focus 1
test('a QR import copies the picture to qr/<id>.img and the person points at it', ...);
// Review Focus 2
test('a file that is not a picture keeps the old QR', ...); // KobanUserError("That file isn't an image."); qrPath and file unchanged
test('save to gallery uses a safe file name', ...); // person "Ali bin Abu" → device got saveImageToGallery(path, 'koban-Ali-bin-Abu-qr.jpg')
testWidgets('the People tab shows how many people have something open', ...); // 2 people open → badge '2', semantics '2 open'
```

- [ ] **Step 2: Run.** `flutter test test/data/people_repository_test.dart test/data/qr_store_test.dart test/app/people_badge_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (14 new tests).
- [ ] **Step 5: Commit.** "Port the people repository and the QR store".

### Task 2: Split editor

**Files:**
- Create: `koban/lib/screens/split/split_editor_screen.dart`, `koban/lib/screens/split/split_editor_view_model.dart`, `koban/lib/screens/split/split_editor_steps.dart`
- Modify: `koban/lib/app/routes.dart` (`openSplitNew`, `openSplitEdit`; `openPaymentEdit` pushes the editor after a `PaymentOpenSplit` result), `koban/lib/screens/payment/payment_screen.dart` and `payment_view_model.dart` (`Split this bill`, `saveAndSplit`)
- Test: `koban/test/screens/split_editor_view_model_test.dart`, `koban/test/screens/split_editor_test.dart`

**Interfaces:**
- Consumes: `SplitRepository` (all of plan 4a Task 2), `ExpenseRepository.getById`, `KobanSettings.hasDeviceToken`, `DeviceControl.shareText`, `SplitMath`, `AmountFormatter.parseInput`, `StepProgress`, `TonalButton`, `showDiscardChangesDialog`, `openOnlinePlaceholder`.
- Produces:
  - `enum SplitStep { photo, items, people, assign, link, summary }`, `class ItemRow { key, name, quantity = '1', price, sharedBy }`, `class SplitEditorState` (the fields of `SplitEditorState` in `SplitEditorViewModel.kt` without the reading fields `readNote`, `readSource`, `canReadAgain`, `readsLeft`, `readingAgain`).
  - `class SplitEditorViewModel extends ChangeNotifier { SplitEditorViewModel(AppServices s, {String? billId, String? expenseId}); SplitEditorState get state; List<SplitPeopleData> get recentPeople; void typeItemsInstead(); void addItem(); void updateItem(int key, ItemRow Function(ItemRow) change); void removeItem(int key); void setMerchant(String v); void setServiceCharge(String v); void setTax(String v); void setDiscount(String v); void setRounding(String v); void addRoundingDifference(); void addPerson(String name); void togglePerson(SplitPeopleData p); void toggleShare(int key, String personId); void selectExpense(String? id); Future<void> saveLockedPayment(); void editItems(); void changePayment(); Future<void> deleteSplit(); void next(); bool back(); void discardEdits(); void keepEditing(); Future<void> done(); static List<DraftItem>? parseItems(SplitEditorState s); static SplitCharges? chargesOf(SplitEditorState s); static Decimal? totalOf(SplitEditorState s); static Decimal? difference(SplitEditorState s); static Set<int> unassigned(SplitEditorState s); static List<(String, Decimal)>? summaryLines(SplitEditorState s); static String? shareText(SplitEditorState s); }` — port of `SplitEditorViewModel.kt` (the step moves, the `back` rules, `done` rules, a `KobanUserError` message shown as `error`, the other errors as the 0.1.1 texts).
  - `PaymentViewModel.saveAndSplit() → Future<PaymentResult?>` — saves, then `PaymentOpenSplit(expenseId)`; only for an edited payment. The payment sheet shows the tonal button `Split this bill` (icon `Icons.groups`, height 56, off until the amount is valid) when editing a Spent payment.
  - `routes.dart`: `Future<void> openSplitNew(BuildContext context, {String? expenseId})`, `Future<void> openSplitEdit(BuildContext context, String billId)`.
  - `SplitEditorScreen({String? billId, String? expenseId})` — `SplitEditorScreen.kt` and `SplitEditorSteps.kt`: title `Split a bill`, Back; step names `Receipt`, `Items`, `People`, `Who had what`, `Payment`, `Summary`; Photo (`Start with the receipt`, the online or offline line, `Take photo`, `Choose from gallery` → `openOnlinePlaceholder(context, OnlineFeature.receiptReading)`, `Type items instead`); Items (`Place`, `Items`, `Item`, `Qty`, `Line price (RM)`, `Remove $name` or `Remove item`, `Add item`, `Charges`, `Service charge (RM)`, `SST (RM)`, `Discount (RM)`, `Rounding (RM)` with `Use - for a negative amount`, `Total` or `Check the amounts`, `Receipt total`, the mismatch card `Differs from the receipt total by RM 0.50.` / `Items add up to RM 23.50. The receipt says RM 24.00.` / `Fix`, the fix sheet `Add RM 0.50 as rounding` and `Edit by hand`); People (`Who is sharing?`, `Tap a name to add or remove it.`, the fixed `Me` chip, recent people chips, `New person`, `Add`); Assign (`Tap names to share each item. A shared item splits evenly.`, `Nasi lemak ×2`, `Pick at least one person`); Link (`Which payment was this?`, `Link the card payment, so your spending counts only your share.`, `Not paid by card`, options `EEE, d MMM, HH:mm`, the line `The payment is RM 24.00, the receipt is RM 23.50. Your share absorbs the difference.`); Summary (`Split done`, `Someone has paid you back, so the items can't change.` or `Ali now owes you.` / `Ali and Mei now owe you.`, lines with `Me` last, `Total`, `Share summary` → `device.shareText(shareText)`, `Change payment`, `Edit items`, `Delete split` → `Delete this split?` / `The bill and what people owe are removed. Your payment counts in full again.` / `Delete split` / `Cancel`); bottom actions `Next`, `Next · 2 people` (`person` for one), `Save payment` (locked bill on the Link step), `Done`; the screen pops when `state.finished`.

- [ ] **Step 1: Write the failing tests.** Draft: place `Kedai Contoh`, bill time 13 Nov 2026, items `Nasi lemak` 20.00 shared by Me and Ali, `Teh ais` 4.00 by Ali.

```dart
// split_editor_view_model_test.dart
test('a row with no name, a bad quantity or a price of 0 makes the items invalid', ...);
test('the difference is the printed total minus the computed total, null when equal', ...);
test('add rounding difference moves the whole gap into rounding', ...); // printed 24.50 → rounding '0.50'
test('the summary lines list the others first and Me last', ...); // [('Ali', 14.00), ('Me', 10.00)]
test('the share text has the place, the date, each share and the total', () {
  expect(SplitEditorViewModel.shareText(s), 'Kedai Contoh, 13 Nov 2026\nAli: RM 14.00\nMe: RM 10.00\nTotal: RM 24.00');
});
test('a person named Me or a name already in the list is not added', ...);
test('removing a person also removes them from every item', ...);
test('a split from a payment links it and takes its time as the bill time', ...);
test('a payment that already has a split opens that split on the summary', ...);
// Review Focus 5
test('back on a saved bill in edit mode asks first, and on a viewed bill leaves', ...);
  // editItems() then back on Items → true and confirmDiscard true; a viewed bill on Summary → back() false
test('done on a viewed bill saves nothing', ...);
test('done saves the split and finishes', ...); // split_debts: Ali 14.00 OPEN
test('a locked bill only saves its payment link', ...);

// split_editor_test.dart
testWidgets('the receipt step offers the photo buttons and typing', ...);
  // 'Start with the receipt'; 'Take photo' → 'Receipt reading' placeholder; back; 'Type items instead' → 'Step 2 of 6 · Items' and one empty item row
testWidgets('a full split from typed items ends on Split done', ...);
  // type the draft → Next → 'Who is sharing?' add 'Ali' → 'Next · 2 people' → assign → 'Next' → 'Not paid by card' → 'Next' → 'Split done', 'Ali now owes you.' → 'Done' → popped
testWidgets('Next on the assign step is off while an item has nobody', ...); // 'Pick at least one person'
testWidgets('Share summary sends the share text to the device', ...); // device channel shareText {text: '<share text>', chooserTitle: 'Share summary'}
testWidgets('delete split asks first and then closes', ...);
// Review Focus 4
testWidgets('Split this bill saves the payment first and opens the editor with it linked', ...);
  // edit 24.00 → amount 26.00 → 'Split this bill' → expense amount 26.00; editor selectedExpenseId == the payment id
testWidgets('a payment linked to another split shows the refusal on the summary', ...); // 'This payment already belongs to another split.'
testWidgets('the split editor meets the tap target guidelines and works at text scale 1.3', ...);
```

- [ ] **Step 2: Run.** `flutter test test/screens/split_*` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (21 new tests).
- [ ] **Step 5: Commit.** "Add the split editor and Split this bill".

### Task 3: Person page

**Files:**
- Create: `koban/lib/screens/person/person_screen.dart`, `koban/lib/screens/person/person_view_model.dart`, `koban/lib/screens/person/person_dialogs.dart`
- Modify: `koban/lib/app/routes.dart` (`openPerson`)
- Test: `koban/test/screens/person_view_model_test.dart`, `koban/test/screens/person_screen_test.dart`

**Interfaces:**
- Consumes: `PeopleRepository` (Task 1), `SplitRepository.repaymentCandidates` / `markPaid` / `confirmSuggestion` / `dismissSuggestion`, `AppServices.pickImage`, `DeviceControl.storageAllowed` / `requestStoragePermission`, `openSplitEdit` (Task 2), `PeopleMath.headline`, `showPastDatePicker`, `DialogTextField`.
- Produces:
  - `class DebtPayment { final OpenDebtView debt; final List<Expense> candidates; }`
  - `class PersonViewModel extends ChangeNotifier { PersonViewModel(AppServices s, String personId); PersonDetail? get detail; bool get gone; int get qrVersion; DebtPayment? get paying; Stream<String> get messages; void showMessage(String m); Future<void> rename(String name); Future<void> addItem(String description, Decimal amount, int itemDate); Future<void> updateItem(OwedItem item); void deleteItem(String id); void markItemPaid(String id); Future<void> addOwedToMe(String d, Decimal a, int date); Future<void> updateOwedToMe(String debtId, String d, Decimal a, int date); void deleteOwedToMe(String debtId); void delete(); void pickQr(); void saveQrToGallery(); void settleUp(); void confirmSettle(); void dismissSettle(); void startPaying(OpenDebtView debt); void cancelPaying(); void markDebtPaid(String? expenseId); void confirmDebtSuggestion(String debtId); void dismissDebtSuggestion(String debtId); }` — port of `PersonViewModel.kt`: one action at a time (`busy`; a tap during an action sends `Try again in a moment.`); a `KobanUserError` sends its message, another error `Something went wrong. Try again.`; dialog actions (`rename`, `addItem`, `updateItem`, `addOwedToMe`, `updateOwedToMe`) throw so the dialog shows the message; `pickQr` uses `pickImage` (null = cancelled, no message) and bumps `qrVersion`; `saveQrToGallery` asks for storage when `storageAllowed` is false and sends `Allow storage access to save the QR.` on a refusal.
  - `routes.dart`: `Future<void> openPerson(BuildContext context, String personId)`.
  - `PersonScreen(personId)` — `PersonScreen.kt` and `PersonDialogs.kt`: top bar with the name, Back, `More options` menu (`Rename`, `Replace QR` when a QR exists, `Delete person`); the QR frame (tap label `Replace QR` or `Add QR`, image label `$name's payment QR`, `Couldn't load the QR. Tap to pick it again.` or `Add their payment QR`); `Save QR to gallery` and `Then open your bank app and pick it from the gallery`; the headline with only the trailing `RM …` in the balance color; `Settle up`; `Possible settle up` card (`Not this`, `Confirm`); `$name owes you` with debt rows (`Split bill` when no shop; tap `Edit` for a manual debt, `Open split` else; `Possible repayment` card; `Mark paid`), `Add what $name owes me`; `You owe $name` with item rows (`Mark paid`), `Add what I owe`; `Nothing.` for an empty list; the dialogs `Rename`, the owed item dialog (`Add what I owe`, `Add what $name owes me`, `Edit what $name owes me`, `Edit what I owe`; fields `What for`, `Amount`, `Date` with `Pick date`; `Delete` in edit; `Save`, `Cancel`), `Settle up with $name?` (`Closes 1 split bill debt and 2 items you owe. Split bills it touches can't be edited after this.`), `Delete $name?` (`Their QR and paid items are removed. Split bills keep their name.`), `Delete this item?` (`This removes what $name owes you for it.` / `This removes what you owe for it.`), `Mark paid` (candidates `RM 12.00 from Ali, 3 Oct`, `Paid in cash`, `Cancel`); the page pops when `gone` turns true; messages as snackbars. The QR image is `Image.file(File(path), key: ValueKey(qrVersion))`.

- [ ] **Step 1: Write the failing tests.** Person Ali: a split debt 14.00 (bill `Kedai Contoh`), a manual debt 20.00 (`Cash`), one item the owner owes 4.00 (`Parking`).

```dart
// person_view_model_test.dart
// Review Focus 3
test('a second action during the first says Try again in a moment', ...);
  // vm.settleUp(); vm.markItemPaid(id) at once → messages ['Try again in a moment.']; one settle only
test('a refused action sends its message', ...); // delete with open items → 'Settle up with them first.'
test('mark paid with a matching receive closes the debt', ...);
test('a stale settle suggestion says it no longer matches', ...);
test('a refused storage permission says how to save the QR', ...); // storageAllowed false, request false → 'Allow storage access to save the QR.'
test('a saved QR says to open the bank app', ...); // 'Saved to gallery. Open your bank app and pick it.'

// person_screen_test.dart
testWidgets('the page shows the headline and both sides', ...);
  // 'Ali pays you RM 30.00', 'Ali owes you', 'Kedai Contoh', 'Cash', 'You owe Ali', 'Parking'
testWidgets('Settle up asks with the counts and closes everything', ...);
  // 'Settle up with Ali?', 'Closes 2 split bill debts and 1 item you owe. Split bills it touches can't be edited after this.'
testWidgets('add what I owe checks the fields in the dialog', ...); // empty 'What for' → 'Enter what it was for.' in the dialog
testWidgets('a manual debt opens its edit dialog and a split debt opens the split', ...); // 'Edit what Ali owes me'; 'Split done'
testWidgets('Mark paid offers the matching receives and cash', ...); // 'Mark paid', 'RM 14.00 from Ali, 13 Nov', 'Paid in cash'
// Review Focus 1
testWidgets('an imported QR shows and a replace shows the new picture', ...);
  // qrPath = a PNG in the temp files folder → Image with semantics "Ali's payment QR"; pickImage gives another PNG → Image key changes
testWidgets('Delete person asks and closes the page', ...); // after settle up: 'Delete Ali?' → 'Delete' → popped
testWidgets('the person page meets the tap target guidelines and works at text scale 1.3', ...);
```

- [ ] **Step 2: Run.** `flutter test test/screens/person_*` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (14 new tests).
- [ ] **Step 5: Commit.** "Add the person page".

### Task 4: People tab

**Files:**
- Create: `koban/lib/screens/people/people_screen.dart`, `koban/lib/screens/people/people_view_model.dart`
- Modify: `koban/lib/app/home_shell.dart` (the People tab body replaces the empty `SizedBox`)
- Test: `koban/test/screens/people_test.dart`

**Interfaces:**
- Consumes: `PeopleRepository.watchPeople` / `addPerson`, `SplitRepository.watchBills`, `PeopleMath.normalizedName` / `group` / `statusLine`, `PeopleGroup`, `openPerson` (Task 3), `openSplitNew` / `openSplitEdit` (Task 2).
- Produces:
  - `class PeopleViewModel extends ChangeNotifier { PeopleViewModel(AppServices s); String get query; void setQuery(String q); List<(PeopleGroup, List<PersonSummary>)> get sections /* non-empty groups in enum order, filtered by the normalized query */; List<SplitBill> get bills; Future<String> add(String name); }`
  - `PeopleScreen` — `PeopleScreen.kt`: `LargeTopBar(title: 'People', subtitle: 'Payment QRs, and what you owe each other')`; search `Search people`; tonal `Split a bill` → `openSplitNew`; empty `No people yet. Add someone, or split a bill to start.` or `Nobody matches that search.`; headings `You owe`, `Owes you`, `Everyone else`; person rows (avatar, name, `PeopleMath.statusLine(name, balance, hasQr: qrPath != null)`, tap label `Open`); `Past splits` rows (`Split bill` when no shop, the date `d MMM`, tap label `Open`); the gold `Add person` button → dialog `Add person`, field `Name`, `Add`, `Cancel` → opens the new person.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('people show in the You owe, Owes you and Everyone else groups', ...);
  // Ali pays you 14.00, Mei you pay 4.00, Abu all paid with no QR → 'You owe' [Mei 'You pay RM 4.00'], 'Owes you' [Ali 'Pays you RM 14.00'], 'Everyone else' [Abu 'No QR saved yet']
testWidgets('search ignores case and extra spaces', ...); // ' ALI ' → only Ali
testWidgets('a search with no match says so', ...); // 'Nobody matches that search.'
testWidgets('with nobody the tab says how to start', ...);
testWidgets('Add person opens the new person', ...); // 'Add person' → 'Name' 'Ali' → 'Add' → person page 'Ali'
testWidgets('a blank name stays in the dialog with its message', ...); // 'Enter a name.'
testWidgets('Past splits open the split and Split a bill starts one', ...);
testWidgets('the People tab meets the tap target guidelines and works at text scale 1.3', ...);
```

- [ ] **Step 2: Run.** `flutter test test/screens/people_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (8 new tests).
- [ ] **Step 5: Commit.** "Add the People tab".

### Task 5: Milestone check

**Files:**
- Create: `koban/test/app/parity_test.dart`

**Interfaces:**
- Consumes: every open function in `koban/lib/app/routes.dart`.
- Produces: one test that opens each 0.1.1 route from the running app and finds its title. Routes of `app/.../ui/navigation/Routes.kt` and their Flutter place:

| 0.1.1 route | Flutter | Title the test finds |
| --- | --- | --- |
| `home` | `HomeShell` tab Home | `Today` |
| `activity` | tab Activity | `Activity` |
| `people` | tab People | `People` |
| `groups` | tab Groups (`OnlinePlaceholder(OnlineFeature.groups)`) | `Groups` |
| `groups/{groupId}` | milestone 5 | — |
| `people/{personId}` | `openPerson` | the name |
| `split/new` | `openSplitNew` | `Split a bill` |
| `split/edit/{billId}` | `openSplitEdit` | `Split done` |
| `payment/new` | `openPaymentNew` | `Save payment` |
| `payment/edit/{expenseId}` | `openPaymentEdit` | `Payment` |
| `check` | `openCheckPayments` | `Check payments` |
| `settings` | `openSettings` | `Settings` |
| `settings/payment_apps` | `openPaymentApps` | `Payment apps` |
| `settings/notification_debug` | `openNotificationLog` | `Notification log` |
| `onboarding` | `openOnboarding` | `Koban counts your spending for you.` |

- [ ] **Step 1: Write the test** `every 0.1.1 route opens its Flutter screen` (one `testWidgets` that pushes each route in turn, checks the title, and pops), and `the app works in the light theme` (prefs `dark_mode` false: open Home, Activity, payment sheet and Check payments; no exception; `Theme.of(context).brightness == Brightness.light`).
- [ ] **Step 2: Run everything, one at a time.** `flutter analyze` → "No issues found!"; `flutter test` → "All tests passed!"; Gradle test → BUILD SUCCESSFUL.
- [ ] **Step 3: Build once.** `flutter build apk --debug` → `koban/build/app/outputs/flutter-apk/app-debug.apk` exists. Do not install it.
- [ ] **Step 4: Check the placeholders.** `grep -rn "OnlineFeature\." koban/lib` → exactly these 5 uses: Groups tab body (`groups`), Settings `Use code` (`inviteCode`), Settings `Check for updates` (`updates`), split editor `Take photo` and `Choose from gallery` (`receiptReading`). `grep -rn "inGroups" koban/lib` → `AppServices` and the payment sheet only.
- [ ] **Step 5: Check the Kotlin app is untouched.** `git diff --stat main -- app/ gradle/` → empty.
- [ ] **Step 6: Draft the map note** for issue #20 (3 to 5 lines, STE): all local screens of 0.1.1 are in Flutter with the 0.1.1 motion and both themes; 5 online entry points open a placeholder for milestone 5; the owner device checks are open. The controller posts it.
- [ ] **Step 7: Commit.** "Check milestone 4 against the 0.1.1 routes".

## Known limits

- Receipt reading, groups, the invite code check and the updater are placeholders until milestone 5.
- The split editor has no `Reading` step and no `Read again with Claude`; milestone 5 adds them to `SplitStep` and the fix sheet.
- The phone's photo picker, gallery save, share sheet and permission dialogs are not tested on a phone yet (owner device checks).

## Owner device checks (end of milestone 4)

Install the debug build over the 0.1.1 debug build as in milestone 3 (`adb install -r koban/build/app/outputs/flutter-apk/app-debug.apk`). About 30 minutes.

1. Open Koban. Home shows the 0.1.1 totals; open a payment from Activity: it rises as a sheet; open Settings: it slides in and Home moves 30% to the left and darkens. Turn on "Remove animations" in the Android accessibility settings: pages show at once.
2. Settings › Dark mode off: the app turns light at once and stays light after a restart.
3. Make a small real payment with Koban open on Home: "1 payment to check" shows within about 5 seconds. Open it, swipe right, press the Home button within 4 seconds, open Koban again: the payment is in Activity and the card does not come back.
4. Settings › Payment apps: the list shows app icons and names; save 1 app. Settings › Notification log: rows show and new rows come in while it is open.
5. A person with a 0.1.1 QR shows the same QR. Replace it from the photo picker. Save QR to gallery: the picture is in Pictures/Koban. A split summary › Share summary opens the Android share sheet with the text.
6. On an Android 13 or later phone, clear the app data of a test install, open Koban: onboarding starts; in Keep it running, Allow asks for the alerts permission.
