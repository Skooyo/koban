# Contact Book Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A "People" contact book in Koban that stores each person's payment QR, shows money owed in both directions as one net amount, and replaces "Who owes me".

**Architecture:** People stay in `split_people` (new columns). Hand-entered items the owner owes go in a new `owed_items` table. Pure balance logic lives in `PeopleMath` (unit tested). A new `PeopleRepository` owns people, QR files and owed items, and calls `SplitRepository` for split debts. Two new Compose screens (`PeopleScreen`, `PersonScreen`) replace `DebtsScreen`.

**Tech Stack:** Kotlin, Jetpack Compose Material 3, Room (v6 → v7), Hilt, AndroidX Activity Photo Picker, MediaStore.

**Spec:** `docs/superpowers/specs/2026-10-20-contact-book-design.md`

## Global Constraints

- MYR only. Money is `BigDecimal` with scale 2, stored as TEXT, compared with `compareTo`.
- No new dependency. No QR decoding.
- Hand-entered items never create or count as spending.
- Names: trimmed, unique case-insensitively, enforced in app logic (no DB unique index).
- Room `exportSchema = false`; migrations are explicit in `data/DatabaseMigrations.kt` and must keep all existing rows.
- Both themes (dark default, Banknote light) via `MaterialTheme.colorScheme` and `LocalMoneyColors` (`gold` for amounts the owner pays, `received` for amounts paid to the owner).
- Copy is fixed by the spec: "People", "Save QR to gallery", "Then open your bank app and pick it from the gallery", "Saved to gallery. Open your bank app and pick it.", "Add their payment QR", "+ Add what I owe", "Mark paid", "Settle up", "[Name] pays you RM X", "You pay [Name] RM X", "You're even", "All paid", "No QR saved yet".
- No instrumented tests. Unit tests are JVM tests under `app/src/test`.
- Do not run `git commit`. The owner commits. Steps say "Stage" instead.
- Back up the phone database before installing the v7 build.

## Review Focus

1. A person added in the contact book with the same name as a split person (different case or extra spaces) must open the existing person, never create a duplicate. Test: `PeopleMathTest.normalizedName_matchesCaseAndSpaces` (Task 2).
2. Settle suggestion with two people whose net both equal the received amount and no sender match: no suggestion. Test: `PeopleMathTest.settleMatch_ambiguousWithoutSender_returnsNull` (Task 2).
3. Net exactly zero with open items both sides shows "You're even", not "All paid". Test: `PeopleMathTest.status_evenWhenNetZeroWithOpenItems` (Task 2).
4. Confirming a stale settle suggestion (an item was added after the suggestion) must not close anything. Covered by `PeopleRepository.confirmSettleSuggestion` re-checking `PeopleMath.net`; reviewer checks it in Task 3.
5. Saving a split bill that names an archived person revives that person instead of creating a second row. Reviewer checks `SplitRepository.saveSplit` in Task 3.

---

### Task 1: Schema v7

**Files:**
- Modify: `app/src/main/java/com/expensetracker/app/data/SplitEntities.kt`
- Create: `app/src/main/java/com/expensetracker/app/data/OwedItemEntity.kt`
- Modify: `app/src/main/java/com/expensetracker/app/data/DatabaseMigrations.kt`
- Modify: `app/src/main/java/com/expensetracker/app/data/ExpenseDatabase.kt`
- Modify: `app/src/main/java/com/expensetracker/app/data/SplitDao.kt`
- Modify: `app/src/main/java/com/expensetracker/app/di/AppModule.kt`

