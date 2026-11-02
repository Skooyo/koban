# Receipt scanning without an LLM

Date: 2026-11-02. Status: reviewed; owner decided Gemini (removed) and the scanner (yes); waiting for the owner's approval.

## Why

- Split billing reads a receipt photo with Gemini. Gemini is not deterministic: the same photo can give different items. It also needs an API key, costs money per call, and sends the receipt to Google.
- The owner may publish Koban. The regex-confirm work (2026-10-25) already took the LLM out of notification capture. Receipts are the last place that needs one.
- A spike on 2026-11-02 showed that on-device OCR plus rules is good enough (numbers below).

## What changes, in one paragraph

`ReceiptReader` stops calling Gemini. It runs Google ML Kit text recognition on the phone, then a new pure-Kotlin rule engine, `ReceiptRules`, turns the OCR lines into the same `ReceiptDraft` the Items step already uses. The rules also check the result: when the items plus charges equal the printed total, the draft is complete. When they do not, the Items step shows its existing mismatch warning and the owner fixes the list. Nothing else in the split flow changes.

## Spike results (evidence for this design)

Data: 625 public Malaysian receipts (SROIE, ICDAR 2019; flatbed scans from 2018). OCR: ML Kit Latin, bundled model, on the owner's Xiaomi 15T. Rules: `receipt-spike/tools/parse.py` (Python, throwaway).

| | Restaurant (144) | All shops (625) |
|---|---|---|
| Items add up to the printed total (accepted) | 73.6% | 54.6% |
| Mismatch shown to the owner | 26.4% | 44.3% |
| Wrong and not flagged | 0% | 1.1% |
| Printed total found | 88.9% | 81.0% |

OCR time: median 145 ms per receipt, max 461 ms. With perfect OCR text the same rules accept 83% of restaurant receipts, so the remaining gap is mostly OCR, not rules.

What the numbers measure: SROIE labels the total, not the items. "Accepted" means the item prices plus charges equal the last printed total, and that total equals SROIE's true total. So the item amounts of an accepted receipt add up to the real bill, and tax counted twice cannot pass. Item names and quantities were only spot-checked (4 receipts, all correct apart from OCR typos such as "TEA POI BIG"). "Wrong and not flagged" means accepted while the total differs from SROIE's true total.

The spike data is in `receipt-bench/` in the repo, git-ignored: SROIE keys and ground-truth text (`sroie/`), the ML Kit output for all 626 receipts (`mlkit/`), and the spike scripts (`spike/`). Images are not kept; they can be downloaded again from github.com/zzzDavid/ICDAR-2019-SROIE (`data/img`).

## Goals

