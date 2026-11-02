# Data Model

## Catalog

- `Book__c`: title, ISBN, publication metadata, status, aggregate total/available copies.
- `Book_Copy__c`: physical copy, barcode, shelf, condition, price, operational status; master-detail to Book.
- `Author__c` and `Book_Author__c`: author catalog and ordered junction.
- `Book_Category__c` and `Book_Category_Link__c`: category catalog and junction.

`BookCopyInventoryTrigger` recalculates Book totals after copy insert, update, delete, and undelete. Available copies are copies whose status is `Available`.

## Member and identity

- `Member__c`: profile, membership plan/dates/status, Contact/User legacy links, external portal fields, and accessibility/localization preferences (`Preferred_Language__c`, `Timezone__c`, `High_Contrast__c`, `Large_Text__c`, `Reduced_Motion__c`, and `Screen_Reader__c`).
- `External_Auth_Id__c`: unique, case-sensitive External ID; immutable provider UID.
- `Normalized_Email__c`: case-insensitive unique normalized email.
- `Account_Status__c`: Pending, Active, Suspended, Rejected, Inactive.
- `Email_Verified__c`, `Last_Login__c`.

`Status__c` represents library membership status; `Account_Status__c` represents portal/account eligibility. Code must check the appropriate domain and not treat them as interchangeable.

## Transactions

