# Data Cloud Implementation Blueprint

Audit date: 2026-10-13  
Target org: `library-org`  
Status: Data Cloud is live in the target org. User-provided Data Cloud Setup evidence shows 1 data space, 2 connections, and 11 Salesforce CRM data streams. Agentforce activation is tracked separately. DLO/DMO mappings, relationships, calculated insights, identity resolution, segments, activations, and runtime grounding still require verification.

## Current org evidence

- Data Cloud instance is live and connected to the home org.
- Eleven library streams are configured and active in the Data Streams view.
- Most visible streams show successful runs.
- `Library Book Author` shows a failed run and must be investigated before production sign-off.
- `Library Member` shows a warning/error indicator and must be checked for ingestion or mapping errors.

## 1. Governing decisions

- `Member__c.Id` is the canonical Salesforce source and reconciliation key.
- Production inclusion is `Member_Type__c = 'Production'`; do not add `Status__c = 'Active'`.
- Authentication, session, credential, token, lockout, and diagnostic fields are excluded.
- `Member_Session__c` is always excluded.
- Contact Point Phone is deferred until E.164 normalization, placeholder removal, duplicate resolution, and verification are complete.
- `Membership_Payment__c` and payment-related Agentforce use are deferred.
- Email may be mapped as a governed Contact Point Email, but never as the Individual primary key.
- Existing Contacts remain a Salesforce sharing/identity bridge. Do not create Contacts merely for Data Cloud.

Current verified member population: Production 7, Demo 10, Test 4, UAT 20, unclassified 0.

## 2. Implementation waves

| Source object                                                                           | Classification                      | Reason                                                                                                 |
| --------------------------------------------------------------------------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `Member__c`                                                                             | WAVE 1                              | Canonical member profile and production boundary                                                       |
| `Membership_Plan__c`                                                                    | WAVE 1                              | Membership policy and current-plan context                                                             |
| `Borrow_Record__c`                                                                      | WAVE 1                              | Active-loan and overdue context                                                                        |
| `Reservation__c`                                                                        | WAVE 1                              | Reservation context and demand                                                                         |
| `Fine__c`                                                                               | WAVE 1                              | Fine balance and loan-linked obligations                                                               |
| `Book__c`                                                                               | WAVE 1                              | Basic catalog context                                                                                  |
| `Book_Copy__c`                                                                          | WAVE 2                              | Physical availability and copy-level context                                                           |
| `Author__c`                                                                             | WAVE 2                              | Catalog discovery and recommendations                                                                  |
| `Book_Author__c`                                                                        | WAVE 2                              | Many-to-many book/author relationship                                                                  |
| `Book_Category__c`                                                                      | WAVE 2                              | Catalog taxonomy                                                                                       |
| `Book_Category_Link__c`                                                                 | WAVE 2                              | Many-to-many book/category relationship                                                                |
| `Member_Notification__c`                                                                | WAVE 3                              | Engagement and notification history                                                                    |
| `Library_Registration__c`                                                               | WAVE 3                              | Registration funnel and provisioning operations                                                        |
| `Reservation_Audit__c`                                                                  | WAVE 3                              | Reservation lifecycle history                                                                          |
| `Membership_Payment__c`                                                                 | DEFER                               | Payment ingestion is explicitly out of scope                                                           |
| `Contact`                                                                               | EXCLUDE from library source streams | Do not duplicate Contact as the canonical member; use only governed identity mapping if later required |
| `Member_Session__c`                                                                     | EXCLUDE                             | Session tokens and session security data                                                               |
| `Library_Settings__c`, `Library_Experience_Config__mdt`, `Library_Schema_Diagnostic__c` | EXCLUDE                             | Configuration and diagnostics, not member-domain analytics                                             |

## 3. Exact source field inventory

`Id`, `Name`, `CreatedDate`, and `LastModifiedDate` below refer to standard Salesforce fields where applicable. `Include` means eligible for the corresponding stream after field-level governance; it does not authorize member-facing activation.

### Wave 1 — Member and membership

