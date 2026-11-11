# `objects/` — Data model

28 folders: 26 custom objects and 2 custom metadata types (`__mdt`). Source is stored non-decomposed for some objects (fields inline in `*.object-meta.xml`) and decomposed (`fields/` folder) for others; both are equivalent.

For design intent see also [docs/DATA_MODEL.md](../../../../docs/DATA_MODEL.md).

## ER overview

```
Membership_Plan__c ──< Member__c >── Member_Session__c
                         │ ├──< Borrow_Record__c >── Book_Copy__c >── Book__c >──< Book_Author__c >── Author__c
                         │ │          └──< Fine__c                     └──< Book_Category_Link__c >── Book_Category__c
                         │ ├──< Reservation__c ──< Reservation_Audit__c        (Reservation also → Book__c, Book_Copy__c)
                         │ ├──< Membership_Payment__c
                         │ ├──< Member_Notification__c ──< Notification_Delivery__c
                         │ ├──< Notification_Preference__c
                         │ ├──< Member_Book_Engagement__c >── Book__c
                         │ ├──< Agent_Confirmation__c
                         │ └──< Library_Scan_Transaction__c  (the private JSON ledger)
Library_Registration__c ──► creates Member__c (+ Contact, User)
Acquisition_Recommendation__c ── Book__c      Search_Analytics__c ── Book__c
Library_Public_Chat_Session__c  Library_Settings__c  Library_Schema_Diagnostic__c
```

## Catalog

| Object                                      | Key fields                                                                                                                                                                                                                      | Notes                                                        |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `Book__c`                                   | `ISBN__c` (unique), `Publisher__c`, `Publication_Year__c`, `Edition__c`, `Language__c`, `Description__c`, `Cover_Image_URL__c`, `Total_Copies__c`, `Available_Copies__c`, `Status__c`                                           | Totals rolled up by `BookCopyInventoryTrigger`. Public read. |
| `Book_Copy__c`                              | `Book__c` (master-detail), `Barcode__c` (unique), `Status__c` (Available, Borrowed, Reserved, Lost, Damaged, Maintenance, Retired), `Condition__c` (New/Good/Fair/Poor), `Shelf_Location__c`, `Price__c`, `Acquisition_Date__c` | Controlled by parent.                                        |
| `Author__c`, `Book_Author__c`               | `Biography__c`, `Country__c`; junction `Author_Order__c`, `Book_Author_Key__c`                                                                                                                                                  | Junction key prevents duplicates.                            |
| `Book_Category__c`, `Book_Category_Link__c` | `Active__c`, `Description__c`; junction key                                                                                                                                                                                     | Genres.                                                      |

## Members & identity

| Object                    | Key fields                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | Notes                                                                       |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `Member__c`               | `Email__c`, `Normalized_Email__c` (unique, case-insensitive), `External_Auth_Id__c` (unique external ID), `Membership_Plan__c`, `Membership_Start/End_Date__c`, `Status__c` (membership), `Account_Status__c` (Pending/Active/Suspended/Rejected/Inactive), `Email_Verified__c`, `Password_Hash__c`/`Password_Salt__c`, `Failed_Login_Count__c`, `Locked_Until__c`, activation/reset token hashes + expiry, `Member_Type__c` (Production/Demo/Legacy), accessibility fields (`Preferred_Language__c`, `Timezone__c`, `High_Contrast__c`, `Large_Text__c`, `Reduced_Motion__c`, `Screen_Reader__c`), `Contact__c`, `User__c`, `Interests__c` | `Status__c` ≠ `Account_Status__c`; check the right one. 2 validation rules. |
| `Member_Session__c`       | `Token_Hash__c`, `Expires_At__c`, `Last_Used_At__c`, `Revoked__c`, `IPAddress__c`, `User_Agent__c`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | Raw tokens never stored.                                                    |
| `Membership_Plan__c`      | `Fee__c`, `Duration_Days__c`, `Borrow_Limit__c`, `Loan_Duration_Days__c`, `Reservation_Limit__c`, `Renewal_Limit__c`, `Fine_Per_Day__c`, `Queue_Priority__c`, `Active__c`                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Drives policy checks.                                                       |
| `Library_Registration__c` | Applicant data, `Requested_Plan__c`, `Status__c`, `Provisioning_State__c/Message__c`, `Created_Member__c`, `Created_Contact__c`, `Registration_Email_Key__c`, payment fields (`Payment_Amount__c`, `Payment_Status__c`, `Payment_Reference__c`)                                                                                                                                                                                                                                                                                                                                                                                             | Has a Lightning record page with `libraryRegistrationReview`.               |

## Circulation & money