1. Same photo, same items, every time. No network call to read a receipt.
2. A restaurant receipt the owner photographs flat and in focus usually needs no edits (target: the spike's 73% or better on the benchmark below).
3. A wrong read is visible: the Items step flags every receipt whose items do not add up to the printed total.
4. Reading takes under 1 second after the photo.

## Non-goals

- Uneven item splits, multi-currency, or non-Latin item names (unchanged from the split-billing design).
- A screen to fix OCR line by line (tap a line to add it as an item). Maybe later, if the 26% flagged rate hurts in practice.
- Learning per-shop layouts.
- Grocery and hardware receipts get the same rules but no tuning.

## Anti-goals (a failure even if it works)

- A receipt accepted as matching when its items are wrong. The spike had 0 of these on restaurant receipts; keep it at 0.
- Tax counted twice: a receipt whose item prices already include SST/GST, read as items + tax.
- A real receipt from the owner, or a SROIE image, committed to the repo. Unit tests use made-up receipts only.
- A crash or a blank Items step when OCR finds nothing. The owner can always type the items.

## How it works

### 1. OCR

- Library: ML Kit Text Recognition v2, Latin script, **bundled** model (`com.google.mlkit:text-recognition`). Bundled pins the model version inside the APK, so a Google Play services update cannot change results (goal 1), and it works on first use without a download. Cost: about 4 MB per ABI. (Claude's call.)
- Input: the photo Uri through `InputImage.fromFilePath` (it applies the EXIF rotation). The photo is still deleted after reading, as today.
- Output to the rules: every `Text.Line` as `OcrLine(text, left, top, right, bottom)`. Blocks and elements are not used.

### 2. Rows

Receipts print the name on the left and the price on the right, and ML Kit often returns them as separate lines. Sort lines by vertical center. A line joins an existing row when its center is within half the smaller line height of the row's center. Join the parts of a row left to right with a space.

### 3. Row repair

Before matching, fix the OCR damage seen in the spike, only on the amount at the end of a row:
- `14 00`, `79, 60`, `-0. 03`, `79,60` become `14.00`, `79.60`, `-0.03`, `79.60`.
- `O` or `o` between digits becomes `0` (`1O.50`).

Labels are matched fuzzily: each label word of 4+ letters is replaced by the closest word from a fixed vocabulary (TOTAL, SUBTOTAL, AMOUNT, SERVICE, CHARGE, ROUNDING, DISCOUNT, CHANGE, CASH, ...) at similarity 0.75 or more, so `SULTOTAL`, `T0TAL`, `Amnolunt` still match. The original text is kept for item names.

### 4. Row rules

A row "has an amount" when it ends with a money amount, optionally followed by a tax code (`SR`, `ZRL`, `SR-`, `*`) . `RM` and `$` prefixes are allowed. Rows are read top to bottom:

| Row label matches | Result |
|---|---|
| CHANGE, BAKI, SUMMARY, TAX CODE | Stop reading (payment and GST/SST summary follow) |
| Payment words (CASH, VISA, CARD, TNG, PAID, ...) | Skip; stop if a total was already seen |
| SUBTOTAL, TOTAL EXCL..., NET SALES | Subtotal; items end |
| SERVICE CHARGE, SVC, S/C, SERV CHG | Service charge (not SERVICE TAX); items end |
| TOTAL variants (GRAND TOTAL, NETT TOTAL, TOTAL AMOUNT, AMT DUE, JUMLAH, ...) | A printed total; items end |
| TOTAL QTY, TOTAL ITEMS, ITEM(S) | Ignored; items end |
| GST, SST, TAX, SERVICE TAX | Tax, unless the label says INCLUDED/INCL; items end |
| ROUNDING, ROUND ADJ | Rounding; items end |
| DISCOUNT, DISC, VOUCHER, LESS | Discount (absolute value); allowed inside items |
| anything else, while items have not ended | An item |

Item details:
- Quantity: `2 x 4.50`, `2 @ 4.50`, or a 1–2 digit number at the start of the name. Default 1. The amount at the row end is the line total (as `ReceiptItemDraft.price` already defines).
- Name: the row text without the trailing number columns. If that leaves no letters, use the nearest text row above (with 3+ letters, not a header such as TEL/DATE/TABLE/CASHIER). If there is none, the name is "Item".
- A negative amount inside items is a discount.
- A bare amount right under an item, equal to that item's amount, is the line total printed twice: skip it.

Merchant and date are new (the spike did not read them):
- Merchant: the first row in the top part of the receipt with 3+ letters that is not TAX INVOICE, RECEIPT, a company number, or an address line. The builder tunes this against the SROIE `company` field.
- Date: the first date found anywhere (`dd/mm/yyyy`, `dd-mm-yyyy`, `dd/mm/yy`, `dd MMM yyyy`, `yyyy-mm-dd`). Malaysian order is day first. An impossible or future date is null.

### 5. The check (decides "accepted")

Use the **last** printed total only; an earlier total skips rounding or charges. With s = sum of item prices, try these readings in order and stop at the first that equals the total within RM 0.01:

1. s (prices already include every charge)
2. s + rounding
3. s − discount + rounding
4. s + service charge + tax − discount + rounding
5. s + service charge − discount + rounding (tax printed but already in the prices)
6. As 4, but with a missing service charge calculated as 10% of (s − discount), and/or a missing tax calculated as 6% or 8% of (s − discount + service charge). This covers a charge row the OCR lost.

If none matches exactly and the total is a multiple of 0.05, a difference of up to RM 0.02 is accepted as 5-sen rounding (Malaysian rounding mechanism).

The reading that matched decides the draft charges, so the Items step total equals the printed total:
- Reading 1: service charge, tax and discount are 0 in the draft.
- Reading 5: tax is 0 in the draft.
- Reading 6: the calculated values go in the draft, and the message says which were calculated (for example "Service charge 10% and SST 6% were calculated").
- 5-sen rounding: the difference goes in the rounding field.
- No match: the charges go in as read, and the Items step shows its existing mismatch warning and "Add the difference as rounding".

`printedTotal` in the draft is the last printed total, or the subtotal when there is no total.

### 6. Screens

- Photo step (owner's decision): "Take photo" opens the ML Kit Document Scanner (`GmsDocumentScanning`) in place of the plain camera. It crops, straightens and cleans the photo, so phone photos look more like the flat scans the spike measured. Options: 1 page, JPEG result, gallery import off (the "Choose from gallery" button stays as it is). The scanner's JPEG is deleted after reading, like the camera photo today. If the scanner cannot start (no Play services module, or an error), fall back to the plain camera so the owner is never stuck. "Choose from gallery" and "Type items instead" are unchanged.
- Reading step: unchanged.
- Items step: unchanged, plus one new message line:
  - Accepted: "Matches the receipt total of RM 57.80."
  - Accepted with calculated charges (reading 6): "Matches the receipt total of RM 57.80 with a calculated 10% service charge and 6% SST." (Claude's call: the owner sees both facts in one line.)
  - No printed total found (about 11% of restaurant receipts in the spike): "No total found on the receipt. Check the items." The existing mismatch warning needs a printed total, so without this line a bad read would show nothing. (Claude's call.)
- OCR found no item and no total: Items step with "Couldn't read this receipt. Add the items by hand." The "needs a Gemini key" message goes away.
- Settings: the Gemini card no longer says receipt scanning needs the key.

### 7. Gemini (owner's decision: removed from receipts)

Receipt scanning never calls Gemini, not even as an option. `ReceiptParser.kt` (Gemini JSON) and its tests are deleted, and `ReceiptReader` no longer depends on `GeminiClient`. `GeminiClient` and the Gemini key stay, because the optional notification pre-fill (2026-10-25 design) still uses them. This replaces the 2026-10-25 line "Receipt scanning uses the same key".

## Code shape

- `parser/ReceiptRules.kt`: pure Kotlin, no Android types. `fun read(lines: List<OcrLine>): ReceiptRead`, where `ReceiptRead` holds the `ReceiptDraft`, whether it was accepted, and which charges were calculated. Same style as `PaymentRules`.
- `parser/ReceiptReader.kt`: ML Kit call → `ReceiptRules.read`. Keeps its `read(uri)` entry point for the view model and returns the draft plus the accepted/calculated info. `hasKey()` goes.
- `parser/ReceiptParser.kt` and its tests: deleted. `ReceiptItemDraft` and `ReceiptDraft` move to `ReceiptRules.kt` (or their own file) unchanged.
- `ui/screens/SplitEditorScreen.kt` `PhotoStep`: the scanner launcher, with the camera fallback.
- New dependencies: `com.google.mlkit:text-recognition` (bundled) and `com.google.android.gms:play-services-mlkit-document-scanner`.

## Testing

- Unit tests for `ReceiptRules` with **made-up** receipts written as `OcrLine` lists: one per rule row in the table above, each check reading 1–6, 5-sen rounding, the tax-included case (anti-goal), several TOTAL rows, name on the row above, the damaged amounts in section 3, and an empty OCR result.
- Benchmark: a JVM test that runs only when `receipt-bench/` exists reads `mlkit/*.json` and `sroie/key/*.json` and reports the accepted / flagged / wrong-not-flagged rates. It must reach at least 73% accepted and 0 wrong-not-flagged on restaurant receipts (the spike's restaurant filter is in `spike/eval_sroie.py`). (Claude's call: keeps the benchmark repeatable without committing third-party data.)
- Item check: hand-check the items of 20 accepted restaurant receipts against their images (names, quantities, prices). Record the result in the plan's ledger, not in the repo.
- On the phone: read 3 real receipts of the owner's (any shop; the owner has no restaurant receipts at hand). Pass: no crash, and no receipt marked as matching with wrong items. The accepted rate is not a gate here, because 3 receipts say little. Photos are not kept and the results are not saved to the repo. (Claude's call.)
- No instrumented tests (owner rule).

## Left to the builder

- Exact regex text and keyword lists, starting from the spike's `parse.py`.
- The merchant heuristic, tuned on the benchmark.
- How `ReceiptRead` carries the accepted flag and the calculated-charges text into `SplitEditorState`.
- Wording of the new messages, in Koban's voice.