| Object               | Field API name                                                                      | Type                       | Business meaning                    | Include         | Sensitive | Data Cloud purpose                                    |
| -------------------- | ----------------------------------------------------------------------------------- | -------------------------- | ----------------------------------- | --------------- | --------- | ----------------------------------------------------- |
| `Member__c`          | `Id`                                                                                | Id                         | Canonical member key                | Yes             | No        | Individual/source reconciliation key                  |
| `Member__c`          | `Contact__c`                                                                        | Lookup(Contact)            | Existing Salesforce contact bridge  | Yes, restricted | Yes       | Optional governed Contact relationship                |
| `Member__c`          | `User__c`                                                                           | Lookup(User)               | Experience user bridge              | No              | Yes       | Do not expose platform-user identity                  |
| `Member__c`          | `First_Name__c`, `Last_Name__c`                                                     | Text                       | Member name                         | Yes, restricted | Yes       | Individual name when Contact is not authoritative     |
| `Member__c`          | `Email__c`                                                                          | Email                      | Member email                        | Yes, restricted | Yes       | Contact Point Email value                             |
| `Member__c`          | `Normalized_Email__c`                                                               | Text                       | Matching aid                        | No              | Yes       | Never a primary identity key                          |
| `Member__c`          | `Phone__c`                                                                          | Phone                      | Member phone                        | No              | Yes       | Contact Point Phone deferred                          |
| `Member__c`          | `Email_Verified__c`                                                                 | Checkbox                   | Email verification state            | Yes, restricted | Yes       | Verification attribute, not identity proof            |
| `Member__c`          | `Member_Type__c`                                                                    | Picklist                   | Production/test/demo/UAT governance | Yes             | No        | Production inclusion filter                           |
| `Member__c`          | `Status__c`                                                                         | Picklist                   | Operational membership state        | Yes             | No        | Historical/current status attribute                   |
| `Member__c`          | `Account_Status__c`                                                                 | Picklist                   | Account operational state           | No              | No        | Keep out unless a later governed use case requires it |
| `Member__c`          | `Membership_Plan__c`                                                                | Lookup(Membership_Plan__c) | Current plan relationship           | Yes             | No        | Individual-to-plan relationship                       |
| `Member__c`          | `Membership_Start_Date__c`, `Membership_End_Date__c`                                | Date                       | Membership term                     | Yes             | No        | Membership lifecycle                                  |
| `Member__c`          | `Registration_Date__c`                                                              | Date                       | Member registration date            | Yes             | No        | Member lifecycle                                      |
| `Member__c`          | `Max_Borrow_Limit__c`                                                               | Number                     | Member borrowing limit              | Yes             | No        | Entitlement context                                   |
| `Member__c`          | `Interests__c`                                                                      | Text                       | Member preferences                  | Yes, restricted | Yes       | Personalization only after governance                 |
| `Member__c`          | `Date_of_Birth__c`, `Address__c`                                                    | Date, LongTextArea         | Sensitive profile data              | No              | Yes       | Excluded from initial model                           |
| `Member__c`          | `External_Auth_Id__c`                                                               | Text                       | Legacy external auth identifier     | No              | Yes       | Authentication data                                   |
| `Member__c`          | `Password_Hash__c`, `Password_Salt__c`                                              | Text                       | Credential material                 | No              | Yes       | Never ingest                                          |
| `Member__c`          | `Activation_Token_Hash__c`, `Reset_Token_Hash__c`                                   | Text                       | Token material                      | No              | Yes       | Never ingest                                          |
| `Member__c`          | `Activation_Token_Expires_At__c`, `Reset_Token_Expires_At__c`                       | DateTime                   | Token expiry internals              | No              | Yes       | Never ingest                                          |
| `Member__c`          | `Failed_Login_Count__c`, `Last_Failed_Login__c`, `Locked_Until__c`, `Last_Login__c` | Number, DateTime           | Security/diagnostic state           | No              | Yes       | Never ingest                                          |
| `Membership_Plan__c` | `Id`, `Name`                                                                        | Id, Text                   | Plan identity                       | Yes             | No        | Plan key and label                                    |
| `Membership_Plan__c` | `Description__c`                                                                    | LongTextArea               | Plan description                    | Yes, restricted | Yes       | Plan presentation if approved                         |
| `Membership_Plan__c` | `Fee__c`, `Fine_Per_Day__c`                                                         | Currency                   | Plan financial policy               | Yes, internal   | Yes       | Internal plan analytics                               |
| `Membership_Plan__c` | `Duration_Days__c`, `Loan_Duration_Days__c`                                         | Number                     | Term/loan policy                    | Yes             | No        | Entitlement and policy                                |
| `Membership_Plan__c` | `Borrow_Limit__c`, `Reservation_Limit__c`, `Renewal_Limit__c`                       | Number                     | Plan limits                         | Yes             | No        | Entitlement context                                   |
| `Membership_Plan__c` | `Active__c`                                                                         | Checkbox                   | Plan availability                   | Yes             | No        | Current-plan attribute                                |

