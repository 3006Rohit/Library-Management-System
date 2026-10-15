# Data Cloud Source Readiness

> Superseded by the final three-wave blueprint in [DATA_CLOUD_IMPLEMENTATION_BLUEPRINT.md](DATA_CLOUD_IMPLEMENTATION_BLUEPRINT.md). Historical findings below are retained for audit traceability; use the blueprint for current classification, field governance, filters, DLO/DMO design, and readiness decisions.

Audit date: 2026-10-12  
Target org: `library-org`  
Scope: source-data preparation and design only. No Data Cloud resources were created.

## 1. Readiness summary

The Salesforce record IDs are the authoritative source primary keys. `Member__c.Id` is the canonical library-domain identity and should be the baseline reconciliation key. `Member__c.Contact__c` remains a Salesforce sharing and Experience Cloud bridge where populated. Data Cloud must not use `Member__c.User__c`, email alone, or `External_Auth_Id__c` as the identity anchor.

The catalog and transactional datasets are structurally sound, but the source is not ready for production ingestion because 8 active non-portal members have no deterministic Contact mapping, their historical transactions consequently lack Contact keys, and Experience Cloud sharing verification has unresolved failures. Data 360 also remains disabled in the org.

There is no `Membership_Subscription__c`. Current membership state belongs to `Member__c`; membership payment history belongs to `Membership_Payment__c`; fine balance and payment state belong to `Fine__c`.

## 2. Source objects and proposed semantic model

| Source object         | Proposed DLO            | Proposed DMO                              | Primary key | Foreign keys / parent                                            | Current records |
| --------------------- | ----------------------- | ----------------------------------------- | ----------- | ---------------------------------------------------------------- | --------------: |
| Contact               | Salesforce Contact DLO  | Individual plus Contact Point Email/Phone | `Id`        | `AccountId` when needed                                          |              31 |
| Member__c             | Library Member DLO      | Library Member                            | `Id`        | `Contact__c` -> Contact; `Membership_Plan__c` -> Membership Plan |              20 |
| Membership_Plan__c    | Membership Plan DLO     | Membership Plan                           | `Id`        | None                                                             |               3 |
| Membership_Payment__c | Membership Payment DLO  | Membership Payment                        | `Id`        | `Member__c`; `Contact__c`; `Previous_Plan__c`; `New_Plan__c`     |               0 |
| Borrow_Record__c      | Library Loan DLO        | Library Loan                              | `Id`        | `Member__c`; `Contact__c`; `Book_Copy__c`                        |              25 |
| Reservation__c        | Library Reservation DLO | Library Reservation                       | `Id`        | `Member__c`; `Contact__c`; `Book__c`; optional `Book_Copy__c`    |              20 |
| Fine__c               | Library Fine DLO        | Library Fine                              | `Id`        | `Member__c`; `Contact__c`; `Borrow_Record__c`                    |               7 |
| Book__c               | Library Book DLO        | Library Book                              | `Id`        | None                                                             |             106 |
| Book_Copy__c          | Book Copy DLO           | Book Copy                                 | `Id`        | `Book__c`                                                        |             362 |
| Author__c             | Author DLO              | Author                                    | `Id`        | None                                                             |              45 |
| Book_Category__c      | Book Category DLO       | Book Category                             | `Id`        | None                                                             |              12 |
| Book_Author__c        | Book Author Link DLO    | Book-Author Relationship                  | `Id`        | `Book__c`; `Author__c`                                           |             126 |
| Book_Category_Link__c | Book Category Link DLO  | Book-Category Relationship                | `Id`        | `Book__c`; `Book_Category__c`                                    |             120 |

Custom DMOs are proposed names only. During implementation, reuse a suitable standard DMO where its semantics and cardinality genuinely match; do not force library concepts into unrelated standard objects.

## 3. Identity anchor and relationships

```text
Member__c.Id (canonical library identity)
  <- Member__c.Contact__c -> Contact.Id for Salesforce sharing/contact-point context
       <- Borrow_Record__c.Member__c and Contact__c
       <- Reservation__c.Member__c and Contact__c
       <- Fine__c.Member__c and Contact__c
       <- Membership_Payment__c.Member__c and Contact__c
       -> Membership_Plan__c

Book__c
  <- Book_Copy__c.Book__c
  <- Reservation__c.Book__c
  <- Book_Author__c.Book__c -> Author__c
  <- Book_Category_Link__c.Book__c -> Book_Category__c

Book_Copy__c
  <- Borrow_Record__c.Book_Copy__c
  <- Reservation__c.Book_Copy__c (optional until a copy is allocated)

Borrow_Record__c
  <- Fine__c.Borrow_Record__c
```

Identity-resolution rules should first use the deterministic `Member__c.Id` source key. Contact ID can be a supporting Salesforce relationship. Normalized email can be a secondary, tightly governed reconciliation signal, but it must not merge two profiles by itself when Contact evidence conflicts or is absent.

