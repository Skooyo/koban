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