### Wave 1 — Transactions and catalog

| Object             | Field API names and types                                                                                                                                                                                                                                                                                                | Include       | Sensitive                    | Data Cloud purpose                               |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------- | ---------------------------- | ------------------------------------------------ |
| `Borrow_Record__c` | `Id` (Id); `Member__c`, `Book_Copy__c`, `Contact__c` (Lookups); `Borrow_Date__c`, `Due_Date__c`, `Return_Date__c`, `Last_Renewed_Date__c`, `Defect_Reported_Date__c`, `Replacement_Date__c` (DateTime); `Status__c` (Picklist); `Renewal_Count__c`, `Replacement_Days__c` (Number); `Replacement_Required__c` (Checkbox) | Yes           | Contact restricted           | Loan and overdue context                         |
| `Borrow_Record__c` | `Notes__c` (LongTextArea)                                                                                                                                                                                                                                                                                                | No            | Yes                          | Free text can contain uncontrolled PII           |
| `Reservation__c`   | `Id` (Id); `Member__c`, `Book__c`, `Book_Copy__c`, `Contact__c` (Lookups); `Reservation_Date__c`, `Expiry_Date__c`, `Ready_Date__c`, `Fulfilled_Date__c` (DateTime); `Queue_Position__c` (Number); `Status__c` (Picklist)                                                                                                | Yes           | Contact restricted           | Reservation context and demand                   |
| `Fine__c`          | `Id` (Id); `Member__c`, `Borrow_Record__c`, `Contact__c` (Lookups); `Fine_Type__c`, `Status__c` (Picklists); `Amount__c`, `Paid_Amount__c`, `Balance__c` (Currency); `Generated_Date__c`, `Paid_Date__c` (Date)                                                                                                          | Yes, internal | Financial/contact restricted | Outstanding fine and payment-state analytics     |
| `Fine__c`          | `Notes__c` (LongTextArea)                                                                                                                                                                                                                                                                                                | No            | Yes                          | Uncontrolled free text                           |
| `Book__c`          | `Id`, `Name` (Id, Text); `ISBN__c`, `Publisher__c`, `Edition__c` (Text); `Publication_Year__c`, `Total_Copies__c`, `Available_Copies__c` (Number); `Language__c`, `Status__c` (Picklists); `Cover_Image_URL__c` (Url)                                                                                                    | Yes           | No                           | Catalog and availability context                 |
| `Book__c`          | `Description__c` (LongTextArea)                                                                                                                                                                                                                                                                                          | No initially  | Possible content/PII         | Add only for an approved catalog-search use case |

### Wave 2 — Catalog enrichment