- `Borrow_Record__c`: Member + Book Copy, borrow/due/return dates, status, renewal and damage/replacement tracking.
- `Reservation__c`: Member + Book, optional held copy, queue position and lifecycle dates. `Estimated_Available_Date__c`, `ETA_Confidence__c`, `ETA_Last_Calculated__c`, and `ETA_Reason__c` expose the explainable server-calculated availability estimate for pending and ready reservations.
- `Fine__c`: Member + optional Borrow Record, assessed/paid/balance and status.
- `Membership_Payment__c`: membership plan transition/payment history and gateway/reconciliation placeholders. `Payment_Gateway_Config__mdt` stores provider name, enabled state, default currency, Named Credential reference, and protected webhook-secret metadata; a disabled INR-default record is deployed as the safe baseline, and secrets are never returned to clients.
- `Member_Notification__c`: member notification inbox with deduplication key.
- `Notification_Preference__c`: per-member channel/type preference, digest cadence, quiet hours, timezone, and update timestamp.
- `Notification_Delivery__c`: per-channel delivery attempt linked to a member notification, with pending/sent/delivered/failed/skipped status, attempt count, maximum-attempt policy, next-attempt time, provider/error-safe metadata, idempotency key, and timestamps.
- `Library_Scan_Transaction__c`: idempotent scan operation, member/copy/loan references, processing status, result message, and creation timestamp. The same private ledger also stores hashed confirmation tokens for assistant-initiated member transactions so retries remain safe and auditable.
- `LibraryLedgerMigrationReadinessService` provides a permission-gated, read-only inventory of this temporary ledger: known operation counts, migratable rows, malformed metadata, unknown operations, planned dedicated-object targets, and dynamic target-object metadata availability. Missing target objects are explicit blockers for rows that would need them. The librarian Reports workspace can download a versioned JSON migration manifest containing that inventory and record an idempotent, audit-backed review of the manifest with reviewer, timestamp, and note. Review records use `LibraryOperationAuditService` with `Ledger Migration Review`; they document planning only and never mutate or delete ledger rows or authorize dedicated-object migration.
- Digital member cards: the deployed service stores only a SHA-256 card-token hash in `Library_Scan_Transaction__c` with `Operation__c = 'Member Card'`, a ten-minute issuance window, and `Issued`/`Consumed` state. Raw card tokens are returned once to the member UI and never persisted.
- `Member_Book_Engagement__c`: intended member/book engagement model for reading lists, reading state, private notes, ratings, and availability-notification intent. The current runtime service uses `Library_Scan_Transaction__c` with an operation-scoped JSON payload as a private migration-safe ledger until the new object's fields are queryable in the org metadata index.
- `Author_Follow__c`: intended member/author follow model with a unique member/author key. The current runtime service uses the same private ledger with an `Author Follow` operation, preserving member isolation and idempotent follow/unfollow behavior.
- `Book_Review__c`: intended moderated member review model. The current runtime service stores compact pending review payloads in the private ledger, supports member-scoped submissions, and exposes only librarian-approved (`Published`) records for future catalog display.
- `Library_Event__c` / `Event_Registration__c`: planned event and attendance model. The deployed event foundation currently stores published event payloads and member registrations in the private scan ledger, with event capacity, registered/waitlisted/attended status, idempotent member/event keys, and hashed expiring check-in codes ready for migration.
- `Library_Room__c` / `Room_Booking__c`: planned room inventory and reservation model. The deployed room foundation stores published rooms and member bookings in the private ledger, enforcing capacity filters, eight-hour maximum windows, overlap prevention, ownership-scoped cancellation, and migration-ready room/booking payloads.
- `Reading_Challenge__c` / `Challenge_Enrollment__c`: planned goals and participation model. The deployed challenge foundation stores published goals and member enrollments in the private ledger, while progress is derived from the member's borrowing history for the challenge window.
- `Library_Branch__c` / `Branch_Transfer__c`: planned branch and copy-transfer model. The deployed branch foundation stores active branches, copy assignments, and requested/in-transit/received transfers in the private ledger with idempotent copy assignment keys.
- `Fine_Appeal__c`: planned member fine-dispute model. The deployed appeal foundation stores member-owned pending/approved/rejected appeals in the private ledger and keeps reviewer reasoning separate from the original fine.
- `Membership_Hold__c`: planned membership-pause model. The deployed hold workflow stores member-owned pending/approved/rejected requests in the private ledger with requested dates, reason, policy version, original end date, adjusted end date, and reviewer decision. An approval extends `Member__c.Membership_End_Date__c` exactly once under a locked member row.
- `No_Show_Processing__c`: planned operational run/audit model. The deployed processor records each reconciliation run in the private ledger with expired reservation, room-booking, and event-registration counts; individual stale records transition only once to `Expired`/`No-show` statuses.
- `Library_Closure__c`: planned branch-calendar model. The deployed closure workflow stores planned/emergency date ranges, branch scope, timezone, and idempotency in the private ledger; centralized due-date calculation shifts new loans and renewals past active closures.
- `Privacy_Request__c`: planned privacy workflow model. The deployed privacy center stores re-authenticated export, correction, and deletion requests in the private ledger; exports are protected `ContentVersion` files with a 24-hour expiry, while approved closure requests retain required financial/audit/safety records and anonymize member identity fields.
- `Library_Operation_Audit__c`: planned privileged-operation audit model. The deployed audit service stores compact actor, permission, operation, target, correlation, result, and before/after SHA-256 digests in the private ledger; raw secrets and payloads are never persisted, and access requires the registration-management permission.
- `Library_Risk_Alert__c`: planned anomaly-review model. The deployed risk scanner stores explainable category, score, severity, evidence window, review status, and reviewer rationale in the private ledger; alerts are advisory and never auto-suspend members or deny service.
- `Executive_Summary__c`: planned aggregate reporting model. The deployed daily summary service stores privacy-safe counts for circulation, membership, reservations, fines, risk alerts, and no-shows in the private ledger, with no record-level member data in the snapshot.
- `Payment_Receipt__c` / reconciliation model: planned financial operations model. The deployed payment operations service creates idempotent protected receipts for paid membership transactions and exposes pending/exception reconciliation states with explicit librarian decisions and audit records.
- `Catalog_Import__c`: planned import-job model. The deployed importer uses the private ledger for stable import keys and audit status while previewing CSV rows, rejecting duplicate/existing ISBNs, and committing only fully validated batches.
- `Stocktake_Audit__c` / `Stocktake_Line__c`: planned inventory audit model. The deployed stocktake workflow stores open/closed audit headers and idempotent barcode lines in the private ledger, preserving expected versus observed status and discrepancy notes without silently altering copy records.
- `Copy_Repair__c`: planned repair-case model for damaged, lost, or maintenance copies. The deployed workflow stores an idempotent open/resolved case in the private ledger, captures reason/resolution evidence, and transitions the copy to Maintenance, Available/Good, or Retired/Poor under librarian permission.
- `Book__c` catalog-quality metadata: the deployed ISBN enrichment flow uses the existing title, ISBN, publisher, edition, language, description, publication year, and cover fields with explicit field selection. Provider provenance and quality warnings remain in the preview response until a dedicated metadata snapshot object is available.
- `Membership_Payment__c`: payment lifecycle now includes Initiated, Pending, Paid, Failed, Cancelled, Disputed, Partially Refunded, and Refunded states, with gateway ID/status, currency, idempotency, and refund totals. Verified webhook events and refund intents are retained in the migration-safe operation ledger until dedicated payment webhook/refund objects are queryable.
- `Payment_Gateway_Config__mdt`: protected gateway configuration metadata for the webhook secret and default currency; production administrators must set the secret through the org's secure configuration process.
- Data Cloud source readiness is calculated from `Member__c` and related circulation records by `LibraryDataCloudReadinessService`; it is a source-quality health check, not a Data Cloud stream or calculated insight. Production-member counts, unclassified members, non-production child records, orphaned relationship rows, and verified-email warnings are exposed to the librarian Reports workspace without returning secrets or payloads. The same response carries a versioned, source-safe handoff contract with governed/deferred objects, production predicates, and the five approved calculated-insight definitions; librarians can download it as JSON for administrator-led Data Cloud setup.
- Reading challenge achievements: the deployed service stores idempotent completion badges, certificate ContentVersion references, leaderboard opt-in preferences, and anonymous leaderboard projections in the migration-safe ledger until dedicated achievement/preference objects are queryable.
- `Acquisition_Recommendation__c`: immutable evidence-windowed collection-development snapshot with action, score, confidence, evidence, quantity, status, and librarian decision fields. A unique snapshot key prevents later refreshes from overwriting evidence used for an earlier decision.
- `Search_Analytics__c`: privacy-minimized search event containing only a SHA-256 search hash, result count/status, optional matched book, and timestamp. Raw query text and member/session identifiers are intentionally not stored.
- `Agent_Confirmation__c`: confirmation model for assistant-initiated member mutations, containing action/target binding, token hash, expiry, status, idempotency key, and preview evidence. Runtime execution also uses the existing idempotent scan transaction ledger so the token cannot be replayed or transferred across members.
- `Reservation_Audit__c`: immutable-style reservation lifecycle audit records.

Direct Contact lookups on loan/reservation/fine are legacy Experience sharing mirrors maintained by triggers.

## Registration and policy

- `Library_Registration__c`: applicant, requested plan, decision, provisioning state, created records, and unique external UID/email keys.
- `Membership_Plan__c`: fee, duration, borrow/loan/reservation/renewal limits, daily fine, active flag.
- `Library_Experience_Config__mdt`: legacy Experience provisioning settings and hold duration.

## Sharing and integrity

Member, loan, reservation, fine, payment, registration, notification, and audit data are Private where defined. Catalog objects are broadly readable. Unique ISBN, barcode, junction keys, normalized email, and external UID prevent key duplicates. Validation rules enforce nonnegative values and chronological dates.
