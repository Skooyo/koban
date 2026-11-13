# Koban design system

The browsable version with live previews: https://claude.ai/artifact/1qY6bsCrnWNSKiDoPUx9N4 (private to the owner). This file is the copy that coding agents read. When the two differ, change both.

Koban is an Android expense tracker for people in Malaysia. It reads bank notifications and receipts, and it splits bills with friends and groups. This book sets the look, the words and the rules for every Koban screen. Follow it for every new screen and every UI change.

## The vibe

Calm, exact, a little dry. One gold coin on a night-blue table. The app counts money for you and does not shout about it.

- **Calm:** dark night-blue grounds, few colors, no motion that nobody asked for.
- **Exact:** every amount is a real number in tabular figures. Every button says what it does.
- **A little dry:** Mon, the coin, makes a short plain joke on an empty or a finished screen. Nowhere else.
- **One gold thing:** gold marks the one action you can take next. If two things are gold, one of them is wrong.

## Color rules

The values are in the Tokens section below. Dark is the main theme; light follows the phone setting.

1. Use `night` for the page, `surface` for cards, lists and sheets, `surface-2` for fields and keys inside them.
2. Use `ink` for main text and `muted` for second lines. Do not make a third gray.
3. Use `gold` for the one main action on a screen: the filled button or the add button. Put `on-gold` text on it.
4. Use `gold-soft` with `gold-text` for a second action (the tonal button) and for selected chips.
5. Use `error` for errors only. Spent money is `ink`, not red.
6. Use `received` for money that came in. Put a plus sign in front: `+ RM 50.00`. Color is never the only sign.
7. Use `review` only for payments that wait in Check payments.
8. Use the `cat-*` colors only for category dots, chart parts and the edge of a category chip. Never for text, never for a button fill.
9. Keep text at 4.5:1 or more on its ground in both themes. Dots, icons and focus rings need 3:1. Every token note gives its number.

The category colors come from Malaysian ringgit notes, so they feel familiar:

| Category | Token | Note |
| --- | --- | --- |
| Food | `cat-food` | RM10, red |
| Transport | `cat-transport` | RM1, blue |
| Shopping | `cat-shopping` | RM100, purple |
| Bills | `cat-bills` | RM20, orange |
| Health | `cat-health` | RM50, teal |
| Entertainment | `cat-fun` | RM5, green |
| Own category | `cat-custom` | indigo |
| Other, none | `cat-other` | slate |

## Type

One font: Bricolage Grotesque, a variable font. The Android code loads it from `app/src/main/res/font/bricolage_grotesque.ttf`.

- Display and headline styles use optical size 96. Text, title and label styles use optical size 14. This matches `Theme.kt`.
- Amounts use tabular figures (`font-feature-settings: "tnum"`; in Compose `fontFeatureSettings = "tnum"`), so columns of money line up.
- Write money as `RM 12.50`: a space after RM, always two decimals. A received amount is `+ RM 12.50`.
- Write dates as `Fri, 13 Nov`. Write ranges as `Mon 9 – Sun 15 Nov`. Say `Today` and `Yesterday` for the last two days.
- One `display-*` amount per screen. It is the number the screen is about.
- Use sentence case everywhere: `Save payment`, not `Save Payment`. No all-caps labels.

## Layout and shape

- Side margin `space-16`. Gap between groups `space-24`.
- Every tap target is `tap-48` or more. A list row is 56px tall or more.
- Lists sit in one `surface` group with `radius-16` and `line` dividers. Do not put each row in its own card.
- Sheets have `radius-24` top corners. Dialogs have `radius-24`. Buttons are `radius-full`.
- The add button sits bottom right above the bottom bar. Give the last list row enough bottom padding so the add button never covers it.
- No shadows on dark. Show depth with `night`, `surface` and `surface-2`.
- The bottom bar has 4 tabs: Home, Activity, People, Groups. The selected tab gets a `gold-soft` pill.

## Icons

- Use Material Icons, filled style (`Icons.Default`). Use `Icons.AutoMirrored.Filled` for icons that point (back, forward, lists).
- Size 24dp in rows and bars, 20dp inside buttons.
- Color icons `ink`, or `muted` in a second-line role. Gold only inside the main action.
- No emoji in the UI.