| Object                  | Field API names and types                                                                                                                                                   | Include                           | Data Cloud purpose                                                            |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- | ----------------------------------------------------------------------------- |
| `Book_Copy__c`          | `Id` (Id); `Book__c` (MasterDetail); `Barcode__c`, `Shelf_Location__c` (Text); `Status__c`, `Condition__c` (Picklists); `Acquisition_Date__c` (Date); `Price__c` (Currency) | Yes, price internal               | Physical availability and location                                            |
| `Author__c`             | `Id`, `Name` (Id, Text); `Country__c` (Text)                                                                                                                                | Yes                               | Author discovery                                                              |
| `Author__c`             | `Biography__c` (LongTextArea)                                                                                                                                               | No initially                      | Add only for approved recommendation/RAG use                                  |
| `Book_Category__c`      | `Id`, `Name` (Id, Text); `Description__c` (LongTextArea); `Active__c` (Checkbox)                                                                                            | Yes, description restricted       | Catalog taxonomy                                                              |
| `Book_Author__c`        | `Id`, `Name` (Id, AutoNumber); `Book__c`, `Author__c` (MasterDetail); `Author_Order__c` (Number); `Book_Author_Key__c` (Text)                                               | Id, both foreign keys, order only | Preserve many-to-many author relationships; exclude redundant composite key   |
| `Book_Category_Link__c` | `Id`, `Name` (Id, AutoNumber); `Book__c`, `Book_Category__c` (MasterDetail); `Book_Category_Key__c` (Text)                                                                  | Id and both foreign keys          | Preserve many-to-many category relationships; exclude redundant composite key |

### Wave 3 — Engagement and operations

| Object                    | Field API names and types                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Include                                                     | Sensitive               | Data Cloud purpose               |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- | ----------------------- | -------------------------------- |
| `Member_Notification__c`  | `Id`, `Name` (Id, AutoNumber); `Member__c`, `Contact__c` (Lookups); `Related_Record__c`, `Subject__c`, `Type__c` (Text); `Status__c`, `Email_Status__c` (Picklists); `Message__c` (LongTextArea); `Read_At__c` (DateTime)                                                                                                                                                                                                                                                                                                                                                                                                   | Yes, message restricted                                     | Contact/message content | Notification history             |
| `Member_Notification__c`  | `Dedup_Key__c` (Text)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | No                                                          | Yes                     | Internal idempotency key         |
| `Library_Registration__c` | `Id`, `Name` (Id, AutoNumber); `First_Name__c`, `Last_Name__c` (Text); `Email__c` (Email); `Phone__c` (Phone); `Date_of_Birth__c` (Date); `Address__c` (LongTextArea); `Interests__c` (Text); `Requested_Plan__c`, `Created_Member__c`, `Created_Contact__c`, `Approved_By__c`, `External_User__c`, `Provisioned_User__c` (Lookups); `Registration_Date__c`, `Approved_Date__c` (DateTime); `Status__c`, `Provisioning_State__c`, `Provisioning_Status__c` (Picklists); `Rejection_Reason__c`, `Provisioning_Message__c`, `Provisioning_Error__c` (LongTextArea); `Registration_Email_Key__c`, `Normalized_Email__c` (Text) | Lifecycle fields, restricted PII                            | Yes                     | Registration funnel analytics    |
| `Library_Registration__c` | `External_Auth_Id__c` (Text)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | No                                                          | Yes                     | Legacy authentication identifier |
| `Reservation_Audit__c`    | `Id`, `Name` (Id, AutoNumber); `Reservation__c`, `Actor__c` (Lookups); `Action__c`, `From_Status__c`, `To_Status__c`, `Notes__c` (Text); `Occurred_At__c` (DateTime); `Queue_Position__c` (Number)                                                                                                                                                                                                                                                                                                                                                                                                                          | Yes except actor/user and uncontrolled notes as appropriate | Yes for actor/notes     | Reservation operational history  |

## 4. Streams, DLOs, and production filtering

These are design names only. They are not deployed Data Cloud resources.

