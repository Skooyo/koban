# Flutter milestone 5b: receipt reading — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the split editor the 0.1.1 receipt reading: take a photo with the ML Kit document scanner (camera if the scanner is not available) or choose one from the gallery, read it on the phone with ML Kit text recognition and the ported `ReceiptRules`, read it at the same time with Claude through the `read-receipt` function when the phone has a device token, choose the read with the ported rule, and offer `Read again with Claude`.

**Architecture:** Two small interfaces keep the device out of the tests: `ReceiptOcr` (ML Kit text lines → `OcrLine`) and `ReceiptPhotos` (document scanner with camera fallback). `ReceiptReader` runs `ReceiptRules.read` on the OCR lines. `ReceiptCloudClient.read` (plan 5a's class) shrinks the photo natively (a port of the 0.1.1 `shrink`, over the `device` channel) and posts it with the device token. `SplitEditorViewModel` gets the `reading` step and the reading fields of 0.1.1 `SplitEditorViewModel.kt`; it uses `chooseReceiptRead` from `koban/lib/rules/receipt_cloud.dart` (milestone 1).

**Tech Stack:** Flutter 3.50.0 / Dart 3.14.0; plan 5a. New pub packages: `google_mlkit_text_recognition` (flutter-ml.dev; Android uses `com.google.mlkit:text-recognition:16.0.1`, the 0.1.1 version; `TextLine` has `boundingBox` and `angle`; verify version at Task 1) and `google_mlkit_document_scanner` (Android uses `play-services-mlkit-document-scanner:16.0.0`, the 0.1.1 version; verify version at Task 1). `image_picker` is already in (plan 4c). No new Kotlin library.

**Spec:** `docs/superpowers/specs/2026-11-13-flutter-migration-design.md` (3 "ML Kit document scanner and text recognition", "The online receipt read", 6.7 item 5). Reference: `app/.../parser/ReceiptReader.kt`, `parser/ReceiptCloudClient.kt` (`read`, `shrink`), `ui/viewmodel/SplitEditorViewModel.kt` (lines 189 to 301, 410 to 465, 505 to 541), `ui/screens/SplitEditorScreen.kt` (`PhotoStep`, the `Reading` step, `ItemsStep` top block, `FixSheet`), Kotlin tests `CacheFileTest.kt` and `SplitReadNoteTest.kt`, `supabase/functions/read-receipt/index.ts`.

**Order:** plan 2 of 3. Start on branch `feature/flutter-m5b` from `main` after plan 5a is merged. Plan 5c comes next.

**Decisions (the spec leaves these to the builder):**
1. **ML Kit through the flutter-ml.dev plugins.** They wrap the same Android libraries and versions as 0.1.1, so `ReceiptRules` gets the same lines. A native channel was rejected: it is more Kotlin for the same libraries and does not help iPhone (milestone 7 wants the plugin's iOS side or VisionKit).
2. **Photo shrink stays native** (`shrinkReceipt` on the `device` channel, a port of 0.1.1 `shrink`: longest side 1600 px, JPEG quality 85, EXIF rotation applied). Rejected: the `image` package (decoding a 12 MP photo in Dart takes seconds on a mid phone) and `image_picker` resize options (they do not cover the scanner output).
3. **Paths, not content URIs.** The scanner and `image_picker` give file paths in the app cache. The 0.1.1 rule "delete only our own files" becomes `isCacheFile(path, cacheDir)`: a file inside the app cache (after `..` is resolved), never the cache folder itself, never a `content://` text. So the gallery copy that `image_picker` makes in the cache is deleted too; the gallery original is never touched.
4. **A late read is ignored by a counter, not cancelled.** Dart futures cannot be cancelled. Each `readReceipt` call takes a new number; a result whose number is not the current one changes nothing (0.1.1 `readJob?.cancel()`).

**Not in this plan:** the updater (plan 5c). The iPhone VisionKit scanner (milestone 7).

## Global Constraints

- `flutter` means `D:/flutter/bin/flutter`, `dart` means `D:/flutter/bin/dart`; run them from `koban/`. Gradle: `cd koban/android && JAVA_HOME=D:/jdk-17 ./gradlew.bat --max-workers=2 :app:testDebugUnitTest`.
- Commit steps: the controller runs them. The implementer stops after the last verification step and reports the changed files.
- Run at most one Gradle or Flutter build or test run at a time.
- Each task ends with `flutter analyze` → "No issues found!" and `flutter test` → "All tests passed!"; when Kotlin changed, also the Gradle command → BUILD SUCCESSFUL.
- `git diff main -- app/ gradle/ supabase/` stays empty.
- No test calls the real `read-receipt` function or ML Kit. Dart tests use `MockClient` (plan 5a `FakeBackend`), a fake `ReceiptOcr` and a fake `ReceiptPhotos`.
- No secret value in the repository, a fixture or a log. Never log the photo, the token or the reply body; 0.1.1 debug logs (`KobanCloud`, `KobanOcr`) are not ported. Receipt texts in tests are synthetic (`Kedai Contoh`, `Nasi lemak`, `Teh ais`).
- The `online_features` setting gates the Claude read: with it off, `read` sends nothing and gives `Turn on online features in Settings to read with Claude.`.
- `read-receipt` contract, as 0.1.1: `POST <supabaseUrl>/functions/v1/read-receipt`, headers `Authorization: Bearer <device token>` and `Content-Type: image/jpeg`, body the JPEG bytes (2 MB at most), no `apikey` header; timeout 90 s (Claude 60 s → function 70 s → app 90 s).
- UI text is copied byte for byte from `SplitEditorScreen.kt`, `SplitEditorViewModel.kt` and `ReceiptCloudClient.kt`.
- Doc comments and test names in ASD-STE100 Simplified Technical English.

## Review Focus

1. A device token that the server cancelled (401): the token must go from the phone, the read must still show the phone's read with `Read on the phone. Your invite code is no longer active.`, and Settings must show the invite field again. Pinned in Task 2.
2. Back while `Reading the receipt…` shows: a read that ends later must not move the editor to the Items step or fill items. Pinned in Task 2.
3. The photo file: kept for `Read again with Claude` while the Items step is open, deleted when the Items step closes and when the editor closes; a file outside the app cache is never deleted. Pinned in Tasks 1 and 2.
4. `Read again with Claude` shows only with online access, a kept photo and no Claude run for that photo (a Claude run that used a read counts). Pinned in Task 2.
5. Two fast taps on `Take photo` open one scanner. Pinned in Task 3.

---

### Task 1: OCR, photo sources, photo shrink and the Claude read

**Files:**
- Modify: `koban/pubspec.yaml` (`flutter pub add google_mlkit_text_recognition google_mlkit_document_scanner`), `koban/android/app/src/main/kotlin/io/github/skooyo/koban/DeviceChannel.kt`, `koban/lib/device/device_control.dart`, `koban/lib/online/receipt_cloud_client.dart`, `koban/lib/app/app_services.dart` (add `receiptReader`, `receiptPhotos`, `cacheDir`)
- Create: `koban/lib/receipts/receipt_reader.dart`, `koban/lib/receipts/receipt_photos.dart`
- Test: `koban/android/app/src/test/kotlin/io/github/skooyo/koban/ShrinkReceiptTest.kt`, `koban/test/receipts/receipt_reader_test.dart`, `koban/test/receipts/cache_file_test.dart`, `koban/test/online/receipt_cloud_client_test.dart` (add tests), `koban/test/support/harness.dart` (fakes)

**Interfaces:**
- Consumes: `ReceiptRules.read(List<OcrLine>, {int? now})`, `OcrLine`, `ReceiptRead`, `CloudRead`, `CloudReadOk`, `CloudReadFailed`, `ReceiptCloudClient.parse` from `rules/receipt_cloud.dart` (milestone 1; import it with a prefix, the online class has the same name); `ReceiptCloudClient(OnlineServices)`, `isNoConnection`, `FakeBackend` (plan 5a); `AppServices.pickImage` (plan 4c).
- Produces:
  - Channel `io.github.skooyo.koban/device` adds `shrinkReceipt {path: String}` → `ByteArray` or null (port of `ReceiptCloudClient.shrink` with `BitmapFactory.decodeFile` and `ExifInterface(path)`; runs on the plugin executor).
  - `DeviceControl.shrinkReceipt(String path) → Future<Uint8List?>`.
  - `receipt_reader.dart`: `abstract interface class ReceiptOcr { Future<List<OcrLine>> lines(String path); }`; `class MlKitReceiptOcr implements ReceiptOcr` — a new `TextRecognizer(script: TextRecognitionScript.latin)` per call, closed in `finally`; one `OcrLine` per `TextLine` of each block: `text`, `boundingBox` left/top/right/bottom rounded to int, `angle ?? 0`. `class ReceiptReader { ReceiptReader(ReceiptOcr ocr, {required int Function() now}); Future<ReceiptRead?> read(String path); }` — `ReceiptRules.read(lines, now: now())`; any error → null (0.1.1).
  - `receipt_photos.dart`: `abstract interface class ReceiptPhotos { Future<String?> scan(); }`; `class PhoneReceiptPhotos implements ReceiptPhotos` — `DocumentScanner(options: DocumentScannerOptions(documentFormats: {DocumentFormat.jpeg}, mode: ScannerMode.full, pageLimit: 1, isGalleryImport: false))`, the first image path; a cancel gives null; a scanner error (no Play services, no activity) falls back to `ImagePicker().pickImage(source: ImageSource.camera)`. `bool isCacheFile(String path, String cacheDir)`; `Future<void> deleteIfCache(String? path, String cacheDir)`.
  - `ReceiptCloudClient.read(String path, String deviceToken) → Future<CloudRead>` with the 0.1.1 texts: `notReachable = 'Claude was not reachable.'`, `couldNotRead = "Claude could not read this receipt. This used 1 of today's reads."`. Online off → `CloudReadFailed(onlineOff)`; shrink null → `CloudReadFailed(notReachable)`; 200 → `parse(body)` → `CloudReadOk(read, readsLeftToday >= 0 ? it : null)`, unreadable → `CloudReadFailed(couldNotRead, usedRead: true)`; 401 → `CloudReadFailed('Your invite code is no longer active.', tokenRevoked: true)`; 429 → `limit` `all` `Koban reached today's Claude limit.`, `code` `Your invite code used all its Claude reads for today.`, else `You used your 10 Claude reads for today.`; 502 and 504 → `CloudReadFailed(couldNotRead, usedRead: true)`; other status, no connection or timeout → `CloudReadFailed(notReachable)`. The constructor gets `Future<Uint8List?> Function(String path) shrink` (default `DeviceControl().shrinkReceipt`).
  - `AppServices`: `receiptReader` (`ReceiptReader(MlKitReceiptOcr(), now:)`), `receiptPhotos` (`PhoneReceiptPhotos()`), `cacheDir` (`getTemporaryDirectory().path`, read in `start`). Harness: `testServices(..., ReceiptOcr? ocr, ReceiptPhotos? photos, String? cacheDir)` with `FakeReceiptOcr(Map<String, List<OcrLine>> byPath)` and `FakeReceiptPhotos(List<String?> answers)` (counts calls).

- [ ] **Step 1: Write the failing tests.**

```kotlin
// ShrinkReceiptTest — Robolectric @Config(sdk = [35]), @GraphicsMode(GraphicsMode.Mode.NATIVE); FakeMessenger, direct executor
@Test fun aLargePhotoBecomes1600PixelsOnTheLongSide() {
    // write a 4000 x 3000 JPEG to cacheDir/big.jpg
    val bytes = messenger.call(DEVICE, "shrinkReceipt", mapOf("path" to big.path)) as ByteArray
    val b = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    assertEquals(1600 to 1200, b.width to b.height)
}
@Test fun aPhotoWithExifRotationComesUpright() { /* 4000 x 3000 with TAG_ORIENTATION ROTATE_90 → 1200 x 1600 */ }
@Test fun aSmallPhotoKeepsItsSize() { /* 800 x 600 → 800 x 600 */ }
@Test fun aFileThatIsNotAnImageGivesNull() { /* text file → null */ }
```

```dart
// cache_file_test.dart — port of CacheFileTest.kt (5 cases); cache = p.join(tmp, 'cachetest')
test('a file inside the cache is ours', () => expect(isCacheFile(p.join(cache, 'mlkit', 'scan.jpg'), cache), true));
test('a content address is never ours', () => expect(isCacheFile('content://media/external/images/1', cache), false));
test('a file outside the cache is not ours', ...);
test('a path that climbs out with .. is not ours', () => expect(isCacheFile(p.join(cache, '..', 'other', 'scan.jpg'), cache), false));
test('the cache folder itself is not ours', ...);

// receipt_reader_test.dart
test('the reader gives the rules read of the OCR lines', ...);
  // FakeReceiptOcr lines of a synthetic receipt (Kedai Contoh; Nasi lemak 20.00; Teh ais 4.00; TOTAL 24.00) → read == ReceiptRules.read(same lines, now: T) by draft values; accepted true
test('an OCR error gives null', ...);

// receipt_cloud_client_test.dart
test('a good Claude read gives the items and the reads left', () async {
  // shrink → Uint8List.fromList([1, 2, 3]); backend.on('POST', '/functions/v1/read-receipt', → 200 with items, total, readsLeftToday 7)
  final r = await client.read('/cache/r.jpg', 'test-device-token') as CloudReadOk;
  expect(r.readsLeft, 7);
  final req = backend.requests.single;
  expect(req.headers['authorization'], 'Bearer test-device-token');
  expect(req.headers['content-type'], 'image/jpeg');
  expect(req.headers.containsKey('apikey'), false);
  expect(req.bodyBytes, [1, 2, 3]);
});
test('each failure gives the 0.1.1 reason and flags', ...);
  // 401 → tokenRevoked true; 429 {"limit":"all"} / {"limit":"code"} / {} → the 3 texts; 502 and 504 → couldNotRead, usedRead true;
  // 200 with bad JSON → couldNotRead, usedRead true; 500 → notReachable, usedRead false; ClientException → notReachable
test('a photo that cannot be opened sends nothing', ...); // shrink → null → notReachable, 0 requests
test('with Online features off the photo is not sent', ...); // 0 requests, why == onlineOff
```

- [ ] **Step 2: Run.** `flutter test test/receipts/ test/online/receipt_cloud_client_test.dart` → FAIL; Gradle test → FAIL.
- [ ] **Step 3: Implement.** Add the packages; record their versions in the task report. Check in the plugin source how `scanDocument` reports a cancel, and map only a cancel to null. If native graphics does not run under Robolectric on Windows, keep the 4 Kotlin tests with `@Ignore("needs native graphics")` and report it; the owner device check 5 covers the shrink.
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (12 new tests). Gradle test → BUILD SUCCESSFUL (4 new tests).
- [ ] **Step 5: Commit.** "Add receipt OCR, the photo sources and the Claude read".

### Task 2: Reading in the split editor view model

**Files:**
- Modify: `koban/lib/screens/split/split_editor_view_model.dart` (the plan 4c file)
- Test: `koban/test/screens/split_editor_view_model_test.dart` (add tests), `koban/test/screens/split_read_note_test.dart`

**Interfaces:**
- Consumes: Task 1; `chooseReceiptRead` (milestone 1); `SecretStore.deviceToken` / `setDeviceToken` (plan 5a); `SplitEditorViewModel`, `SplitEditorState`, `SplitStep` (plan 4c Task 2).
- Produces:
  - `enum SplitStep { photo, reading, items, people, assign, link, summary }`.
  - `SplitEditorState` adds the 0.1.1 fields `String? readNote`, `String? readSource`, `bool onlineAccess` (device token stored and Online features on), `bool canReadAgain`, `int? readsLeft`, `bool readingAgain`.
  - `SplitEditorViewModel` adds `Future<void> readReceipt(String path)`, `Future<void> readAgainWithClaude()`, `static String? readNote(ReceiptRead read)`; `back()` from `reading` → `photo` (drops the photo, Decision 4); `next()` from `items` drops the photo; `dispose()` drops the photo. Dropping deletes the file only through `deleteIfCache`.
  - `readReceipt` rules (0.1.1): drop the old photo; keep `path`; `claudeRan = false`; step `reading`; run the phone read and, when a token is stored, the Claude read at the same time (`Future.wait`); `claudeRan` = `CloudReadOk` or `usedRead`; `tokenRevoked` → `setDeviceToken('')`; `chooseReceiptRead` → `showRead`. `showRead` fills merchant, bill time (`dateMillis` or the old time), printed total, items (`AmountFormatter.formatDisplay`), charges (blank for 0), `readNote`, `readSource`, `readsLeft`, and `message`: no read → `Couldn't read this receipt. Add the items by hand.`; no printed total → `No total found on the receipt. Check the items.`.
  - `readAgainWithClaude`: only with a kept photo and not while `readingAgain`; no token → `readSource` `Enter an invite code in Settings first.`; `CloudReadOk` → `showRead(read, '✓ Read by Claude' + ' · $n reads left today' when known)`; `CloudReadFailed` → `readSource` = `why` (not prefixed), `usedRead` sets `claudeRan`, `tokenRevoked` removes the token.
  - `canReadAgain` = `onlineAccess && photo kept && !claudeRan`.

- [ ] **Step 1: Write the failing tests.** OCR lines L (accepted read, total 24.00); Claude reply C (accepted, total 24.00, `readsLeftToday` 7); photo `p.join(cacheDir, 'scan.jpg')` written by the test.

```dart
// split_read_note_test.dart — port of SplitReadNoteTest.kt (1 case, 5 asserts, same texts)
test('the read note names the receipt total and the calculated charges', () {
  expect(SplitEditorViewModel.readNote(read(true, '57.80')), 'Matches the receipt total of RM 57.80.');
  expect(SplitEditorViewModel.readNote(read(true, '57.80', ['10% service charge', '6% SST'])),
      'Matches the receipt total of RM 57.80 with a calculated 10% service charge and 6% SST.');
  // + '6% SST' only; not accepted with no total → null; not accepted with a total → null
});

// split_editor_view_model_test.dart
test('with a token the phone and Claude read together and the Claude read wins', ...);
  // step items; items Nasi lemak / Teh ais; readSource '✓ Read by Claude · 7 reads left today'; canReadAgain false
test('without a token only the phone reads and no request is sent', ...); // readSource null, backend.requests empty
// Review Focus 1
test('a cancelled token is removed and the phone read is shown', ...);
  // 401 → secrets device_token ''; readSource 'Read on the phone. Your invite code is no longer active.'; state.onlineAccess false
test('a photo with nothing readable asks for the items by hand', ...); // OCR [] and no token → message "Couldn't read this receipt. Add the items by hand."
// Review Focus 2
test('back during reading ignores the late result', () async {
  // OCR answers after a Completer; readReceipt(path); back() → step photo; complete the OCR
  expect(vm.state.step, SplitStep.photo);
  expect(vm.state.items, isEmpty);
  expect(File(path).existsSync(), false);
});
// Review Focus 4
test('read again is offered only after a phone-only read with online access', ...);
  // Claude 500 (notReachable, not used) → canReadAgain true; readAgainWithClaude with reply C → items from Claude, canReadAgain false
  // Claude 504 (used) → canReadAgain false
// Review Focus 3
test('the photo stays while the items show and goes when the items step closes', ...);
  // after the read: file exists; next() → file gone
test('closing the editor deletes the kept photo', ...);
test('a photo outside the cache is never deleted', ...); // path in another temp folder → still exists after next() and dispose()
```

- [ ] **Step 2: Run.** `flutter test test/screens/split_editor_view_model_test.dart test/screens/split_read_note_test.dart` → FAIL.
- [ ] **Step 3: Implement.** Keep every plan 4c rule; `back()` and `next()` change only for `reading` and `items` as above.
- [ ] **Step 4: Run.** `flutter analyze`; `flutter test` → PASS (10 new tests).
- [ ] **Step 5: Commit.** "Read receipts in the split editor".

### Task 3: Receipt steps on the split editor screen

**Files:**
- Modify: `koban/lib/screens/split/split_editor_screen.dart` (and its steps file from plan 4c), `koban/lib/app/online_placeholder.dart` (remove `OnlineFeature.receiptReading`)
- Test: `koban/test/screens/split_editor_test.dart` (replace the placeholder test, add tests)

**Interfaces:**
- Consumes: Task 2; `AppServices.receiptPhotos`, `AppServices.pickImage` (plan 4c).
- Produces (texts from `SplitEditorScreen.kt`):
  - Photo step: `Take photo` → `receiptPhotos.scan()`; `Choose from gallery` → `pickImage()`; a path → `readReceipt(path)`; null → nothing. Both buttons are off while a pick is open (Review Focus 5). The online line uses `state.onlineAccess`.
  - Reading step: a centered progress indicator and `Reading the receipt…`; the step bar shows step 1 of 6 (as `photo`); Back returns to the photo step.
  - Items step top block, in this order: `readSource` with a check icon in primary color; the mismatch card; `message` in error color; `readNote` only when there is no mismatch.
  - Fix sheet: while `readingAgain` only a progress indicator and `Reading with Claude… about 10 seconds`; when `canReadAgain`, an outlined button `Read again with Claude` with the line `Sends the photo to Koban's server` + ` · $n reads left today` when known.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('Take photo reads the scanned receipt and shows the items', ...);
  // FakeReceiptPhotos ['<cache>/scan.jpg'], no token → 'Reading the receipt…' → 'Matches the receipt total of RM 24.00.', 'Nasi lemak'
testWidgets('Choose from gallery reads the picked photo', ...);
testWidgets('a cancelled scan stays on the receipt step', ...); // answers [null] → 'Start with the receipt'
// Review Focus 5
testWidgets('two fast taps on Take photo open one scanner', ...); // FakeReceiptPhotos.calls == 1
testWidgets('the Claude line shows above the items', ...); // '✓ Read by Claude · 7 reads left today'
testWidgets('the fix sheet offers Read again with Claude and shows the wait', ...);
  // phone read with a 0.50 gap, Claude 500 → 'Fix' → 'Read again with Claude', 'Sends the photo to Koban's server'; tap → 'Reading with Claude… about 10 seconds'
testWidgets('Back on the reading step returns to the receipt step', ...);
```

- [ ] **Step 2: Run.** `flutter test test/screens/split_editor_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, one at a time.** `flutter analyze`; `flutter test` → PASS (7 new tests). Gradle test → BUILD SUCCESSFUL. `flutter build apk --debug` → the APK exists. Do not install it.
- [ ] **Step 5: Check.** `grep -rn "OnlineFeature\." koban/lib` → only `updates` (Settings). `git diff --stat main -- app/ gradle/ supabase/` → empty. `git grep -n "eyJ\|sb_publishable_" -- koban/` → nothing.
- [ ] **Step 6: Commit.** "Add the receipt scan, the reading step and Read again with Claude".

## Known limits

- The APK grows by the ML Kit text model (about 65 MB in 0.1.1, `docs/RELEASING.md` section 8); the scanner comes from Play services and adds little.
- On a phone without Play services the scanner is not there, and `Take photo` opens the camera, as in 0.1.1.
- The scanner, the camera fallback, the gallery pick, the shrink and a real Claude read first run in the owner device checks at the end of plan 5c.