## Words

Use one word for one thing, on every screen. These are the words of the redesign mockups (`docs/prototypes/app-redesign-mockups.html`):

| Use | Not | Meaning |
| --- | --- | --- |
| payment | transaction, expense, entry | one money movement |
| Spent / Received | debit/credit, expense/income | the two types of payment |
| Shop | merchant, payee, vendor | where the money went |
| Check payments | review queue, inbox | the screen for payments Koban found but did not save |
| Not a payment | dismiss, reject, ignore | the button that drops a found notification |
| Save payment | submit, add, confirm | the button that keeps a payment |
| split | share, divide | one bill paid by many people |

Button text is a verb and an object: `Save payment`, `Turn on tracking`, `Check for updates`. A result uses the same verb: `Payment saved`.

## Errors and empty screens

An error says what happened and what to do, in two short lines. No "Oops", no "Something went wrong", no apology.

- Good: `Could not check for updates.` / `Try again later.`
- Good: `Koban cannot read notifications.` / `Turn on notification access.` with a `Turn on` button.

An empty screen says what will show here and gives the one action that fills it. Mon may sit above the text.

- Good: `No payments yet.` / `Add one, or turn on tracking to find them.`

Before Koban drops typed data (X, Back, swipe down), it asks `Discard changes?` with `Keep editing` and `Discard`. After a delete, it shows a snackbar with `Undo` for 6 seconds instead of a dialog.

## Motion

- Motion answers a tap: a sheet slides up, a row slides out on delete, a number counts up once when a payment is saved.
- 200 ms for small changes, 300 ms for sheets and screens. Standard Material easing.
- No looping animation. Mon does not move by itself.
- When the phone setting turns animations off, Koban shows each change at once.

## Mon, the mascot

Mon is a tilted koban coin with a sleepy face, in the spirit of a small desk toy. The Mon section below shows the rules; the mockups file draws all 5 faces.

- Mon appears on empty screens, finished screens (all checked, all paid), the tracking-off status, and first start. Nowhere else.
- Never more than one Mon on a screen. Never on a list row, a button, a chart or the cover.
- Mon has 5 faces: `idle` (usual), `sleep` (tracking is off), `happy` (all done), `worry` (an error with a fix), `look` (working: reading a receipt, syncing).
- Mon's line is one short sentence, dry, under 60 characters. The real message stays in plain text next to it, so the screen works without the joke.
- Mon is decoration for screen readers when the text says the same thing. Otherwise give it a label: `Mon, sleeping`.
- Mon uses only `gold`, `coin-rim`, `coin-shade`, `coin-shine` and `on-gold`. Do not recolor it.

## Logo

The logo is a gold coin ellipse, tilted 14 degrees, on night blue (`docs/logo/koban.svg`). Use the file as it is. Do not add a face to the logo: the face belongs to Mon.

## Checklist for a new screen

Check these 10 items before a screen ships. They follow Nielsen's 10 usability heuristics.

1. **Status:** the screen shows what Koban does now (tracking on or off, syncing, last check).
2. **Words:** it uses the words in the Words table, and money as `RM 12.50`.
3. **Way out:** X or Back leaves it. Typed data gets `Discard changes?`. A delete gets `Undo`.
4. **Same as the rest:** tokens only, no new colors, sizes or radii. One gold action.
5. **Errors stopped early:** amounts take only numbers, dates cannot be in the future when that makes no sense.
6. **Visible choices:** options show on screen. Nothing hides behind a long press only.
7. **Fast for regulars:** the common action is one tap from the screen it belongs to.
8. **Calm:** no element that does not help this task. One `display-*` amount at most.
9. **Error text:** what happened and what to do, in two lines, with the fix as a button.
10. **Help in place:** a one-line hint under the field that needs it, not a help page.

## Where this lives in the code

The Compose theme is `app/src/main/java/com/expensetracker/app/ui/theme/Theme.kt`: `MoneyColors` for amounts and categories, and the Material color schemes.