| Data Stream                    | Source                    | Wave | Refresh                                                                 | Filter                                                                | Notes                                 |
| ------------------------------ | ------------------------- | ---- | ----------------------------------------------------------------------- | --------------------------------------------------------------------- | ------------------------------------- |
| `DS_Library_Member`            | `Member__c`               | 1    | Frequent incremental; near real-time only if member context requires it | `Member_Type__c = 'Production'`                                       | Exclude security fields               |
| `DS_Library_Membership_Plan`   | `Membership_Plan__c`      | 1    | Daily incremental                                                       | Active and historical plans; no member filter                         | Preserve plan history                 |
| `DS_Library_Loan`              | `Borrow_Record__c`        | 1    | Frequent incremental                                                    | Related `Member__c.Member_Type__c = 'Production'`                     | Must retain historical returned loans |
| `DS_Library_Reservation`       | `Reservation__c`          | 1    | Frequent incremental                                                    | Related member is Production                                          | `Book_Copy__c` optional               |
| `DS_Library_Fine`              | `Fine__c`                 | 1    | Daily or frequent incremental                                           | Related member is Production                                          | Internal-only financial access        |
| `DS_Library_Book`              | `Book__c`                 | 1    | Daily incremental                                                       | Active catalog plus historical books as needed                        | Initial catalog context               |
| `DS_Library_Book_Copy`         | `Book_Copy__c`            | 2    | Daily; more frequent if availability is operational                     | Related book is in governed catalog                                   | Physical availability                 |
| `DS_Library_Author`            | `Author__c`               | 2    | Daily incremental                                                       | None                                                                  | Catalog enrichment                    |
| `DS_Library_Book_Author`       | `Book_Author__c`          | 2    | Daily incremental                                                       | Related book is governed                                              | Preserve junction                     |
| `DS_Library_Category`          | `Book_Category__c`        | 2    | Daily incremental                                                       | None                                                                  | Catalog taxonomy                      |
| `DS_Library_Book_Category`     | `Book_Category_Link__c`   | 2    | Daily incremental                                                       | Related book is governed                                              | Preserve junction                     |
| `DS_Library_Notification`      | `Member_Notification__c`  | 3    | Daily or frequent incremental                                           | Related member is Production                                          | Restrict message content              |
| `DS_Library_Registration`      | `Library_Registration__c` | 3    | Daily incremental                                                       | Approved/completed lifecycle and governed member relation as required | Do not ingest auth identifiers        |
| `DS_Library_Reservation_Audit` | `Reservation_Audit__c`    | 3    | Daily incremental                                                       | Related reservation belongs to Production member                      | Operational history                   |

The required child predicate is `Member__r.Member_Type__c = 'Production'` for loans, reservations, fines, notifications, and registration-derived member data. CRM Data Stream filter support for related-object criteria must be verified in the target Data Cloud connector. If direct relationship filtering is unavailable, use a source-side filtered replication/view or ingest into a governed staging DLO and apply the relationship predicate before the production DMO/Data Space; do not claim that an unfiltered child stream is production-only.

| Source                    | Data Stream                    | Proposed DLO                   | Primary key                  | Foreign keys                                    |
| ------------------------- | ------------------------------ | ------------------------------ | ---------------------------- | ----------------------------------------------- |
| `Member__c`               | `DS_Library_Member`            | `LibraryMember__dlm`           | `Member__c.Id`               | `Membership_Plan__c`, optional `Contact__c`     |
| `Membership_Plan__c`      | `DS_Library_Membership_Plan`   | `LibraryMembershipPlan__dlm`   | `Membership_Plan__c.Id`      | None                                            |
| `Borrow_Record__c`        | `DS_Library_Loan`              | `LibraryLoan__dlm`             | `Borrow_Record__c.Id`        | `Member__c`, `Book_Copy__c`                     |
| `Reservation__c`          | `DS_Library_Reservation`       | `LibraryReservation__dlm`      | `Reservation__c.Id`          | `Member__c`, `Book__c`, optional `Book_Copy__c` |
| `Fine__c`                 | `DS_Library_Fine`              | `LibraryFine__dlm`             | `Fine__c.Id`                 | `Member__c`, `Borrow_Record__c`                 |
| `Book__c`                 | `DS_Library_Book`              | `LibraryBook__dlm`             | `Book__c.Id`                 | None                                            |
| `Book_Copy__c`            | `DS_Library_Book_Copy`         | `LibraryBookCopy__dlm`         | `Book_Copy__c.Id`            | `Book__c`                                       |
| `Author__c`               | `DS_Library_Author`            | `LibraryAuthor__dlm`           | `Author__c.Id`               | None                                            |
| `Book_Author__c`          | `DS_Library_Book_Author`       | `LibraryBookAuthor__dlm`       | `Book_Author__c.Id`          | `Book__c`, `Author__c`                          |
| `Book_Category__c`        | `DS_Library_Category`          | `LibraryCategory__dlm`         | `Book_Category__c.Id`        | None                                            |
| `Book_Category_Link__c`   | `DS_Library_Book_Category`     | `LibraryBookCategory__dlm`     | `Book_Category_Link__c.Id`   | `Book__c`, `Book_Category__c`                   |
| `Member_Notification__c`  | `DS_Library_Notification`      | `LibraryNotification__dlm`     | `Member_Notification__c.Id`  | `Member__c`, optional `Contact__c`              |
| `Library_Registration__c` | `DS_Library_Registration`      | `LibraryRegistration__dlm`     | `Library_Registration__c.Id` | `Requested_Plan__c`, `Created_Member__c`        |
| `Reservation_Audit__c`    | `DS_Library_Reservation_Audit` | `LibraryReservationAudit__dlm` | `Reservation_Audit__c.Id`    | `Reservation__c`                                |

