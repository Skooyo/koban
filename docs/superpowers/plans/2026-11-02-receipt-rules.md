# Receipt Rules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Read split-bill receipts with on-device ML Kit OCR and a pure-Kotlin rule engine instead of Gemini.

**Architecture:** `ReceiptRules` (pure Kotlin, JVM-testable) turns OCR lines into the existing `ReceiptDraft` and decides whether the items add up to the printed total. `ReceiptReader` runs ML Kit and calls it. The photo step opens the ML Kit Document Scanner, with the plain camera as fallback. Gemini leaves the receipt path completely.

**Tech Stack:** Kotlin, Jetpack Compose M3, Hilt, ML Kit Text Recognition v2 (bundled), ML Kit Document Scanner (Play services), JUnit 4, org.json (already a dependency).

**Spec:** `docs/superpowers/specs/2026-11-02-receipt-rules-design.md`

## Global Constraints

- Reference implementation: `receipt-bench/spike/parse.py` (Python spike). Keyword lists, regexes and check order are ported from it unless a task says otherwise.
- Benchmark floor (spec): restaurant receipts ≥ 73% accepted and 0 wrong-not-flagged, measured on `receipt-bench/`.
- No receipt image, real receipt text, or SROIE data in the repo. `receipt-bench/` is git-ignored; unit tests use made-up receipts.
- Money is `BigDecimal`, scale 2, like the rest of the app. Malaysian date order is day first.
- Dependencies (exact): `com.google.mlkit:text-recognition:16.0.1` (bundled model), `com.google.android.gms:play-services-mlkit-document-scanner:16.0.0`. Add both to `gradle/libs.versions.toml`.
- Receipt photos are never kept: the camera file and the scanner JPEG are deleted after reading.
- Gemini: receipt code must not reference `GeminiClient`. `GeminiClient` itself stays (notification pre-fill uses it).
- Git: do not commit. Work on branch `feature/receipt-rules`; stage files and show the diff. The owner commits.
- No instrumented tests. No database change (so no phone DB backup is needed for this plan).
- Build/test: `$env:JAVA_HOME="<scratchpad>\jdk\jdk-17.0.20.1+1"; .\gradlew.bat testDebugUnitTest -q` and `assembleDebug`. Run one Gradle build at a time (owner's machine is small).

## Review Focus

1. An item name close to a keyword ("PHONE CASE 10.00", "EXCHANGE TEA") must stay an item; fuzzy label matching must not turn CASE into CASH. → Task 1 test `itemNameNearKeywordStaysItem`.
2. A time or date at a row end ("Time: 12:06 00", "Date 06/03 18") must not become an amount or an item. → Task 1 test `timeRowIsNotAnItem`.
3. Thousands separators ("TOTAL 1,234.00") survive the decimal repair. → Task 1 test `thousandsSeparatorKept`.
4. A photo with no text, or text with no amounts, gives `null` and the "Couldn't read this receipt" path, never an empty accepted draft. → Task 2 test `emptyOcrGivesNull`.
5. A free item ("0.00") or a zero charge row is not counted and does not break the check. → Task 2 test `zeroAmountsIgnored`.

---

### Task 1: ReceiptRules rows, repair and row rules

**Files:**
- Create: `app/src/main/java/com/expensetracker/app/parser/ReceiptRules.kt`
- Test: `app/src/test/java/com/expensetracker/app/parser/ReceiptRulesTest.kt`

**Interfaces:**
- Produces:
  - `data class OcrLine(val text: String, val left: Int, val top: Int, val right: Int, val bottom: Int)`
  - `internal fun ReceiptRules.rows(lines: List<OcrLine>): List<String>` — spec §2 (center within half the smaller height joins a row; parts joined left to right with one space).
  - `internal fun ReceiptRules.fixRow(row: String): String` — spec §3 amount repair, port of `fix_row`.
  - `internal fun ReceiptRules.normLabel(label: String): String` — spec §3 fuzzy labels. Kotlin has no `difflib`: use Levenshtein similarity `1 - dist / maxLen >= 0.75`, only for words of **5+ letters**, and only when the word's first letter equals the keyword's (EXCHANGE→CHANGE has the same similarity as AMNOLUNT→AMOUNT; the first letter separates them). 4-letter words such as CASE/CASH are too close; add the needed 4-letter OCR forms (`SERV`, `SERY`, `NETT`) as exact keywords instead.
  - `internal data class ParsedReceipt(val items: List<ReceiptItemDraft>, val subtotal: BigDecimal?, val serviceCharge: BigDecimal, val tax: BigDecimal, val discount: BigDecimal, val rounding: BigDecimal, val totals: List<BigDecimal>)`
  - `internal fun ReceiptRules.parse(rows: List<String>): ParsedReceipt` — spec §4 table, port of `parse_rows` (including the `names[-1]` nearest-row name rule and the "line total printed twice" skip).
  - `ReceiptItemDraft` and `ReceiptDraft` move here from `ReceiptParser.kt` unchanged (delete them there; `ReceiptParser.kt` itself goes in Task 4).

- [ ] **Step 1: Create branch** `git switch -c feature/receipt-rules`.
- [ ] **Step 2: Write failing tests** in `ReceiptRulesTest` with made-up receipts built from a helper `row(y: Int, vararg parts: Pair<Int, String>)` that emits `OcrLine`s 20 px tall at x positions:
  - `nameAndPriceLinesJoinIntoOneRow`: lines "NASI LEMAK" (x 10, y 100) and "8.50" (x 300, y 102) → `rows` = `["NASI LEMAK 8.50"]`.
  - `amountRepair`: `fixRow("TEH TARIK 2 x 2.50 5 00")` = `"TEH TARIK 2 x 2.50 5.00"`; `fixRow("SUBTOTAL. 79, 60")` = `"SUBTOTAL. 79.60"`; `fixRow("Rounding Adj : -0. 03")` = `"Rounding Adj : -0.03"`; `fixRow("ROTI 1O.50")` = `"ROTI 10.50"`.
  - `thousandsSeparatorKept`: `fixRow("TOTAL 1,234.00")` = `"TOTAL 1,234.00"`.
  - `timeRowIsNotAnItem`: rows `["Time: 12:06 00", "MEE GORENG 7.00", "TOTAL 7.00"]` → one item, "MEE GORENG", 7.00.
  - `fuzzyLabels`: `normLabel("SULTOTAL.")` contains `SUBTOTAL`; `normLabel("Total Amnolunt :")` contains `AMOUNT`; `normLabel("NLI T0TAL")` contains `TOTAL`.
  - `itemNameNearKeywordStaysItem`: rows `["PHONE CASE 10.00", "EXCHANGE TEA 3.00", "TOTAL 13.00"]` → 2 items.
  - `restaurantBill` (made-up, shaped like the spike's SROIE 107): rows `["TEH O AIS", "1X 2.50 2.50 SR", "NASI AYAM", "2X 9.00 18.00 SR", "TOTAL (EXCLUDING SST): 20.50", "SERV. CHARGE(10%): 2.05", "SST PAYABLE: 1.35", "TOTAL (INCLUSIVE OF SST): 23.90", "ROUNDING ADJ: 0.00", "TOTAL: 23.90", "CASH : 50.00", "CHANGE : 26.10"]` → items `[("TEH O AIS",1,2.50), ("NASI AYAM",2,18.00)]`, subtotal 20.50, serviceCharge 2.05, tax 1.35, rounding 0.00, totals `[23.90, 23.90]`.
  - `taxCodesAndDollar`: rows `["COKE", "1 X 2.10 2.10 ZRL", "MEAT + VEGE", "1 \$7.10", "\$7.10", "NETT TOTAL: \$9.20"]` → items 2.10 and 7.10 only (the repeated `$7.10` is skipped), totals `[9.20]`.
  - `nameless items`: rows `["4 3.50 14.00 SR-", "1 3.00 3.00 SR-", "TOTAL: 17.00"]` → two items named "Item", quantities 4 and 1.
  - `stopsAtSummary`: rows after `"GST SUMMARY AMOUNT(RM) TAX(RM)"` add nothing.
- [ ] **Step 3: Run** `.\gradlew.bat testDebugUnitTest --tests "*ReceiptRulesTest" -q` → FAIL (unresolved references).
- [ ] **Step 4: Implement** the Interfaces above by porting `parse.py` (`build_rows`, `fix_row`, `norm_label`, `parse_rows`, keyword lists). Keep each keyword list as one `Regex` constant, named as in the spike.
- [ ] **Step 5: Run** the same command → PASS. Then full `testDebugUnitTest -q` → PASS.
- [ ] **Step 6: Stage** `git add` the two files and the `ReceiptParser.kt` change; show `git diff --cached --stat`.

### Task 2: The check, the draft, merchant and date

**Files:**
- Modify: `app/src/main/java/com/expensetracker/app/parser/ReceiptRules.kt`
- Test: `app/src/test/java/com/expensetracker/app/parser/ReceiptRulesTest.kt`

**Interfaces:**
- Consumes: Task 1 `OcrLine`, `rows`, `parse`, `ParsedReceipt`.
- Produces:
  - `data class ReceiptRead(val draft: ReceiptDraft, val accepted: Boolean, val calculated: List<String>)` — `calculated` holds display phrases in order, e.g. `["10% service charge", "6% SST"]`; empty when nothing was calculated.
  - `fun ReceiptRules.read(lines: List<OcrLine>, now: Long = System.currentTimeMillis()): ReceiptRead?` — `null` when there is no item and no printed total.

Rules (spec §5): check only the **last** printed total; readings 1–6 in spec order, tolerance RM 0.01; then 5-sen rounding (total × 20 is whole, |diff| ≤ 0.02, difference goes to `rounding`). The matched reading sets the draft charges as the spec lists. `printedTotal` = last total, else subtotal, else null. `accepted` = a reading matched. Reading 6 computes with `setScale(2, HALF_UP)`; tax rate phrase is "6% SST" or "8% SST".

Merchant (spec §4): first row among the top 8 rows with 3+ letters that is not TAX INVOICE / RECEIPT / INVOICE / a row of mostly digits / a row matching `SDN|BHD|NO\.|JALAN|JLN|TAMAN|TEL|GST|SST|REG` … then tuned in Task 3. Date: first match of `dd/mm/yyyy`, `dd-mm-yyyy`, `dd.mm.yyyy`, `dd/mm/yy`, `dd MMM yyyy` / `dd MMM yy` (English month abbreviations), `yyyy-mm-dd`; local midnight millis; impossible date or a date after `now` → null.

- [ ] **Step 1: Write failing tests** (all made-up), each asserting `accepted`, the draft charges and `calculated`:
  - `reading1_pricesIncludeEverything`: items 10.00 + 5.00, SST row 0.85 "INCLUDED", total 15.00 → accepted, tax 0, serviceCharge 0.
  - `reading4_chargesAdded`: the Task 1 `restaurantBill` lines → accepted, serviceCharge 2.05, tax 1.35, printedTotal 23.90, `calculated` empty.
  - `reading5_taxAlreadyInPrices`: items 20.00, service 2.00, "SST 6% 1.25", total 22.00 → accepted, tax 0.
  - `reading6_missingServiceChargeCalculated`: items 79.60, discount 30.00, tax row lost, service row lost, rounding -0.03, total 57.80 → accepted, serviceCharge 4.96, tax 3.27, `calculated == listOf("10% service charge", "6% SST")`.
  - `fiveSenRounding`: items 7.72, total 7.70 → accepted, rounding -0.02.
  - `subtotalNeverAccepts`: items 295.00, "SUB TOTAL 295.00", "TOTAL 350.00", no charge rows → **not** accepted (no reading reaches 350.00; matching the subtotal must not count), printedTotal 350.00.
  - `lastTotalWins`: items 20.00, "TOTAL 20.00", "SERVICE CHARGE 2.00", "TOTAL 22.00" → accepted against 22.00 (reading 4), not against the earlier 20.00.
  - `noTotalNotAccepted`: items only → accepted false, printedTotal null.
  - `emptyOcrGivesNull`: `read(emptyList())` is null; lines "THANK YOU" only → null.
  - `zeroAmountsIgnored`: "FREE SAMBAL 0.00", "DISCOUNT 0.00" with items 12.00 and total 12.00 → accepted, one item.
  - `merchantAndDate`: top rows `["KEDAI MAKAN CONTOH", "SDN BHD (123456-X)", "NO. 1 JALAN CONTOH", "TEL: 03-1234 5678", "DATE: 05/10/2026 13:05"]` → merchant "KEDAI MAKAN CONTOH", date 2026-10-05 local midnight; `"DATE: 31/02/2026"` → null; a date after `now` → null.
- [ ] **Step 2: Run** the ReceiptRulesTest → FAIL.
- [ ] **Step 3: Implement** `ReceiptRead` and `read`.
- [ ] **Step 4: Run** ReceiptRulesTest, then all unit tests → PASS.
- [ ] **Step 5: Stage** and show the diff stat.

### Task 3: Benchmark gate and merchant tuning

**Files:**
- Test: `app/src/test/java/com/expensetracker/app/parser/ReceiptBenchmarkTest.kt`
- Modify (tuning only, if needed): `app/src/main/java/com/expensetracker/app/parser/ReceiptRules.kt`

**Interfaces:**
- Consumes: Task 2 `ReceiptRules.read`, `OcrLine`.
- Data (git-ignored): `receipt-bench/mlkit/<id>.json` = `{"lines":[{"text":..., "box":[left,top,right,bottom]}]}`; `receipt-bench/sroie/key/<id>.json` = `{"company","date","total"}`. Unit tests run with the `app/` module as working directory, so the folder is `File("../receipt-bench")`.

- [ ] **Step 1: Write the test** `restaurantBenchmark`: `Assume.assumeTrue(File("../receipt-bench/mlkit").isDirectory)`. For every key with a parseable total, run `read` on its ML Kit lines. A receipt is **accepted-correct** when `accepted` and `printedTotal == key total`; **wrong-not-flagged** when `accepted` and `printedTotal != key total`. Restaurant = company matches the `FOOD` regex in `receipt-bench/spike/eval_sroie.py` (copy it). Print a one-line report for all and for restaurant (rates as in the spike), plus merchant accuracy (draft merchant equals `company` after upper-case and whitespace collapse, or one contains the other) and date accuracy (equals key date). Assert restaurant accepted-correct ≥ 0.73 and restaurant wrong-not-flagged == 0.
- [ ] **Step 2: Run** `.\gradlew.bat testDebugUnitTest --tests "*ReceiptBenchmarkTest" -i` and read the printed report. If the gate fails, compare with `python -I receipt-bench/spike/eval_sroie.py receipt-bench/sroie receipt-bench/mlkit` (spike: 73.6% / 0) and fix the port until the numbers match or beat the spike.
- [ ] **Step 3: Tune the merchant rule** against the printed merchant accuracy. Stop when another change gains under 2 points. Record the final merchant and date accuracy in the ledger. Rerun the full unit tests → PASS.
- [ ] **Step 4: Hand-check items (controller step).** Pick 20 accepted restaurant receipts. Download their images to the scratchpad from `https://raw.githubusercontent.com/zzzDavid/ICDAR-2019-SROIE/master/data/img/<id>.jpg`, view each, and compare names, quantities and prices with the draft. Record wrong items per receipt in the ledger (not in the repo). Any wrong price on an accepted receipt is a finding to fix before Task 4.
- [ ] **Step 5: Stage** and show the diff stat.

### Task 4: ML Kit reader, Gemini out, Items step notes

**Files:**
- Modify: `gradle/libs.versions.toml`, `app/build.gradle.kts` (text-recognition dependency)
- Modify: `app/src/main/java/com/expensetracker/app/parser/ReceiptReader.kt`
- Delete: `app/src/main/java/com/expensetracker/app/parser/ReceiptParser.kt`, `app/src/test/java/com/expensetracker/app/parser/ReceiptParserTest.kt`
- Modify: `app/src/main/java/com/expensetracker/app/ui/viewmodel/SplitEditorViewModel.kt:52-80,160-215`
- Modify: `app/src/main/java/com/expensetracker/app/ui/screens/SplitEditorScreen.kt:200-216` (Items header)
- Modify: `app/src/main/java/com/expensetracker/app/ui/screens/SettingsScreen.kt:256-260`

**Interfaces:**
- Consumes: Task 2 `ReceiptRules.read`, `ReceiptRead`, `OcrLine`.
- Produces:
  - `ReceiptReader @Inject constructor(@ApplicationContext context: Context)`; `suspend fun read(imageUri: Uri): ReceiptRead?` — `InputImage.fromFilePath`, `TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)`, every `Text.Line` with a `boundingBox` → `OcrLine`; any exception → null. `hasKey()` is removed.
  - `SplitEditorState.readNote: String? = null` — an informational line (not error colored).

- [ ] **Step 1: Write the failing test** `itemsNoteText` in a new `SplitReadNoteTest`: a pure function `fun readNote(read: ReceiptRead): String?` in `SplitEditorViewModel`'s companion returns exactly:
  - accepted, nothing calculated: `"Matches the receipt total of RM 57.80."`
  - accepted with calculated: `"Matches the receipt total of RM 57.80 with a calculated 10% service charge and 6% SST."` (one calculated item: no "and")
  - not accepted, `printedTotal == null`: null (the view model shows the error message below instead).
  - not accepted with a total: null (the existing mismatch warning covers it).
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement**:
  - Dependency `com.google.mlkit:text-recognition:16.0.1`.
  - `ReceiptReader` as in Interfaces; delete `ReceiptParser.kt` and `ReceiptParserTest.kt`.
  - `readReceipt`: `null` → message `"Couldn't read this receipt. Add the items by hand."` (no Gemini branch). A read with `printedTotal == null` → message `"No total found on the receipt. Check the items."`. Otherwise `readNote = readNote(read)`, `message = null`. Draft-to-state mapping unchanged.
  - Items header: show `readNote` under the title in `onSurfaceVariant`; `message` stays error colored.
  - Settings Gemini text: delete the sentence "Receipt scanning also needs this key."
- [ ] **Step 4: Run** all unit tests and `assembleDebug` → PASS; `grep -rn "GeminiClient\|hasKey" app/src/main/java/com/expensetracker/app/parser/ReceiptReader.kt app/src/main/java/com/expensetracker/app/ui/viewmodel/SplitEditorViewModel.kt` → no match.
- [ ] **Step 5: Stage** and show the diff stat.

### Task 5: Document Scanner on "Take photo"

**Files:**
- Modify: `gradle/libs.versions.toml`, `app/build.gradle.kts` (scanner dependency)
- Modify: `app/src/main/java/com/expensetracker/app/ui/screens/SplitEditorScreen.kt:161-196` (`PhotoStep`)
- Modify: `app/src/main/java/com/expensetracker/app/ui/viewmodel/SplitEditorViewModel.kt:171-181` (`readReceipt` cleanup)

**Interfaces:**
- Consumes: Task 4 `readReceipt(uri)`.

- [ ] **Step 1: Implement** (UI wiring; no unit test, the phone check in Task 6 covers it):
  - Options: `GmsDocumentScannerOptions.Builder().setGalleryImportAllowed(false).setPageLimit(1).setResultFormats(RESULT_FORMAT_JPEG).setScannerMode(SCANNER_MODE_FULL).build()`.
  - "Take photo" calls `GmsDocumentScanning.getClient(options).getStartScanIntent(activity)`; on success launch with `ActivityResultContracts.StartIntentSenderForResult`; on failure (task failure or exception) run today's camera path (`newPhotoUri` + `TakePicture`). Keep both launchers.
  - Result: `GmsDocumentScanningResult.fromActivityResultIntent(data)?.pages?.firstOrNull()?.imageUri` → `vm.readReceipt(uri)`. Cancel → nothing.
  - `readReceipt` cleanup: after reading, also delete the read Uri's file when its scheme is `file` and its path is inside `context.cacheDir` (the scanner writes there). Never delete a gallery `content://` Uri.
- [ ] **Step 2: Run** `assembleDebug` and all unit tests → PASS.
- [ ] **Step 3: Stage** and show the diff stat.

### Task 6: Phone check (controller, with the owner)

- [ ] **Step 1:** Install the debug build on the owner's phone (`8T5XTCZHJBVK9LON`). No DB change, so no backup step.
- [ ] **Step 2:** Split a bill from 3 of the owner's receipts (any shop) through "Take photo". Pass: no crash; the scanner opens; no receipt shows "Matches the receipt total" with a wrong item; the photo is gone afterwards (`run-as com.expensetracker.app find cache -name "*.jpg"` lists nothing). Do not save receipt text or photos anywhere in the repo.
- [ ] **Step 3:** Check "Choose from gallery" once and "Type items instead" once.
- [ ] **Step 4:** Report to the owner; the owner decides on the commit.