- Done on 2026-11-13: primary is gold (dark) and `#7A5D00` with white text (light, because Material also uses primary for text buttons); Entertainment uses `MoneyColors.green`.

## Tokens

### Colors

| Token | Dark | Light | Use |
| --- | --- | --- | --- |
| `night` | `#141b2b` | `#f6f7fa` | Page background behind every screen. Dark is the main theme. |
| `surface` | `#1c2539` | `#ffffff` | Cards, list groups, sheets and dialogs on night. |
| `surface-2` | `#243049` | `#eef1f6` | Raised parts inside a surface: fields, the segmented control, the keypad keys, chart tracks. |
| `line` | `#2f3b57` | `#d9dee8` | Dividers between list rows and outlines of outline buttons. Never use it for text. |
| `ink` | `#edf0f7` | `#161d2b` | Main text and icons. 15:1 on night, 11.5:1 or more on surface-2 in both themes. |
| `muted` | `#a2acc2` | `#5a6478` | Second-line text: row labels, dates, hints. 5.2:1 or more on surface and surface-2 in both themes. |
| `gold` | `#f2c94c` | `#f2c94c` | The one action color: the filled button, the add button, the selected tab pill, the focus ring. One gold action per screen. In light it is a fill only: its edge is 1.5:1 on night, so the on-gold label carries it. |
| `on-gold` | `#2a2106` | `#2a2106` | Text and icons on a gold fill. 10:1. |
| `gold-soft` | `#3a3420` | `#fbf1cf` | Tonal button fill, the selected chip, a highlighted row. Put gold-text on it. |
| `gold-text` | `#f2c94c` | `#7a5d00` | Gold as text: links, the active label, text on gold-soft. 5.4:1 or more on surface and gold-soft in both themes. |
| `received` | `#6fd3a0` | `#16804a` | Money that came in: the amount and the plus sign of a Received payment. 5:1 or more on surface. |
| `error` | `#ff7b6b` | `#c8372a` | Errors only: the error line under a field, a failed sync, the Discard button. Never for spent money. 5.2:1 or more on surface. |
| `review` | `#f0b060` | `#a85a00` | A payment that waits for a check (the Check payments queue). Text and the small badge. 5:1 or more on surface. |
| `cat-food` | `#ff6b5e` | `#e5483b` | Food. Red, like the RM10 note. Category colors are for dots, chart parts and the category chip edge only, never for text or a button fill. |
| `cat-transport` | `#5b9bff` | `#1f6fe0` | Transport. Blue, like the RM1 note. |
| `cat-shopping` | `#a98bff` | `#7b4fd6` | Shopping. Purple, like the RM100 note. |
| `cat-bills` | `#ffa94d` | `#e07a0f` | Bills. Orange, like the RM20 note. Light value is 3.0:1 on surface: the minimum for a dot. |
| `cat-health` | `#3cc6c0` | `#0e9c95` | Health. Teal, like the RM50 note. |
| `cat-fun` | `#a8d45a` | `#6e9a12` | Entertainment. Green, like the RM5 note. It moved off gold so gold stays the action color. |
| `cat-custom` | `#8c9eff` | `#4c5fd5` | A category the person made. Indigo. |
| `cat-other` | `#8a96a8` | `#6b7686` | Other, and a payment with no category. Slate. |
| `coin-rim` | `#d9ae35` | `#d9ae35` | Mon and the logo only: the coin rim line. |
| `coin-shade` | `#c99a22` | `#c99a22` | Mon and the logo only: the coin edge below the face. |
| `coin-shine` | `#fff3c4` | `#fff3c4` | Mon and the logo only: the highlight, at 55% opacity. |

### Type

Bricolage Grotesque. Sizes in sp. Display group uses optical size 96, Text group optical size 14.