## 5. DMO and relationship design

Proposed custom DMO API names use the `__dll` convention and must be confirmed against the target Data Cloud namespace before setup.

| DMO label               | Proposed API name              | Source DLO                     | Attributes / keys                              | Wave |
| ----------------------- | ------------------------------ | ------------------------------ | ---------------------------------------------- | ---- |
| Library Membership Plan | `LibraryMembershipPlan__dll`   | `LibraryMembershipPlan__dlm`   | Plan name, limits, duration, fee, active state | 1    |
| Library Loan            | `LibraryLoan__dll`             | `LibraryLoan__dlm`             | Dates, status, renewal, replacement attributes | 1    |
| Library Reservation     | `LibraryReservation__dll`      | `LibraryReservation__dlm`      | Dates, status, queue, book/copy keys           | 1    |
| Library Fine            | `LibraryFine__dll`             | `LibraryFine__dlm`             | Type, amounts, balance, status, dates          | 1    |
| Library Book            | `LibraryBook__dll`             | `LibraryBook__dlm`             | ISBN, title, catalog metadata, counts, status  | 1    |
| Library Book Copy       | `LibraryBookCopy__dll`         | `LibraryBookCopy__dlm`         | Barcode, book key, status, shelf, condition    | 2    |
| Library Author          | `LibraryAuthor__dll`           | `LibraryAuthor__dlm`           | Name and country                               | 2    |
| Library Category        | `LibraryCategory__dll`         | `LibraryCategory__dlm`         | Name, description, active state                | 2    |
| Library Book Author     | `LibraryBookAuthor__dll`       | `LibraryBookAuthor__dlm`       | Book key, author key, author order             | 2    |
| Library Book Category   | `LibraryBookCategory__dll`     | `LibraryBookCategory__dlm`     | Book key, category key                         | 2    |
| Library Notification    | `LibraryNotification__dll`     | `LibraryNotification__dlm`     | Type, status, read state, related record       | 3    |
| Library Registration    | `LibraryRegistration__dll`     | `LibraryRegistration__dlm`     | Lifecycle, plan, created-member key, dates     | 3    |
| Reservation Audit       | `LibraryReservationAudit__dll` | `LibraryReservationAudit__dlm` | Reservation key, action, statuses, timestamp   | 3    |

### Profile mapping

Map `Member__c` to the standard Individual profile model using `Member__c.Id` as the source/reconciliation key. Map `First_Name__c`/`Last_Name__c` and governed `Email__c` only where Contact is not authoritative. Map `Email__c` to Contact Point Email with `Email_Verified__c` as a separate verification attribute. Do not use email, `User__c`, or `External_Auth_Id__c` as the primary key. Contact Point Phone is **DEFERRED**.

