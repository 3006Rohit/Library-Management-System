# Analytics & insights

## Dashboard analytics — `LibraryDataCloudService`

`getRealtimeLibrarianAnalytics`, `getLibrarianAnalytics`, `getMemberAnalytics(memberId)`, `getRealtimeMemberAnalytics`. Returns DTOs for the librarian dashboard and the member "My analytics" tab. Calculated insights it expects (set up by an admin, see [SETUP](../../SETUP.md)): `Library_Copy_Availability__cio`, `Library_Member_Loan_Activity__cio`, `Library_Member_Reservation_Activity__cio`, `Library_Member_Fine_Activity__cio`, `Library_Book_Popularity__cio`, `Library_Reservation_Demand__cio`. The service reads live Salesforce data when insights are unavailable.

## Data Cloud readiness — `LibraryDataCloudReadinessService.getStatus()`

Source-quality check only (it does **not** claim streams or insights exist): counts `Production` vs unclassified members (`Member_Type__c`), non-production loans/reservations/fines, orphaned children, and verified-email warnings. Result `Blocked` / `Ready with warnings` / `Ready` plus a versioned, secret-free handoff contract (governed objects, predicates, five approved calculated-insight definitions) that librarians download as JSON. Classification script: `scripts/apex/classify-member-types.apex`. Deep dive: [DATA_CLOUD docs](../../DATA_CLOUD_SOURCE_READINESS.md).

## Acquisition intelligence — `LibraryAcquisitionInsightService`

1. Build per-title signals from a rolling **90-day** window (reservations, checkouts, availability, damaged/lost).
2. Send them to prompt template `Library_Acquisition_Advisor` ([README](../../../force-app/main/default/genAiPromptTemplates/README.md)).
3. Persist **new immutable snapshots** `Acquisition_Recommendation__c` (unique `Snapshot_Key__c`) — never overwrite earlier evidence.
4. Librarian `decide(...)`: accept / defer / reject with note (`libraryAcquisitionDashboard`).
5. `recordSearchTelemetry` logs hashed zero-result searches (`Search_Analytics__c`) to reveal unmet demand.

## Room insights

`LibraryRoomInsightService` — utilisation and busy-time forecast for librarians, members and agents ([events-rooms-calendar](../events-rooms-calendar/README.md)).

## Ledger migration readiness

`LibraryLedgerMigrationReadinessService.getStatus()` inventories the private ledger by `Operation__c`: rows with stable migration metadata, malformed/unknown rows, planned target objects, and whether each target object is actually deployed (missing target = explicit blocker). Librarians download a versioned JSON manifest and `LibraryLedgerMigrationReviewService.recordReview(...)` stores one idempotent, audited review (planning checkpoint only; no data moves).

## Schema validation

`LibrarySchemaValidation.validate()` → `scripts/apex/validate-library-schema.apex` / `scripts/validate-library-schema.ps1`; fails if the runtime schema lacks something the code needs.

## Tests

`LibraryAcquisitionInsightServiceTest`, `LibraryDataCloudServiceTest`, `LibraryDataCloudReadinessServiceTest`, `LibraryLedgerMigrationTest`, `LibraryLedgerMigrationReviewTest`, `LibraryRoomInsightServiceTest`.