| Style | Size / line | Weight | Tracking | Use |
| --- | --- | --- | --- | --- |
| `display-large` | 57 / 64 | 700 | -1.5px | The one big amount on a screen: the total on Home, the amount on the payment screen. Tabular figures. |
| `display-medium` | 45 / 52 | 700 | -1px | A big amount in a sheet or a card. |
| `display-small` | 36 / 44 | 700 | -0.5px | An amount in a dialog or a split share. |
| `headline-large` | 32 / 40 | 600 | -0.5px | Screen title on the top level tabs. |
| `headline-medium` | 28 / 36 | 600 | -0.25px | Month title in Activity. |
| `headline-small` | 24 / 32 | 600 | 0px | Title of a pushed screen or a sheet. |
| `title-large` | 22 / 28 | 600 | 0px | Dialog title. |
| `title-medium` | 16 / 24 | 600 | 0px | First line of a list row: the shop name. The amount on the row end. |
| `title-small` | 14 / 20 | 600 | 0px | Group heading above a list. |
| `body-large` | 16 / 24 | 400 | 0.5px | Main paragraph text, dialog body. |
| `body-medium` | 14 / 20 | 400 | 0.25px | Second line of a list row, hints. |
| `body-small` | 12 / 16 | 400 | 0.4px | Captions and the line under a field. |
| `label-large` | 14 / 20 | 500 | 0.1px | Button and snackbar action text. |
| `label-medium` | 12 / 16 | 500 | 0.5px | Bottom bar labels, chip text. |
| `label-small` | 11 / 16 | 500 | 0.5px | Badges and counters. The smallest text: use it for numbers, not sentences. |

### Spacing and radius (dp)

| Token | Value | Use |
| --- | --- | --- |
| `space-4` | 4px | Between an icon and its label, between a row's two lines. |
| `space-8` | 8px | Between buttons in a row, between chips. |
| `space-12` | 12px | Inside a chip or a small card. |
| `space-16` | 16px | Screen side margin and list row padding. The default step. |
| `space-24` | 24px | Between groups on a screen, dialog padding. |
| `space-32` | 32px | Above the big amount, around an empty state. |
| `tap-48` | 48px | The smallest tap target, in both directions. A list row is 56px or more. |
| `radius-8` | 8px | Chips, badges, the category chip. |
| `radius-12` | 12px | Text fields, keypad keys, the snackbar. |
| `radius-16` | 16px | List groups and cards. |
| `radius-24` | 24px | Bottom sheets (top corners), dialogs, the hero card on Home. |
| `radius-full` | 999px | Buttons, the add button, the bottom bar pill, toggles. |

## Components

### Button

Buttons start one action, and their text says that action as a verb and an object.

| Kind | Look | Use |
| --- | --- | --- |
| Filled | `gold` fill, `on-gold` text | The one main action on a screen: `Save payment`. Only one per screen. |
| Tonal | `gold-soft` fill, `gold-text` text | A second action next to the main one: `Split bill`. |
| Outline | `line` edge, `ink` text | A safe other choice: `Not a payment`, `Keep editing`. |
| Text | no fill, `gold-text` text | Small actions in snackbars and dialogs: `Undo`, `OK`. |

- Height 48px (`tap-48`), radius `radius-full`, text `label-large`, side padding 24px.
- An icon goes before the text, 20px. A button never has only an icon; an icon-only control is an icon button with a content description.
- Disabled: 38% opacity, and a line of `muted` text near it says why (`Turn on Online features to check for updates.`).
- Focus: a 3px `gold` ring, 2px out.
- A destructive action (`Discard`, `Delete`) is a text button in `error`. Never a gold fill.
- In Compose: `Button` (filled), `FilledTonalButton`, `OutlinedButton`, `TextButton` with the theme colors. Do not pass custom colors per screen.

### PaymentRow

A payment row shows one payment in a list: category dot, shop, date and category, and the amount.

- The row is 64px tall, padding 12px 16px, inside one `surface` group with `radius-16`. Rows are split by a 1px `line`. Do not put each row in its own card.
- Dot: 10px, the category's `cat-*` color. The category name is also in the second line, so color is never the only sign.
- First line: the shop, `title-medium`, one line, cut with an ellipsis.
- Second line: `Today · Food`, `body-medium` in `muted`.
- Amount: `title-medium`, tabular figures, at the row end. Spent is `ink`. Received is `received` with a plus: `+ RM 23.40`.
- A payment that waits in Check payments gets a small `Check` badge in `review`.
- Tap opens the payment. Swipe to delete shows a snackbar with `Undo` (see Snackbar).
- The consumer gives: shop, date label, category (name and color), amount, type (Spent or Received), and whether it waits for a check.