### Relationships

| Parent DMO        | Child DMO               | Parent key                      | Child foreign key                           | Cardinality                  | Required                            |
| ----------------- | ----------------------- | ------------------------------- | ------------------------------------------- | ---------------------------- | ----------------------------------- |
| Individual        | Library Membership Plan | `LibraryMembershipPlan__dll.Id` | Individual current `Membership_Plan__c`     | Many Individuals to one Plan | Optional                            |
| Individual        | Library Loan            | Individual source key           | `LibraryLoan__dll.Member__c`                | One to many                  | Required for production loan        |
| Individual        | Library Reservation     | Individual source key           | `LibraryReservation__dll.Member__c`         | One to many                  | Required for production reservation |
| Individual        | Library Fine            | Individual source key           | `LibraryFine__dll.Member__c`                | One to many                  | Required for production fine        |
| Library Loan      | Library Fine            | Loan source key                 | `LibraryFine__dll.Borrow_Record__c`         | One to many                  | Optional                            |
| Library Book Copy | Library Loan            | Copy source key                 | `LibraryLoan__dll.Book_Copy__c`             | One to many                  | Required for loan                   |
| Library Book      | Library Book Copy       | Book source key                 | `LibraryBookCopy__dll.Book__c`              | One to many                  | Required                            |
| Library Book      | Library Reservation     | Book source key                 | `LibraryReservation__dll.Book__c`           | One to many                  | Required                            |
| Library Book Copy | Library Reservation     | Copy source key                 | `LibraryReservation__dll.Book_Copy__c`      | One to many                  | Optional                            |
| Library Book      | Library Book Author     | Book source key                 | `LibraryBookAuthor__dll.Book__c`            | One to many                  | Required junction row               |
| Library Author    | Library Book Author     | Author source key               | `LibraryBookAuthor__dll.Author__c`          | One to many                  | Required junction row               |
| Library Book      | Library Book Category   | Book source key                 | `LibraryBookCategory__dll.Book__c`          | One to many                  | Required junction row               |
| Library Category  | Library Book Category   | Category source key             | `LibraryBookCategory__dll.Book_Category__c` | One to many                  | Required junction row               |

`Book_Author__c` and `Book_Category_Link__c` remain junction DMOs; do not flatten them because recommendation and catalog use cases need many-to-many relationships. `Membership_Plan__c` is a relationship from the current Member record, not a copied set of plan attributes. Historical plan versioning is not currently modeled; introduce a membership-history object or effective-dated plan relationship before historical plan analytics is required.

## 6. Validation rules before ingestion

- Member: `Member_Type__c = 'Production'`, stable `Id`, valid email for Contact Point Email, no authentication/security fields.
- Loan: Member and Book Copy exist; due date is not before borrow date; valid `Status__c`; returned/active dates are coherent.
- Reservation: Member and Book exist; optional copy is valid; expiry is not before reservation date; valid `Status__c`.
- Fine: Member and Borrow Record exist; amount and paid amount are nonnegative; paid amount does not exceed amount; valid status.
- Book: stable `Id`, title/name present, catalog status valid, ISBN governed if used as a secondary catalog key.
- Book Copy: Book exists, barcode is present/unique, status and condition are valid.
- Author/category: stable `Id` and name present.
- Junctions: both parents exist; no duplicate parent pair; exclude redundant composite key fields.
- Notification: Production member exists; valid type/status; deduplication key remains internal.
- Registration: lifecycle status valid; no auth identifiers; include only approved/completed records or explicitly separate funnel analytics.
- Reservation Audit: Reservation exists; timestamp and action are present; actor/user is restricted.

## 7. Identity Resolution, insights, and graphs

### Identity Resolution

Defer Identity Resolution. There is one canonical Salesforce source, a stable `Member__c.Id`, and no current duplicate normalized-email groups. Reconsider when multiple source systems, multiple orgs, external identity sources, or proven duplicate cross-source members are introduced. Until then, use deterministic source-key reconciliation and do not merge on email alone.

### First five Calculated Insights