**Interfaces:**
- Produces:
  - `SplitPersonEntity(id, name, lastUsedAt, qrPath: String? = null, archived: Boolean = false, suggestedSettleExpenseId: String? = null)`
  - `@Entity(tableName = "owed_items", indices = [Index("personId")]) data class OwedItemEntity(@PrimaryKey id: String, personId: String, description: String, amount: BigDecimal, itemDate: Long, createdAt: Long, status: DebtStatus, paidAt: Long?)`
  - `val MIGRATION_6_7: Migration`
  - `SplitDao` additions: `observeAllPeople(): Flow<List<SplitPersonEntity>>` (archived = 0, ORDER BY name COLLATE NOCASE), `getPerson(id): SplitPersonEntity?`, `observePerson(id): Flow<SplitPersonEntity?>`, `observeOpenDebtsFor(personId): Flow<List<OpenDebtRow>>`, `getOpenDebtsFor(personId): List<SplitDebtEntity>`, `insertOwedItem(item)`, `updateOwedItem(item)`, `deleteOwedItem(id)`, `getOwedItem(id)`, `observeOwedItems(personId): Flow<List<OwedItemEntity>>` (status OPEN, ORDER BY itemDate), `getOpenOwedItems(personId): List<OwedItemEntity>`, `observeAllOpenOwedItems(): Flow<List<OwedItemEntity>>`, `deletePaidOwedItems(personId)`.
  - Existing `observePeople()` / `getPeople()` filter `archived = 0`; add `getAllPeopleIncludingArchived(): List<SplitPersonEntity>` for name matching.

- [ ] **Step 1: Add the columns and entity**, register `OwedItemEntity` in `@Database`, set `version = 7`.
- [ ] **Step 2: Write `MIGRATION_6_7`** with exactly:
  - `ALTER TABLE split_people ADD COLUMN qrPath TEXT`
  - `ALTER TABLE split_people ADD COLUMN archived INTEGER NOT NULL DEFAULT 0`
  - `ALTER TABLE split_people ADD COLUMN suggestedSettleExpenseId TEXT`
  - `CREATE TABLE IF NOT EXISTS owed_items (id TEXT NOT NULL, personId TEXT NOT NULL, description TEXT NOT NULL, amount TEXT NOT NULL, itemDate INTEGER NOT NULL, createdAt INTEGER NOT NULL, status TEXT NOT NULL, paidAt INTEGER, PRIMARY KEY(id))`
  - `CREATE INDEX IF NOT EXISTS index_owed_items_personId ON owed_items (personId)`
- [ ] **Step 3: Add `MIGRATION_6_7` to `.addMigrations(...)`** in `AppModule.provideDatabase`.
- [ ] **Step 4: Build.** Run `.\gradlew.bat assembleDebug testDebugUnitTest -q`. Expected: exit 0 (Room validates the schema against the entities at runtime, so the reviewer compares the migration SQL with the entity fields line by line).
- [ ] **Step 5: Stage** the files.

### Task 2: PeopleMath

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/data/PeopleMath.kt`
- Test: `app/src/test/java/com/expensetracker/app/data/PeopleMathTest.kt`

**Interfaces:**
- Produces:
  - `sealed interface Balance { data class PaysYou(val amount: BigDecimal); data class YouPay(val amount: BigDecimal); data object Even; data object AllPaid }`
  - `object PeopleMath`:
    - `fun normalizedName(name: String): String` — trim, collapse inner whitespace to one space, lowercase.
    - `fun net(owedToMe: List<BigDecimal>, iOwe: List<BigDecimal>): BigDecimal` — scale 2.
    - `fun balance(owedToMe: List<BigDecimal>, iOwe: List<BigDecimal>): Balance`
    - `fun statusLine(name: String, balance: Balance, hasQr: Boolean): String` — list row text: "Pays you RM 5.31", "You pay RM 18.00", "You're even", "All paid", or "No QR saved yet" (AllPaid and no QR).
    - `fun headline(name: String, balance: Balance): String` — person screen: "Jun Wei pays you RM 5.31", "You pay Jun Wei RM 18.00", "You're even", "All paid".
    - `enum class Group { YOU_OWE, OWES_YOU, OTHERS }` and `fun group(balance: Balance): Group`
    - `data class SettleCandidate(val personId: String, val name: String, val net: BigDecimal)`
    - `fun settleMatch(amount: BigDecimal, senderName: String?, candidates: List<SettleCandidate>): String?` — candidates whose `net > 0` and `net.compareTo(amount) == 0`; one → its id; several → the single one whose name shares a word (letters only, length ≥ 3, case-insensitive) with `senderName`; otherwise null. Reuse the word rule from `RepaymentMatcher` by making its `words` function `internal`.
- Money text uses the existing `AmountFormatter` if it formats "RM 5.31"; otherwise `"RM " + amount.setScale(2).toPlainString()`.

- [ ] **Step 1: Write the failing tests**

```kotlin
class PeopleMathTest {
    private fun m(s: String) = BigDecimal(s)