### StatusRow

A status row tells what Koban does now, and gives the fix in one tap when something is wrong.

- Put it at the top of Home, under the screen title. One status row at a time: show the most urgent state.
- Layout: 24px icon, a `title-medium` state line, a `body-medium` `muted` detail line, and an optional text button at the end. `surface` fill, `radius-16`, 64px tall or more.
- States and their icon color:
  - On: check icon in `received`. No button.
  - Off: icon in `muted`, a button that turns it on (`Turn on`). Mon may show the `sleep` face here at 44px, in place of the icon.
  - Failed: warning icon in `error`, what happened and when Koban tries again, and a button (`Try now`).
- The state line uses the words of the feature (`Tracking on`, `Sync failed`). The detail line says the cause or the time in plain words.
- The consumer gives: state, detail text, and the action label and handler if there is one.

### Snackbar

A snackbar confirms an action that just happened and offers Undo for 6 seconds.

- Use it after delete, Not a payment, and bulk saves. Use it in place of an "Are you sure?" dialog for actions that Undo can reverse.
- The text is the result in the past tense, with the same verb as the button: `Payment deleted`, `3 payments saved`. No full stop.
- The fill is the inverse of the theme: `ink` fill with `night` text. The action is the gold of the other theme (`gold-text` light value `#7a5d00` on dark, `gold` `#f2c94c` on light), so it stays readable on the inverse fill.
- One action at most: `Undo`. An error with a fix is a StatusRow or a dialog, not a snackbar.
- Sits above the bottom bar and the add button, `radius-12`, 48px tall or more. It does not cover the add button.
- In Compose: `SnackbarHost` with `SnackbarDuration.Short` plus the action, or a 6 second custom duration.

### DiscardDialog

The discard dialog asks before Koban drops data the person typed.

- Show it when X, Back or a swipe-down would close a screen or sheet that has changes. With no changes, close at once, with no dialog.
- Title `Discard changes?` in `title-large`. One line in `muted`: `Your changes are not saved.` Two text buttons: `Keep editing` (left, `gold-text`) and `Discard` (right, `error`).
- `Keep editing` and a tap outside the dialog both keep the screen open with the data unchanged.
- `surface` fill, `radius-24`, 24px padding, a 50% black scrim.
- In the code: `DiscardChangesDialog.kt`, used by the payment screen, the edit sheet and the split editor. Reuse it; do not write a second one.
- Use a dialog only for this kind of loss. A delete that Undo can reverse gets a Snackbar, not a dialog.

### Mon

Mon is Koban's mascot: a tilted koban coin with a sleepy face, shown on empty, finished and status screens.

- Faces: `idle`, `sleep`, `happy`, `worry`, `look`. Pick the face from the screen's state, not for fun.
- Sizes: 120 to 160px on an empty or finished screen, 96px in a dialog, 44px in a status row, 22px next to a Settings row title.
- One Mon per screen at most. Never on a list row, a button, a chart, a notification or the cover.
- Next to Mon goes one dry line under 60 characters, plus the real message in plain text. Examples: `Nothing left. I will just sit here and shine.` (happy), `I cannot see your payments. Wake me up.` (sleep).
- Mon does not move by itself. It may change face when the state changes.
- Colors are fixed: face `gold` `#F2C94C`, edge `coin-shade` `#C99A22`, rim `coin-rim` `#D9AE35`, hammer lines `#E3B93E`, shine `coin-shine` `#FFF3C4` at 55%, face lines `on-gold` `#2A2106` at 2.6 stroke. The same on dark and light.
- Accessibility: when the text says the same as Mon's face, mark Mon as decoration (`contentDescription = null`). Otherwise label it: `Mon, sleeping`.
- Source: the `mon(face, size)` function in `docs/prototypes/app-redesign-mockups.html` (viewBox 0 0 100 110). In Compose, draw it as one `ImageVector` per face, or as vector drawables in `res/drawable`.