| Insight                  | Sources           | Measure                          | Dimension        | Agentforce value                         |
| ------------------------ | ----------------- | -------------------------------- | ---------------- | ---------------------------------------- |
| Active loan count        | Loan              | Count where `Status__c = Active` | Individual       | “What do I currently have?”              |
| Overdue count and days   | Loan              | Count and max overdue days       | Individual, book | Proactive overdue summary                |
| Outstanding fine balance | Fine              | Sum `Balance__c`                 | Individual       | Fine context with internal authorization |
| Reservation activity     | Reservation       | Count pending/ready/fulfilled    | Individual, book | Reservation context                      |
| Book popularity          | Loan, Reservation | Loan/reservation counts          | Book, category   | Demand analysis and recommendations      |

Do not implement these until stream row counts, relationships, and security are verified.

### First Data Graphs

| Data Graph        | Root         | Related DMOs                                   | Primary use                               |
| ----------------- | ------------ | ---------------------------------------------- | ----------------------------------------- |
| Member 360        | Individual   | Membership Plan, Loan, Reservation, Fine       | Internal/member-authorized member context |
| Loan Context      | Individual   | Loan, Book Copy, Book, Fine                    | Active loan and overdue handling          |
| Catalog Discovery | Library Book | Author, Category, Book Copy, Loan, Reservation | Catalog search, availability, demand      |

## 8. Agentforce dependency matrix

| Agentforce use case    | Agent type | Required DMO                                         | Required graph                 | Wave required |
| ---------------------- | ---------- | ---------------------------------------------------- | ------------------------------ | ------------- |
| Member summary         | Internal   | Individual, Membership Plan, Loan, Reservation, Fine | Member 360                     | 1             |
| Overdue summary        | Internal   | Loan, Book Copy, Fine                                | Loan Context                   | 1–2           |
| Demand analysis        | Internal   | Loan, Reservation, Book, Category                    | Catalog Discovery              | 1–2           |
| Reservation context    | Internal   | Reservation, Book, Book Copy                         | Member 360 / Catalog Discovery | 1–2           |
| Catalog lookup         | Internal   | Book, Copy, Author, Category                         | Catalog Discovery              | 1–2           |
| My loans               | External   | Individual, Loan, Book                               | Member 360 / Loan Context      | 1             |
| My reservations        | External   | Individual, Reservation, Book                        | Member 360                     | 1             |
| My fines               | External   | Individual, Fine                                     | Member 360                     | 1             |
| Membership information | External   | Individual, Membership Plan                          | Member 360                     | 1             |
| Recommendations        | External   | Book, Author, Category, Copy, demand insights        | Catalog Discovery              | 2             |

External use cases require record-level authorization and must not expose credentials, session data, internal financial data, staff/user IDs, or unrestricted free text.

## 9. Data quality and runtime acceptance

Before activation, verify: stream activation state; source/DLO row counts; rejected rows; production filter counts; DLO primary-key uniqueness; DMO mapping coverage; relationship population; Contact Point Email verification handling; and member-facing authorization. A source file or proposed DLO name is not evidence that a Data Stream exists.

### Code-managed vs Data Cloud setup

Codex can prepare this blueprint, source field governance, filters/documentation, validation utilities, and tests. Data Cloud Setup must create and activate actual Data Streams, DLOs, DMOs, relationships, mappings, Data Spaces, Data Graphs, Calculated Insights, segments, and activations where those resources are not deployable from this Salesforce source repository. Runtime owners must verify activation, ingestion errors, counts, mappings, relationships, retention, and authorization.

## 10. Final status

The source model is **READY FOR DATA CLOUD BLUEPRINT**. It is not yet ready for Data Cloud resource creation until Data Cloud is enabled/provisioned, connector support for related-object production filtering is confirmed, governance for Contact PII/internal financial data is approved, and runtime row-count/relationship tests are completed.

No Data Streams or Agentforce configuration were created in this phase. Payments, Contact Point Phone, Identity Resolution, and payment-related Agentforce functionality remain deferred.
