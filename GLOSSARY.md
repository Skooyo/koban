# Koban

Koban is an expense tracker for a small circle of friends. It records payments, splits bills, and reads receipts.

## Receipt reading

**Receipt rules**:
The on-phone reading of a scanned receipt into items, charges and a printed total, without a network call.
_Avoid_: OCR (that is only the text recognition step), parser

**Mismatch**:
The state where the items plus charges of a read receipt do not equal its printed total.
_Avoid_: error, failed read

**Claude fallback**:
A second reading of a receipt by Claude, started only when the friend taps "Read with Claude" on a mismatch.
_Avoid_: LLM mode, AI scan, auto-read

## Access

**Local feature**:
A feature that runs only on the phone and is open to everyone, such as expenses, payment capture and split bill.
_Avoid_: free feature, offline mode

**Online feature**:
A feature that needs Koban's servers, such as the Claude fallback. Only a phone with online access can use it.
_Avoid_: premium feature, cloud feature

**Online access**:
The right of a phone to use online features. Today an invite code is the only way to get it.
_Avoid_: subscription, membership, plan

**Invite code**:
A code the owner gives to one friend, which gives up to 2 phones online access. The owner can cancel it.
_Avoid_: access key, password, signup code

**Device token**:
The secret a phone gets in exchange for an invite code, and sends with each Claude fallback request.
_Avoid_: API key, session, login

**Daily limit**:
The most Claude fallback reads allowed in one day, counted per phone, per invite code, and for all friends together.
_Avoid_: quota, rate limit

**Online features switch**:
One setting that turns all of Koban's network calls on or off, the update check included. On by default; without an invite code or an account, "on" sends only the app version.
_Avoid_: offline mode, privacy mode

## Groups

**Group**:
A set of friends who see each other's shared totals, for awareness and for challenges against personal budgets.
_Avoid_: team, circle, room

**Member**:
A person in a group. Every member sees the same shared totals about every other member.
_Avoid_: participant, follower

**Group owner**:
The member who made a group. Only the group owner approves join requests, removes members, renames the group and makes a new group code.
_Avoid_: admin, host, creator

**Group code**:
A short code like GRP-7KQ2 that a person shares so friends can ask to join a group. It stays valid until the group owner makes a new one.
_Avoid_: invite code (that gives online access), group link

**Join request**:
A request to join a group, sent with its group code. The group owner approves or declines it; it expires after 7 days.
_Avoid_: invitation, application

**Shared totals**:
What a member shows a group: the total spending, and the total per category, for each calendar week and calendar month. Never single payments, notes or bank notification text.
_Avoid_: feed, activity, spending data

**Account**:
A person's sign-in for groups (Google on Android), linked once to one invite code. It works on any phone the person signs in on.
_Avoid_: user, profile, login

**Alias**:
The name that other members see for a person. The person picks it and can change it.
_Avoid_: username, display name, nickname

**Private payment**:
A payment that its person marked "not in groups". It counts in no group's shared totals, and still counts on the person's own phone.
_Avoid_: hidden payment, excluded payment

## Budgets

**Personal budget**:
A spending limit that a person sets for one category, or for the total, for each week or month. A local feature; in a group, members see each other's personal budgets and progress.
_Avoid_: goal, cap, challenge (a challenge is the group use of personal budgets)