    @Test fun net_subtractsWhatIOwe() =
        assertEquals(m("5.31"), PeopleMath.net(listOf(m("23.31")), listOf(m("18.00"))))

    @Test fun balance_paysYouWhenPositive() =
        assertEquals(Balance.PaysYou(m("5.31")), PeopleMath.balance(listOf(m("23.31")), listOf(m("18.00"))))

    @Test fun balance_youPayWhenNegative() =
        assertEquals(Balance.YouPay(m("18.00")), PeopleMath.balance(emptyList(), listOf(m("18.00"))))

    @Test fun status_evenWhenNetZeroWithOpenItems() =
        assertEquals(Balance.Even, PeopleMath.balance(listOf(m("10.00")), listOf(m("10.00"))))

    @Test fun status_allPaidWhenNothingOpen() =
        assertEquals(Balance.AllPaid, PeopleMath.balance(emptyList(), emptyList()))

    @Test fun headline_namesWhoPays() {
        assertEquals("Jun Wei pays you RM 5.31", PeopleMath.headline("Jun Wei", Balance.PaysYou(m("5.31"))))
        assertEquals("You pay Jun Wei RM 18.00", PeopleMath.headline("Jun Wei", Balance.YouPay(m("18.00"))))
    }

    @Test fun statusLine_noQrOnlyWhenAllPaid() {
        assertEquals("No QR saved yet", PeopleMath.statusLine("Daniel", Balance.AllPaid, hasQr = false))
        assertEquals("All paid", PeopleMath.statusLine("Aisyah", Balance.AllPaid, hasQr = true))
        assertEquals("You pay RM 18.00", PeopleMath.statusLine("Jun Wei", Balance.YouPay(m("18.00")), hasQr = false))
    }

    @Test fun group_ordersYouOweFirst() {
        assertEquals(PeopleMath.Group.YOU_OWE, PeopleMath.group(Balance.YouPay(m("1.00"))))
        assertEquals(PeopleMath.Group.OWES_YOU, PeopleMath.group(Balance.PaysYou(m("1.00"))))
        assertEquals(PeopleMath.Group.OTHERS, PeopleMath.group(Balance.Even))
    }

    @Test fun normalizedName_matchesCaseAndSpaces() =
        assertEquals(PeopleMath.normalizedName("jun wei"), PeopleMath.normalizedName("  Jun   Wei "))

    @Test fun settleMatch_singleCandidate() = assertEquals("p1",
        PeopleMath.settleMatch(m("5.31"), "SOMEONE", listOf(PeopleMath.SettleCandidate("p1", "Jun Wei", m("5.31")))))

    @Test fun settleMatch_senderBreaksTie() = assertEquals("p2", PeopleMath.settleMatch(m("5.31"), "PRIYA DEVI",
        listOf(PeopleMath.SettleCandidate("p1", "Jun Wei", m("5.31")), PeopleMath.SettleCandidate("p2", "Priya", m("5.31")))))

    @Test fun settleMatch_ambiguousWithoutSender_returnsNull() = assertNull(PeopleMath.settleMatch(m("5.31"), null,
        listOf(PeopleMath.SettleCandidate("p1", "Jun Wei", m("5.31")), PeopleMath.SettleCandidate("p2", "Priya", m("5.31")))))

