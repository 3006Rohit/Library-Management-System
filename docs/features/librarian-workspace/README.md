# Librarian workspace & governance

Entry: App Launcher → _Library Management_ → **Library Librarian Workspace** tab → LWC `libraryLibrarianWorkspace` → `LibraryLibrarianController` (with sharing) → services.

## Sections of the workspace

| Section                               | Backing methods (`LibraryLibrarianController`)                                                                                                                 |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Dashboard & analytics                 | `getDashboard`, `getDashboardAnalytics` (Data Cloud service with fallback)                                                                                     |
| Books / copies / authors / categories | `searchBooks`, `getBookDetail`, `addBook`, `updateBook`, `addCopy`, `updateCopy`, `searchCopies`, `getAuthors`, `getCategories`                                |
| Members                               | `searchMembers`, `getMemberDetail`, `addMember`, `updateMember`, `setMemberAccountStatus` (suspend/reactivate), `resetMemberPassword`, `renewMemberMembership` |
| Registrations                         | `getRegistrations` + `LibraryExternalRegistrationController` approve/reject/retry                                                                              |
| Circulation                           | `checkout`, `returnLoan`, `renewLoan`, `getLoans`, `approveBorrowRequest`, `rejectBorrowRequest`                                                               |
| Reservations                          | `getReservations`, `createReservation`, `cancelReservation`, `prepareReservation`, `issueReservedBook`, `processExpiredReservations`                           |
| Fines & payments                      | `getFines`, `recordFinePayment`, `waiveFine`, `getPayments`, `getMembershipPlans`, `saveMembershipPlan`                                                        |
| Settings                              | `LibrarySettingsController.getSettings/saveSettings` (`Library_Settings__c`)                                                                                   |
| Reports                               | notification delivery summary/retry, Data Cloud readiness, ledger migration review, payments, executive summary                                                |
| Assistant                             | `LibraryAgentApiController` (librarian agent)                                                                                                                  |

Specialised panels (separate LWCs): acquisition, closures, rooms, room bookings, room insights, repairs, damage/replacement, stocktake, catalog import, ISBN, review moderation, holds, privacy, risk alerts, audit trail, payment operations, executive summary — see [lwc README](../../../force-app/main/default/lwc/README.md).

## Governance services

- **Permissions:** `LibraryPolicyService.require('Manage_Library_…')` at the top of each privileged method.
- **Audit — `LibraryOperationAuditService`:** `record(operation, target, result, before, after, reason, correlationId)` stores actor, permission context and **SHA-256 digests** of before/after state (secret-like fields stripped first). `getRecent(operation?)` powers `libraryLibrarianAuditTrail`. Requires registration-management permission.
- **Risk — `LibraryRiskInsightService`:** `scan()` evaluates explainable patterns over 90 days (e.g. repeated replacement-required loans, frequent waivers) and creates idempotent member-scoped alerts with score + evidence; `decide(alertId, status, reviewerNote)` resolves or marks false-positive. **Advisory only** — never suspends or blocks automatically. UI `libraryLibrarianRiskAlerts`.
- **Executive summary — `LibraryExecutiveSummaryService`:** one idempotent aggregate snapshot per reporting day (circulation, membership, reservations, fines, risk, no-shows), also run by `LibraryExecutiveSummaryScheduler`; counts only, no member records. UI `libraryExecutiveSummary`.

## Tests

`LibraryLibrarianOperationsTest`, `LibraryOperationAuditServiceTest`, `LibraryRiskInsightServiceTest`, `LibraryExecutiveSummaryServiceTest`, `LibrarySettingsControllerTest`; Jest `libraryLibrarianWorkspace`.