## 4. Proposed ingestion allowlist

All fields not explicitly allowed should remain out of the stream until a documented analytical requirement is approved.

| Object                | Allowlisted fields                                                                                                                                                                                                                                                                                 |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Contact               | `Id`, `AccountId`, `FirstName`, `LastName`, `Email`, `Phone`, `MobilePhone`, `CreatedDate`, `LastModifiedDate`                                                                                                                                                                                     |
| Member__c             | `Id`, `Contact__c`, `Membership_Plan__c`, `Status__c`, `Account_Status__c`, `Registration_Date__c`, `Membership_Start_Date__c`, `Membership_End_Date__c`, `Max_Borrow_Limit__c`, `Interests__c`, `CreatedDate`, `LastModifiedDate`                                                                 |
| Membership_Plan__c    | `Id`, `Name`, `Active__c`, `Borrow_Limit__c`, `Reservation_Limit__c`, `Renewal_Limit__c`, `Loan_Duration_Days__c`, `Duration_Days__c`, `Fee__c`, `Fine_Per_Day__c`, `CreatedDate`, `LastModifiedDate`                                                                                              |
| Membership_Payment__c | `Id`, `Member__c`, `Contact__c`, `Previous_Plan__c`, `New_Plan__c`, `Amount__c`, `Payment_Date__c`, `Payment_Method__c`, `Status__c`, `Reconciliation_Status__c`, `Refund_Amount__c`, `Refund_Date__c`, `CreatedDate`, `LastModifiedDate`                                                          |
| Borrow_Record__c      | `Id`, `Member__c`, `Contact__c`, `Book_Copy__c`, `Borrow_Date__c`, `Due_Date__c`, `Return_Date__c`, `Last_Renewed_Date__c`, `Renewal_Count__c`, `Status__c`, `Replacement_Required__c`, `Replacement_Date__c`, `Replacement_Days__c`, `Defect_Reported_Date__c`, `CreatedDate`, `LastModifiedDate` |
| Reservation__c        | `Id`, `Member__c`, `Contact__c`, `Book__c`, `Book_Copy__c`, `Reservation_Date__c`, `Ready_Date__c`, `Expiry_Date__c`, `Fulfilled_Date__c`, `Queue_Position__c`, `Status__c`, `CreatedDate`, `LastModifiedDate`                                                                                     |
| Fine__c               | `Id`, `Member__c`, `Contact__c`, `Borrow_Record__c`, `Fine_Type__c`, `Generated_Date__c`, `Amount__c`, `Paid_Amount__c`, `Paid_Date__c`, `Balance__c`, `Status__c`, `CreatedDate`, `LastModifiedDate`                                                                                              |
| Book__c               | `Id`, `Name`, `ISBN__c`, `Edition__c`, `Language__c`, `Publication_Year__c`, `Publisher__c`, `Status__c`, `Total_Copies__c`, `Available_Copies__c`, `CreatedDate`, `LastModifiedDate`                                                                                                              |
| Book_Copy__c          | `Id`, `Book__c`, `Barcode__c`, `Acquisition_Date__c`, `Condition__c`, `Price__c`, `Shelf_Location__c`, `Status__c`, `CreatedDate`, `LastModifiedDate`                                                                                                                                              |
| Author__c             | `Id`, `Name`, `Country__c`, `CreatedDate`, `LastModifiedDate`                                                                                                                                                                                                                                      |
| Book_Category__c      | `Id`, `Name`, `Active__c`, `CreatedDate`, `LastModifiedDate`                                                                                                                                                                                                                                       |
| Book_Author__c        | `Id`, `Book__c`, `Author__c`, `Author_Order__c`, `CreatedDate`, `LastModifiedDate`                                                                                                                                                                                                                 |
| Book_Category_Link__c | `Id`, `Book__c`, `Book_Category__c`, `CreatedDate`, `LastModifiedDate`                                                                                                                                                                                                                             |

Contact name, email, and phone are identity data and require restricted Data Space, field classification, retention, and activation policies. Payment and fine amounts require internal-only governance even though they are analytically useful.

## 5. Sensitive-field exclusions

Exclude from ingestion and downstream activation unless a separately approved technical requirement proves necessity:

- `Member__c.External_Auth_Id__c`
- `Member__c.User__c`
- `Member__c.Address__c`
- `Member__c.Date_of_Birth__c`
- duplicated member `Email__c`, `Normalized_Email__c`, `Phone__c`, `First_Name__c`, and `Last_Name__c` when Contact is authoritative
- `Membership_Payment__c.Idempotency_Key__c`
- `Membership_Payment__c.Gateway_Payment_Id__c`
- `Membership_Payment__c.Gateway_Status__c`
- `Membership_Payment__c.Transaction_Reference__c`
- free-text `Borrow_Record__c.Notes__c` and `Fine__c.Notes__c`
- `Author__c.Biography__c` and `Book__c.Description__c` unless a specific recommendation/RAG use case is approved
- authentication tokens, credentials, secrets, external client secrets, service-account material, notification deduplication keys, and other internal integration identifiers