    @Test fun settleMatch_ignoresPeopleIOwe() = assertNull(PeopleMath.settleMatch(m("5.31"), null,
        listOf(PeopleMath.SettleCandidate("p1", "Jun Wei", m("-5.31")))))
}
```

- [ ] **Step 2: Run** `.\gradlew.bat testDebugUnitTest --tests "*PeopleMathTest*" -q`. Expected: FAIL, `PeopleMath` unresolved.
- [ ] **Step 3: Implement `PeopleMath` and `Balance`** in `PeopleMath.kt`; make `RepaymentMatcher.words` internal and reuse it.
- [ ] **Step 4: Run** the same command plus `*RepaymentMatcherTest*`. Expected: PASS.
- [ ] **Step 5: Stage.**

### Task 3: PeopleRepository and split changes

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/data/PeopleRepository.kt`
- Create: `app/src/main/java/com/expensetracker/app/data/QrStore.kt`
- Modify: `app/src/main/java/com/expensetracker/app/data/SplitRepository.kt`
- Modify: `app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: Task 1 DAO, Task 2 `PeopleMath`, `Balance`.
- Produces:
  - `data class PersonSummary(val person: SplitPersonEntity, val balance: Balance, val hasOpen: Boolean)`
  - `data class PersonDetail(val person: SplitPersonEntity, val balance: Balance, val owedToMe: List<OpenDebtView>, val iOwe: List<OwedItemEntity>, val settleSuggestion: ExpenseEntity?)`
  - `@Singleton class PeopleRepository @Inject constructor(db: ExpenseDatabase, splitDao: SplitDao, expenseDao: ExpenseDao, splitRepository: SplitRepository, qrStore: QrStore)`:
    - `fun observePeople(): Flow<List<PersonSummary>>`
    - `fun observePerson(personId: String): Flow<PersonDetail?>`
    - `suspend fun addPerson(name: String): String` — returns the existing (revived if archived) person's id when `normalizedName` matches; else creates with `lastUsedAt = now`. Blank name throws `IllegalArgumentException("Enter a name.")`.
    - `suspend fun renamePerson(personId: String, name: String)` — throws `IllegalArgumentException("Someone already has that name.")` on a clash with another non-archived person.
    - `suspend fun archivePerson(personId: String)` — throws `IllegalStateException("Settle up with them first.")` when anything is open; deletes the QR file and paid owed items, sets `archived = true`, `qrPath = null`.
    - `suspend fun setQr(personId: String, uri: Uri)` / `suspend fun saveQrToGallery(personId: String): Uri`
    - `suspend fun addOwedItem(personId: String, description: String, amount: BigDecimal, itemDate: Long)`, `updateOwedItem(item: OwedItemEntity)`, `deleteOwedItem(id: String)`, `markOwedItemPaid(id: String)` — validation: description not blank, amount > 0. Each change clears the person's `suggestedSettleExpenseId`.
    - `suspend fun settleUp(personId: String)` — one transaction: close all open split debts via `SplitRepository.closeAllFor(personId, expense = null)` and mark all open owed items PAID with `paidAt = now`; clears the suggestion.
    - `suspend fun confirmSettleSuggestion(personId: String)` — re-read the expense and the current net; if the expense is missing, not usable (same rule as `isUsableRepayment`), or `amount != net`, clear the suggestion and return; else close everything and link the expense through `SplitRepository.closeAllFor(personId, expense)`.
    - `suspend fun dismissSettleSuggestion(personId: String)`
  - `class QrStore @Inject constructor(@ApplicationContext context: Context)`:
    - `fun importQr(personId: String, uri: Uri): String` — copy the bytes into `filesDir/qr/<personId>.img`, return the absolute path; decode bounds first and throw `IllegalArgumentException("That file isn't an image.")` if not an image.
    - `fun delete(path: String?)`
    - `fun saveToGallery(path: String, displayName: String): Uri` — MediaStore `Images.Media` insert, `RELATIVE_PATH = "Pictures/Koban"` on API 29+, `IS_PENDING` 1 then 0; on API 26–28 write to `Environment.DIRECTORY_PICTURES/Koban` and insert with `DATA` path. `displayName = "koban-<name>-qr.jpg"` with non-letters replaced by `-`. Re-encode as JPEG quality 95.
  - `SplitRepository` changes:
    - `internal suspend fun closeAllFor(personId: String, expense: ExpenseEntity?)` — uses existing private `close(debts, expense)` on `splitDao.getOpenDebtsFor(personId)`; if there are no open split debts and `expense != null`, still mark the expense used (`countedAmount = 0.00`).
    - `saveSplit`: match names with `PeopleMath.normalizedName` against `getAllPeopleIncludingArchived()`, store the trimmed name, set `archived = false` on a match; clear `suggestedSettleExpenseId` for every person whose debts the save changed.
    - `markPaid`, `confirmSuggestion`: clear that person's `suggestedSettleExpenseId`.
    - `suggestRepayment(receive)`: when the matcher returns nothing, build `SettleCandidate`s from non-archived people with open items (net from open split debts and open owed items), call `PeopleMath.settleMatch(receive.amount, receive.merchant, ...)`, and set that person's `suggestedSettleExpenseId = receive.id`.
  - Manifest: `<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />`

- [ ] **Step 1: Implement QrStore, PeopleRepository and the SplitRepository changes** with the signatures above.
- [ ] **Step 2: Run** `.\gradlew.bat assembleDebug testDebugUnitTest -q`. Expected: exit 0, all existing tests pass (`RepaymentMatcherTest`, `SplitMathTest` unchanged).
- [ ] **Step 3: Stage.**

### Task 4: People list screen

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/ui/viewmodel/PeopleViewModel.kt`
- Create: `app/src/main/java/com/expensetracker/app/ui/screens/PeopleScreen.kt`

