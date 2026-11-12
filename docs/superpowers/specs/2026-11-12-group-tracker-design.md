# Group spending tracker

Friends join a group and see each other's shared totals: spending per week and month, per category, and progress against personal budgets. Every decision comes from [Map: Group spending tracker](https://github.com/Skooyo/koban/issues/3); each point links its ticket. Terms are in `GLOSSARY.md` (Group, Member, Group owner, Group code, Join request, Shared totals, Account, Alias, Private payment, Online features switch).

## Rules

- **Online feature.** Groups need an account, and the first sign-in needs an invite code. Local features stay open to everyone. ([#35](https://github.com/Skooyo/koban/issues/35))
- **Local-first.** Room stays the main store. The server holds only accounts, groups, memberships, join requests, shared totals and budget limits. Single payments never leave the phone. ([#18](https://github.com/Skooyo/koban/issues/18))
- **Totals, not payments.** Members see totals per member and per category for each calendar week (Monday to Sunday) and calendar month, Malaysia time. Never merchants, times, notes, the bank notification text or the bank app. ([#15](https://github.com/Skooyo/koban/issues/15))
- **Same for all.** Every member sees the same about every other member, and every group sees the same totals of a person. ([#15](https://github.com/Skooyo/koban/issues/15), [#16](https://github.com/Skooyo/koban/issues/16))

## 1. What counts ([#16](https://github.com/Skooyo/koban/issues/16))

- Every money-out payment that is not dismissed (auto-saved and edited). A split bill counts as the person's own share (`countedAmount`).
- Not: money in (`RECEIVE`), private payments (a new `privateToGroups` flag on `ExpenseEntity`, set on the payment screen as "Not in groups").
- A new member's totals start at the current week and month. Earlier periods are not sent.
- An edit to an earlier period changes that period's shared totals.
- RM and Rp are separate accounts; no conversion. The group screen shows the active account from Settings. ([#38](https://github.com/Skooyo/koban/issues/38))

## 2. Accounts and sign-in ([#35](https://github.com/Skooyo/koban/issues/35))

- Google sign-in with Credential Manager and Supabase Auth (`signInWith(IDToken)`, raw nonce to Supabase, SHA-256 nonce to Google). Sign in with Apple joins on iPhone later.
- Sign-in starts only from "Make a group" or "Join a group".
- First sign-in: the app sends the phone's device token; the server links the account to that device's invite code. A phone with no device token asks for an invite code first (the Settings flow). Later sign-ins on any phone need no code.
- Alias: pre-filled with the Google first name, changeable at any time. Email never shown to members.
- "Delete account" (Settings): an Edge Function with the secret key deletes the auth user; `on delete cascade` removes everything else.
- Deleting the app only: data stays; members see "Updated <date>".

## 3. Groups ([#36](https://github.com/Skooyo/koban/issues/36), [#37](https://github.com/Skooyo/koban/issues/37))

- A signed-in person makes a group and is its group owner. Up to 10 members per group, 5 groups per person.
- Group code `GRP-XXXX` from the invite-code letters (no 0, O, 1, I). Valid until the owner makes a new one. Share sheet text: "Join my Koban group: GRP-XXXX".
- Join request with the code; the owner approves or declines in the app (badge on Groups, a Requests list). No push. Expires after 7 days.
- Only the owner removes members, renames the group and makes a new code.
- Leave or removed: membership deleted at once; no history kept. A removed person sees "You were removed from <group>" once and may ask again.
- Owner leaves: the role passes to the earliest member; the owner may hand it over first. Last member leaves: the group, code and requests are deleted.
- A person in no group: the phone stops sending and the server deletes their shared totals and budget limits.

## 4. Sync ([#16](https://github.com/Skooyo/koban/issues/16), [#39](https://github.com/Skooyo/koban/issues/39), [#34](https://github.com/Skooyo/koban/issues/34))

- Send: at app start, 5 seconds after a payment is saved, edited or deleted, after each group action, and on pull to refresh. The phone recomputes every period since its earliest join and replaces all its rows. No WorkManager: a change made offline goes up at the next change or app start.
- Read: a group screen loads on open and on pull to refresh. No Realtime.
- "Updated <time>" per member is the time of their last upload.
- Online features switch off: no network calls; the Groups screen shows "Online features are off" and a button. Back on: send the current totals at once.

## 5. Data (Supabase project `koban`) ([#19](https://github.com/Skooyo/koban/issues/19), [#17](https://github.com/Skooyo/koban/issues/17))

| Table | Columns |
|---|---|
| `profiles` | `user_id` (pk, → auth.users, cascade), `alias`, `invite_id` (→ invite_codes), `totals_updated_at` |
| `groups` | `id` uuid, `name`, `owner_id`, `code` unique, `created_at` |
| `group_members` | `group_id`, `user_id`, `joined_at`; pk both |
| `join_requests` | `group_id`, `user_id`, `created_at`; pk both; expire after 7 days |
| `shared_totals` | `user_id`, `currency` (MYR/IDR), `period` (week/month), `period_start` date, `category` text, `amount` numeric; pk all but amount |
| `budget_limits` | `user_id`, `currency`, `period`, `category` (or `Total`), `amount` |

- Row-level security on all. Reads: a member reads rows of users in their groups, through a `security definer` helper `private.my_group_mates()`. Writes: a person writes only their own `shared_totals`, `budget_limits` and `profiles` row.
- Group actions are `security definer` RPCs that check rights and limits: `make_group`, `ask_to_join`, `answer_request`, `leave_group`, `remove_member`, `hand_over`, `rename_group`, `new_group_code`, `link_account`.
- App access: a small OkHttp client for GoTrue and PostgREST (`groups/SupabaseClient.kt`) with the publishable key; supabase-kt needs a newer Kotlin than the app. Free plan with the existing keep-alive.
- Money: the group screen shows the account picked in Settings (RM until the Rp account ships); it has no RM/Rp switch of its own.

## 6. Screens ([#40](https://github.com/Skooyo/koban/issues/40))

Prototype: `docs/prototypes/group-screens-prototype.html` (`?variant=D`).

- **Groups list:** one row per group (name, members, your place), a request badge; "Make a group", "Join a group".
- **Group (layout D):** Week / Month; your summary (total in large type, "2nd of 4 in <group>. Resets in N days.", your budget bars); Members as one list with dividers, ranked by total: rank, avatar with a budget ring, alias, status in words ("▲ Over Food", "! Near Food limit", "No budgets set"), total, a category bar in category colors; a row opens in place with every category and the budget bars; an (i) button explains the order and the ring; the group code card with "Share code".
- **Join requests** (owner): Approve / Decline, the group code, "Make a new code".
- **What others see about me:** exactly the member's shared totals and budgets, the list of what is never shared (no count of private payments), "Leave group".
- **Off state:** "Online features are off" and "Turn on online features".
- Spacing: 8 dp scale; 16 dp screen edge, 24 dp between blocks, 16–20 dp inside surfaces; 48 dp touch targets.

## 7. Build order

| # | Work | Needs the owner |
|---|---|---|
| 1 | Migration: tables, RLS, RPCs; push; SQL tests of rights and limits | no |
| 2 | Google sign-in: Google Cloud OAuth clients (Web + Android, debug SHA-1), Supabase Google provider, Credential Manager in the app, `link_account` | the Google Cloud project |
| 3 | Totals: `privateToGroups` flag and "Not in groups" toggle, the totals query per account, the sync worker | no |
| 4 | Screens: Groups list, make and join, group (layout D), requests, what others see, off state, alias in Settings, Delete account | no |
| 5 | End to end on two phones (or a phone and an emulator) | a second account |

## Out of scope

- Setting personal budgets: [Map: Personal budgets per category](https://github.com/Skooyo/koban/issues/33). Until it ships, budget limits are empty and rows show "No budgets set".
- A full backup of payments; push notifications; Realtime; iPhone.