| Object                  | Key fields                                                                                                                                                                                                                                                                                      |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Borrow_Record__c`      | `Member__c`, `Book_Copy__c`, `Borrow/Due/Return_Date__c`, `Status__c` (Requested/Active/Overdue/Returned…), `Renewal_Count__c`, `Last_Renewed_Date__c`, defect fields (`Defect_Reported_Date__c`, `Replacement_Required__c`, `Replacement_Date__c`, `Replacement_Days__c`), `Contact__c` mirror |
| `Reservation__c`        | `Member__c`, `Book__c`, `Book_Copy__c` (held), `Queue_Position__c`, `Status__c` (Pending/Ready/Fulfilled/Cancelled/Expired), `Expiry_Date__c`, `Ready_Date__c`, ETA fields (`Estimated_Available_Date__c`, `ETA_Confidence__c`, `ETA_Reason__c`, `ETA_Last_Calculated__c`) — 2 validation rules |
| `Reservation_Audit__c`  | `Reservation__c`, `Action__c`, `From_Status__c`, `To_Status__c`, `Actor__c`, `Queue_Position__c`, `Notes__c`, `Occurred_At__c`                                                                                                                                                                  |
| `Fine__c`               | `Member__c`, `Borrow_Record__c`, `Fine_Type__c` (Overdue/Lost/Damaged/Other), `Amount__c`, `Paid_Amount__c`, `Balance__c`, `Status__c` (Unpaid/Partially Paid/Paid/Waived)                                                                                                                      |
| `Membership_Payment__c` | `Amount__c`, `Currency__c`, `Previous_Plan__c`, `New_Plan__c`, `Status__c`, `Gateway_Payment_Id__c`, `Gateway_Status__c`, `Idempotency_Key__c`, `Reconciliation_Status__c`, `Refund_Amount__c`, `Refund_Date__c`, `Transaction_Reference__c`                                                    |

## Notifications

| Object                       | Purpose                                                                                                                                                                          |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Member_Notification__c`     | In-app inbox row: `Subject__c`, `Message__c`, `Type__c`, `Status__c`, `Read_At__c`, `Related_Record__c`, `Dedup_Key__c`, `Email_Status__c`.                                      |
| `Notification_Delivery__c`   | One attempt per notification/channel: `Channel__c`, `Status__c`, `Attempt__c`, `Max_Attempts__c`, `Next_Attempt_At__c`, `Error_Code__c`, `Provider_Id__c`, `Idempotency_Key__c`. |
| `Notification_Preference__c` | Per member+channel+type: `Enabled__c`, `Digest_Frequency__c`, quiet hours, `Timezone__c`, `Preference_Key__c` (unique).                                                          |

## Engagement, analytics, agents, platform

| Object                           | Purpose                                                                                                                                                                                                 |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Member_Book_Engagement__c`      | Reading-list entry model (`State__c`, `Private_Notes__c`, `Rating__c`, `Notify_When_Available__c`, `Engagement_Key__c`). Runtime currently uses the ledger.                                             |
| `Acquisition_Recommendation__c`  | Immutable evidence-window snapshot (`Recommendation_Type__c`, `Score`, `Confidence__c`, `Evidence__c`, `Recommended_Quantity__c`, `Snapshot_Key__c`, decision notes).                                   |
| `Search_Analytics__c`            | Privacy-minimised search event: SHA-256 `Search_Hash__c`, result count/status — no raw text.                                                                                                            |
| `Agent_Confirmation__c`          | Assistant transaction confirmation: `Action__c`, `Target_Record__c`, `Parameter_Hash__c`, `Token_Hash__c`, `Expires_At__c`, `Used_At__c`, `Idempotency_Key__c`, `Preview__c`.                           |
| `Library_Public_Chat_Session__c` | Public chat state: `Session_Id__c`, `Token_Hash__c`, `Message_Count__c`, `Ended__c`. Private.                                                                                                           |
| `Library_Settings__c`            | Singleton (`Settings_Key__c`): library name/e-mail, shelf prefix, hold days, reminder days, search limit, toggles for reminders/notices/self-registration/e-mail verification/auto-expiry/fine payment. |
| `Library_Schema_Diagnostic__c`   | Probe object used by `validate-library-schema.ps1`.                                                                                                                                                     |
| `Library_Integration_Audit__c`   | Legacy integration audit (fields folder only).                                                                                                                                                          |

## Custom metadata types

| Type                             | Fields                                                                                                                                                       |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Library_Experience_Config__mdt` | `Community_Account_Name__c`, `External_Profile_Name__c`, `Member_Permission_Set_Name__c`, `Network_Name__c`, `Hold_Duration_Days__c` — provisioning defaults |
| `Payment_Gateway_Config__mdt`    | `Provider_Name__c`, `Enabled__c`, `Default_Currency__c`, `Checkout_Named_Credential__c`, `Webhook_Secret__c` (protected)                                     |

## `Library_Scan_Transaction__c` — the private ledger

Fields: `Operation__c`, `Idempotency_Key__c`, `Member__c`, `Book_Copy__c`, `Borrow_Record__c`, `Status__c`, `Result_Message__c`, `Created_At__c` (+ JSON payload). Different `Operation__c` values hold different features:

`Scan` checkout/return · `Member Card` · `Author Follow` · `Book Review` · `Event` / `Event Registration` · `Room` / `Room Booking` · `Reading Challenge` / enrollment / achievement · `Branch` / `Branch Transfer` · `Fine Appeal` · `Membership Hold` · `No-Show Processing` · `Library Closure` · `Privacy Request` · `Operation Audit` · `Risk Alert` · `Executive Summary` · `Payment Receipt` · `Catalog Import` · `Stocktake` · `Copy Repair` · `Confirmation`.

Why: dedicated objects were planned but not queryable in the org's metadata index yet. `LibraryLedgerMigrationReadinessService` reports what could be moved later. Always filter by `Operation__c` **and** member.

## Sharing summary

Private: members, loans, reservations, fines, payments, notifications, registration, ledger, sessions, chat sessions, analytics. Public read: books, authors, categories, plans. Settings: ReadWrite. See `sharingRules/`, `sharingSets/`.