**Interfaces:**
- Consumes: `PeopleRepository.observePeople()`, `addPerson(name)`, `SplitRepository.observeBills()`.
- Produces: `@Composable fun PeopleScreen(onBack: () -> Unit, onOpenPerson: (String) -> Unit, onOpenSplit: (String) -> Unit, viewModel: PeopleViewModel = hiltViewModel())`; `PeopleViewModel.query: StateFlow<String>`, `setQuery(String)`, `sections: StateFlow<List<Pair<PeopleMath.Group, List<PersonSummary>>>>`, `bills: StateFlow<List<SplitBillEntity>>`, `suspend fun add(name: String): String` (person id).

Layout (mockup option A, no QR thumbnails): back arrow and title "People", subtitle "Their payment QRs, and what you owe each other", search field "Search people", sections titled "You owe", "Owes you", "Everyone else" (skip empty ones), each row = 40dp circle with the initial (color from the person id hashed over `MoneyColors` red, blue, orange, purple, teal), name (titleSmall), status line from `PeopleMath.statusLine` coloured `gold` for YouPay, `received` for PaysYou, `onSurfaceVariant` otherwise; hairline divider; whole row clickable, 56dp min height. Extended FAB "Add person" (gold container, ink content) opens a dialog with one name field and "Add"; after add, navigate to the person. "Past splits" section at the end of the list, as in the old `DebtsScreen`. Empty state: "No people yet. Add someone, or split a bill to start."

- [ ] **Step 1: Build the screen and view model.** Search filters with `PeopleMath.normalizedName(query) in normalizedName(name)`.
- [ ] **Step 2: Run** `.\gradlew.bat assembleDebug -q`. Expected: exit 0.
- [ ] **Step 3: Stage.**