`Reconciliation_Status__c`, refund fields, financial amounts, and Contact PII may be ingested only into governed internal analytics. They must be excluded from member-facing Agentforce grounding and activation unless a narrow authorization policy explicitly permits them.

## 6. Source-quality results

| Object                | Null relationships / keys                            |                     Duplicate-key groups | Invalid statuses | Result                                                                                    |
| --------------------- | ---------------------------------------------------- | ---------------------------------------: | ---------------: | ----------------------------------------------------------------------------------------- |
| Contact               | Email: 2                                             |                                 Email: 0 |              N/A | Review the 2 Contacts without email; Contact ID remains usable                            |
| Member__c             | Contact: 10; User: 12; Plan: 0; normalized email: 10 | normalized email: 0; Contact: 0; User: 0 |                0 | Blocked for complete Member 360; 8 active members lack Contact                            |
| Membership_Plan__c    | None                                                 |                                  Name: 0 |              N/A | Ready                                                                                     |
| Membership_Payment__c | No rows                                              |                 transaction reference: 0 |                0 | Structurally ready; no production sample data                                             |
| Borrow_Record__c      | Member: 0; Contact: 12; Book Copy: 0                 |             Salesforce ID: 0 by platform |                0 | 12 rows blocked by parent members without Contact                                         |
| Reservation__c        | Member: 0; Contact: 10; Book: 0; Book Copy: 14       |                    active Member+Book: 0 |                0 | Book Copy is legitimately optional before allocation; 10 Contact gaps remain              |
| Fine__c               | Member: 0; Contact: 6; Loan: 0                       |             Salesforce ID: 0 by platform |                0 | 6 rows blocked by parent members without Contact                                          |
| Book__c               | ISBN: 0                                              |                                  ISBN: 0 |                0 | Ready                                                                                     |
| Book_Copy__c          | Book: 0; barcode: 0                                  |                               barcode: 0 |                0 | Ready                                                                                     |
| Author__c             | None                                                 |                                  Name: 0 |              N/A | Ready                                                                                     |
| Book_Category__c      | None                                                 |                                  Name: 0 |              N/A | Ready                                                                                     |
| Book_Author__c        | Book: 0; Author: 0                                   |                           Book+Author: 0 |              N/A | Ready                                                                                     |
| Book_Category_Link__c | Book: 0; Category: 0; `Book_Category_Key__c`: 120    |                         Book+Category: 0 |              N/A | Relationships are sound; omit the empty composite key and use `Id` plus both foreign keys |

Additional checks found no orphan loans/reservations/fines, negative fine values, overpayments, duplicate active reservations, or copy-status conflict for active loans. Nine returned-loan rows point to copies currently marked Borrowed, but each copy has a newer active loan; these are valid historical relationships, not anomalies.

## 7. Backfill result

The deterministic backfill populated 1 `Borrow_Record__c.Contact__c` and 2 `Reservation__c.Contact__c` values. It did not overwrite existing values. No mismatches were found. There were no payment rows. All 6 existing notifications belong to members without Contacts and remain unresolved.

## 8. Readiness blockers

1. Resolve or formally classify the 8 active members that have neither Experience user evidence nor a unique matching Contact; do not fabricate Contacts merely to satisfy ingestion.
2. Decide whether non-portal/demo members belong in Member 360. If not, add an explicit governed source filter or durable classification field.
3. Consolidate and revalidate Experience Cloud access mappings in one sharing set for the `Customer Community User` profile. Live retrieval shows that only `Library_Member_Payment_Access` retains the profile; the separate Member, Borrow, Reservation, Fine, and Notification sharing sets have no profile assignment. Real-user checks therefore denied own Member, Borrow, Fine, and Notification records even though Contact keys matched. Cross-member access remained denied.
4. Provision an ordinary librarian user, assign `Library_Librarian`, and add that user to `Library_Librarians`.
5. Enable and provision Data 360 before creating connections, streams, mappings, identity resolution, calculated insights, segments, or activations.
6. Define retention, classification, and activation controls for Contact PII and financial data.

## 9. Recommended ingestion sequence after blockers close

1. Contact, Membership Plan, Member.
2. Book, Author, Category, Book Copy, and both junctions.
3. Borrow Record, Reservation, Fine, and Membership Payment.
4. Validate DLO row counts and rejected rows.
5. Map Contact to the standard identity model and library objects to approved DMOs.
6. Configure deterministic Contact-ID identity first; evaluate normalized email only as a secondary governed rule.
7. Add calculated insights and segments only after relationship coverage and security tests pass.
