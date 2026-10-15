# Data Model

## Catalog

- `Book__c`: title, ISBN, publication metadata, status, aggregate total/available copies.
- `Book_Copy__c`: physical copy, barcode, shelf, condition, price, operational status; master-detail to Book.
- `Author__c` and `Book_Author__c`: author catalog and ordered junction.
- `Book_Category__c` and `Book_Category_Link__c`: category catalog and junction.

`BookCopyInventoryTrigger` recalculates Book totals after copy insert, update, delete, and undelete. Available copies are copies whose status is `Available`.

## Member and identity

- `Member__c`: profile, membership plan/dates/status, Contact/User legacy links, and external portal fields.
- `External_Auth_Id__c`: unique, case-sensitive External ID; immutable provider UID.
- `Normalized_Email__c`: case-insensitive unique normalized email.
- `Account_Status__c`: Pending, Active, Suspended, Rejected, Inactive.
- `Email_Verified__c`, `Last_Login__c`.

`Status__c` represents library membership status; `Account_Status__c` represents portal/account eligibility. Code must check the appropriate domain and not treat them as interchangeable.

## Transactions

- `Borrow_Record__c`: Member + Book Copy, borrow/due/return dates, status, renewal and damage/replacement tracking.
- `Reservation__c`: Member + Book, optional held copy, queue position and lifecycle dates.
- `Fine__c`: Member + optional Borrow Record, assessed/paid/balance and status.
- `Membership_Payment__c`: membership plan transition/payment history and gateway/reconciliation placeholders.
- `Member_Notification__c`: member notification inbox with deduplication key.
- `Reservation_Audit__c`: immutable-style reservation lifecycle audit records.

Direct Contact lookups on loan/reservation/fine are legacy Experience sharing mirrors maintained by triggers.

## Registration and policy

- `Library_Registration__c`: applicant, requested plan, decision, provisioning state, created records, and unique external UID/email keys.
- `Membership_Plan__c`: fee, duration, borrow/loan/reservation/renewal limits, daily fine, active flag.
- `Library_Experience_Config__mdt`: legacy Experience provisioning settings and hold duration.

## Sharing and integrity

Member, loan, reservation, fine, payment, registration, notification, and audit data are Private where defined. Catalog objects are broadly readable. Unique ISBN, barcode, junction keys, normalized email, and external UID prevent key duplicates. Validation rules enforce nonnegative values and chronological dates.