### Task 5: Person screen

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/ui/viewmodel/PersonViewModel.kt`
- Create: `app/src/main/java/com/expensetracker/app/ui/screens/PersonScreen.kt`

**Interfaces:**
- Consumes: Task 3 repository functions, `SplitRepository.repaymentCandidates`, `markPaid`, `confirmSuggestion`, `dismissSuggestion` (moved from `DebtsViewModel`), `EditExpenseDialog`'s date picker helpers for the item date.
- Produces: `@Composable fun PersonScreen(personId: String, onBack: () -> Unit, onOpenSplit: (String) -> Unit, viewModel: PersonViewModel = hiltViewModel())` reading `personId` from `SavedStateHandle["personId"]`.

Layout, top to bottom:
1. Top bar: back, the name (headlineSmall), overflow menu with "Rename" and "Delete person".
2. The koban QR frame (the one bold element): white card, 16dp padding, 24dp corners, a 4dp `gold` border plus a 9dp `gold` at 18% alpha outer ring, width 240dp, centered; the QR image loaded off the main thread with `BitmapFactory` (downsample to 1024px). Caption under the image is not shown. Tap the frame to replace the QR ("Replace QR" also in overflow). Empty state inside the frame: "Add their payment QR", tapping opens `PickVisualMedia(ImageOnly)`.
3. Primary button "Save QR to gallery" (full width, 50dp, gold container, ink text), hint below "Then open your bank app and pick it from the gallery". On API ≤ 28 request `WRITE_EXTERNAL_STORAGE` first. Snackbar "Saved to gallery. Open your bank app and pick it." Hidden when no QR.
4. Headline from `PeopleMath.headline` (titleLarge; amount colour as in the list) and "Settle up" text button when anything is open. Settle up opens a confirm dialog: title "Settle up with [Name]?", body listing counts ("Closes 2 split bill debts and 1 item you owe. Split bills it touches can't be edited after this."), buttons "Settle up" and "Cancel".
5. Settle suggestion card when present: "Possible settle up: RM 5.31 from JUN WEI, 20 Oct" with "Confirm" and "Not this" (same style as today's repayment suggestion).
6. Section "[Name] owes you" — the old Who owes me rows for this person: merchant, date, amount, "Mark paid" (with the existing repayment-candidate picker) and per-debt suggestion Confirm / Not this. Tapping the merchant opens the split.
7. Section "You owe [Name]" — owed items: description, date (`d MMM`), amount, "Mark paid"; tap a row to edit or delete it. "+ Add what I owe" opens a dialog: "What for" (required), "Amount" (> 0, decimal keyboard), date picker (today, not in the future), "Save".
8. Errors from the repository show as snackbars with the exception message.

- [ ] **Step 1: Build the screen and view model.**
- [ ] **Step 2: Run** `.\gradlew.bat assembleDebug -q`. Expected: exit 0.
- [ ] **Step 3: Stage.**

### Task 6: Navigation and removal of Who owes me

**Files:**
- Modify: `app/src/main/java/com/expensetracker/app/ui/navigation/Routes.kt`
- Modify: `app/src/main/java/com/expensetracker/app/ui/ExpenseTrackerNavHost.kt`
- Modify: `app/src/main/java/com/expensetracker/app/ui/screens/ExpensesScreen.kt`
- Modify: `app/src/main/java/com/expensetracker/app/ui/viewmodel/ExpensesViewModel.kt`
- Delete: `app/src/main/java/com/expensetracker/app/ui/screens/DebtsScreen.kt`, `app/src/main/java/com/expensetracker/app/ui/viewmodel/DebtsViewModel.kt`

**Interfaces:**
- Produces: `Routes.PEOPLE = "people"`, `Routes.PERSON = "people/{personId}"`, `fun person(id: String) = "people/${Uri.encode(id)}"`. Remove `Routes.DEBTS`.
- `ExpensesScreen`: parameter `onDebts` renamed `onPeople`; button text "People ($n)" when `n > 0` people have anything open, else "People". `ExpensesViewModel.openPeopleCount: StateFlow<Int>` from `PeopleRepository.observePeople()` counting `hasOpen`.

- [ ] **Step 1: Wire the routes and button; delete the old screen and view model.**
- [ ] **Step 2: Run** `.\gradlew.bat assembleDebug testDebugUnitTest -q`. Expected: exit 0, no references to `DebtsScreen`/`Routes.DEBTS` (`git grep -n "DEBTS\|DebtsScreen\|DebtsViewModel"` prints nothing).
- [ ] **Step 3: Stage.**

### Task 7: Phone check

- [ ] **Step 1: Back up the phone database** (`run-as com.expensetracker.app` copy of `databases/` to `D:\Projects\expense-tracker-backup-2026-10-20-pre-contacts`), and confirm the copy opens.
- [ ] **Step 2: Install** with `adb install -r`. Launch; confirm existing expenses and split debts are present (migration kept data).
- [ ] **Step 3: Walk the flow with sample data the owner approves:** open People, open a person with an open split debt, add "Test item RM 1.00", check the net line, add a QR from the gallery, tap "Save QR to gallery" and confirm the picture appears in Gallery > Koban, delete the test item. Do not Settle up real debts without the owner.
- [ ] **Step 4: Report** results to the owner; leave committing to them.
