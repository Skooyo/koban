# Receipt reading: Claude first, phone rules as backup

Date: 2026-11-12. Status: approved by the owner; amended the same day to **Claude first, rules as backup** (ticket #4, reversed). Each section links to the ticket that holds the decision. Build step 1 (tilt fix) is done.

## Why

- Phone scans of real receipts often fail the receipt rules: the item prices shift one row down (tilt, section 1), and the OCR misreads digits ("3.00" as "300,", SST 7.65 as 7.63) that no rule can repair.
- Claude read all 5 test receipts that the rules failed on correctly. So friends with online access get Claude's read first; the rules stay for everyone else and for every case where Claude cannot run.

## What changes, in one paragraph

With online access, every scanned receipt goes to Claude while the phone rules read it at the same time. The photo goes to a Supabase Edge Function, which checks the friend's device token and daily limits, then forwards the photo to a separate service on the owner's Lightsail server. That service runs Claude (Haiku 5.5, Sonnet 5.5 once if Haiku's read does not add up) and returns receipt JSON. The app uses whichever read adds up, Claude's first. Without online access, offline, past a limit, or on a server error, the app uses the rules' read, which now also handles tilted scans and removes unit prices such as "(26.00/ea)" from item names.

## Rule: local and online features

Local features run on the phone and are open to everyone (expenses, payment capture, split bill, the receipt rules). Online features need Koban's servers and need **online access**, which today only an invite code gives. Claude reading is the first online feature; receipt scanning itself stays a local feature through the rules. The update check and the APK download stay open. (Ticket #30; terms in `GLOSSARY.md`.)

## Goals

1. The Menya Hanabi scan (captured 2026-11-12) is accepted by the rules with all 6 items correct.
2. The restaurant benchmark stays at 73% or more, with 0 wrong-and-not-flagged.
3. A friend with online access gets a correct read from Claude in about 10 seconds, including receipts the rules fail.
4. Nobody without an invite code can make Koban's servers call Claude.
5. The Claude bill cannot pass 150 reads a day.
6. Receipt scanning still works with no invite code and no internet (rules only).
7. A level scan never reads worse than before the tilt fix (`ReceiptLevelScanTest`).

## Non-goals

- A paid plan. Recorded only: a `plan` value on the account (`friend` / `paid`) can choose the limits later; the request format does not change (ticket #30, Out of scope on the map).
- An owner screen for invite codes (waits for real sign-in from the group tracker).
- Gemini (removed by the distribution map, ticket #11).

## 1. Tilt fix on the phone (ticket #7)

Evidence: on the owner's scan, every price sits about 60 px above its item name. ML Kit reports the angle of wide lines as about -3.0° to -3.6°. Names and prices are about 1,050 px apart, and tan(3.3°) × 1,050 ≈ 61 px. `rows()` joins lines only within half a line height (about 26 px). A throwaway test proved the fix: as is, not accepted; straightened, accepted with all items, SST 7.65 and total 135.15.

1. `OcrLine` gets `angle: Float = 0f`. `ReceiptReader` fills it from `Text.Line.angle`.
2. `straighten()`: take the median `angle` of lines wider than 300 px with a non-zero angle. Move each line's vertical center by `-cx · tan(angle)`, where `cx` is the line's horizontal center. Keep the line height. With no usable angle, change nothing (the SROIE benchmark data has no angles).
3. **Plain read first** (found on the second real scan): `read()` reads the lines as they are; it uses the straightened read only when the plain read does not add up and the straightened read does. ML Kit also reports small angles (+0.6° to +1.3°) on a level but curled receipt, and straightening that scan shifted every price one item down.
4. Item names: remove a trailing unit price `(x.xx/ea)`, allowing `{` or `(` at its start and a space in `e a` ("Kimisla (Large) {26.00/ea)" → "Kimisla (Large)").
5. Regression tests, both with the shop name, address, phone and invoice number changed:
   - `ReceiptTiltScanTest` (61 lines, tilted -3°): accepted; items 26.00, 24.00, 35.00, 34.00, 5.50, 3.00; SST 7.65; total 135.15; clean names.
   - `ReceiptLevelScanTest` (58 lines, level, OCR misreads 2 digits): not accepted; the 5 readable items keep their own prices; no "Qty" or "Subtotal" item.
6. Keep the debug-only `KobanOcr` log line in `ReceiptReader` for the next receipt that fails.

Status: built 2026-11-12; all unit tests pass; benchmark unchanged (restaurants 74.3%, 0 wrong-and-not-flagged).

## 2. Architecture (tickets #9, #28, #29)

```
phone ──HTTPS──▶ Supabase Edge Function (free, Singapore)
                   │  checks device token + daily limits in Postgres
                   │  holds the Lightsail URL and token as secrets
                   ▼
                 Lightsail (owner's server, Ireland): separate photo service
                   │  claude -p, Haiku 5.5, then Sonnet 5.5 once if needed
                   ▼
                 Claude
```

- **Supabase:** organization "Koban", project `koban`, free plan, `ap-southeast-1`. Created 2026-11-12; details and the database password are in `~/.koban/` on the owner's PC. A test streamed bodies up to 10 MB unchanged; 2 MB took 1.7 s there and back.
- **Keep-alive:** a daily cron job on the Lightsail server runs one small database read, so the free project does not pause after 7 quiet days. Not confirmed: whether Supabase objects to keep-alive pings. The free plan has no backups; accepted (only invite codes and counts).
- **Lightsail photo service:** separate from the owner's text endpoint (prompt-injection decision, amendment on ticket #9).
  - New system user `koban-receipt`, with no access to the other app's data folder.
  - Own systemd unit: `InaccessiblePaths=` that folder, `ProtectHome=yes`, `PrivateTmp=yes`, `NoNewPrivileges=true`, `MemoryMax=400M`, `MemorySwapMax=512M`.
  - Own localhost port behind the existing Caddy.
  - One request at a time. Each photo goes to a fresh private temp folder and is deleted after the read.
  - Measured: 206 MB peak and 10.4 s for one photo (ticket #28).
- **Claude credential:** the owner's subscription token for development only. Switch to an API key (`sk-ant-api03-`) with a workspace spend limit **before friends use Claude reading**. Reason: reports from February 2026 say subscription tokens may not power other products or services.
- **Model:** Haiku 5.5 first; if its items and charges do not add up to its own total, Sonnet 5.5 once on the same photo (ticket #10). Test: all 3 models read 5/5 failed receipts correctly; Haiku cost about $0.0015 per receipt through `claude -p`.

## 3. Requests (ticket #30)

**Register:** `POST /functions/v1/register`, body `{"inviteCode": "K7QX-M2PA"}` → `{"deviceToken": "<32 random bytes, hex>"}`. Store only a hash of the token. 400 malformed; 403 unknown, cancelled or full code (one message for all three). At most 10 attempts an hour per IP.

**Read:** `POST /functions/v1/read-receipt`, `Authorization: Bearer <deviceToken>`, `Content-Type: image/jpeg` or `image/png`, raw image body. Deployed with `--no-verify-jwt`.

**Daily limits with Claude first:** each scan with online access uses one read, so 10 a day per phone is about 10 bills; the owner can raise it in the Edge Function config.

**Reply (200):** money as strings; `price` is the line total.
```json
{"merchant": "MENYA HANABI", "date": "2026-11-07",
 "items": [{"name": "Kimista (Large)", "quantity": 1, "price": "26.00"}],
 "serviceCharge": "0.00", "tax": "7.65", "discount": "0.00",
 "rounding": "0.00", "total": "135.15", "readsLeftToday": 7}
```

| Code | Meaning | Uses a daily read |
|---|---|---|
| 401 | Unknown or cancelled device token | no |
| 413 / 415 | Over 2 MB / not JPEG or PNG | no |
| 429 + `Retry-After` + `{"limit": "device" \| "code" \| "all"}` | Daily limit reached | no |
| 503 + `Retry-After` | Lightsail queue full (5 or more waiting) | no |
| 502 | Claude replied, JSON not valid | yes |
| 504 | Claude took more than 60 s | yes |

**Edge Function → Lightsail:** `POST https://<lightsail>/receipts/read`, `Authorization: Bearer <own token>` (not the text endpoint's token; a Supabase secret), raw image body. Lightsail owns the prompt and the JSON check; replies 200 (without `readsLeftToday`), 502, 503 or 504.

**Timeouts:** Claude 60 s → Edge Function 70 s → app 90 s.

**Logs:** status, size, duration, a short hash of the device. No photos, no receipt content.

**Starting prompt** (from the model test):
```
Read the image file receipt.jpg in the current folder. It is a restaurant receipt from Malaysia.
Reply with JSON only, no other text, in this shape:
{"merchant": string|null, "date": "YYYY-MM-DD"|null, "items": [{"name": string, "quantity": int, "price": string}], "serviceCharge": string, "tax": string, "discount": string, "rounding": string, "total": string|null}
Money values are strings with 2 decimals. "price" is the line total, not the unit price. Use "0.00" for charges that are not printed. If the item prices already include tax, put the tax in "tax" only if the printed total adds it on top.
```

## 4. Limits and invite codes (ticket #5, #30)

- One invite code per friend, 2 phones per code. The owner can cancel a code; all its phones get 401.
- 10 reads a day per phone, 15 per invite code, 150 for all friends together. The day resets at midnight UTC+8.
- Invite admin: two saved queries in the Supabase SQL editor, "New invite code" (by friend name, returns the code) and "Cancel invite".

## 5. Screens (tickets #31 and #4)

Prototype: `docs/prototypes/claude-fallback-prototype.html` (`?variant=C`, the sheet). Amended for Claude first (ticket #4); points marked *default* were set by Claude and the owner may correct them.

- **Photo step:** text becomes "With online access, the photo is sent to Koban's server to be read, then deleted." Without online access the text stays as today.
- **Reading step** (*default*): one waiting screen, "Reading the receipt…" (about 10 s). Claude and the phone rules run at the same time.
- **Which read wins** (*default*): Claude's read if it adds up; else the rules' read if it adds up; else Claude's read with the mismatch line. No online access, or Claude fails: the rules' read.
- **Read by Claude:** the top line says "✓ Read by Claude · N reads left today". No Undo (*default*: Claude's read is the first read, not a replacement).
- **Claude could not run** (*default*): use the rules' read and show one short line why:
  - no invite code: nothing extra (rules only, as today);
  - 401: "Read on the phone. Your invite code is no longer active.";
  - 429: "Read on the phone. You used your 10 Claude reads for today." (for `"all"`: "…Koban reached today's Claude limit.");
  - 503 / no internet: "Read on the phone. Claude was not reachable.";
  - 502/504: "Read on the phone. Claude could not read this receipt. This used 1 of today's reads."
- **Mismatch** (layout C): a short red line at the top of the Items step, "Differs from the receipt total by RM x. Fix". "Fix" opens a bottom sheet with "Add RM x as rounding" and "Edit by hand". "Read again with Claude" (with "Sends the photo to Koban's server · N reads left today") shows **only when Claude did not run for this photo** (offline, busy, or the code was entered after the scan). Its waiting view shows the phone's read next to Claude's read as it fills in.
- **Settings:** an "Invite code" field. After a good register it shows "Online access: on".
- **Photo:** keep the photo until the Items step closes (the sheet may still send it), then delete it.

## 6. Build order

| # | Work | Where | Time |
|---|---|---|---|
| 1 | Tilt fix, name cleanup, regression tests, benchmark run — **done** | App | 1.5 h |
| 2 | Postgres tables (invite codes, devices, daily counts), saved SQL queries — **done** | Supabase | 1 h |
| 3 | Lightsail photo service: user, systemd unit, Caddy route, prompt, Haiku → Sonnet, canary test — **done** | Lightsail | 2 h |
| 4 | Edge Functions `register` and `read-receipt`, secrets, keep-alive cron — **done** | Supabase + Lightsail | 2 h |
| 5 | App: invite code in Settings, `ReceiptCloudClient` (OkHttp), Claude and rules in parallel with the choice of read, photo kept until the Items step closes, bottom sheet, messages — **done**, tested on the phone | App | 4 h |
| 6 | Switch to an API key with a spend limit; scan 5 real receipts end to end | All | 30 min |

Total: about 11 hours.

## Anti-goals (a failure even if it works)

- A receipt photo, the Lightsail URL, or any key inside the APK or in this public repo.
- The photo service able to read the other app's files (the canary test must fail at both the Claude and the OS level).
- A Claude call without a valid device token, or past a daily limit.
- A friend's read used up by a 429 or 503.
- Friends using Claude reading while the backend still runs on the owner's subscription token.
- Receipt scanning that stops working without an invite code or internet.
