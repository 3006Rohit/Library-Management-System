# `classes/` — Apex

154 Apex classes (about 94 production, 60 test classes including `LibraryTestDataFactory`). They follow a strict layering:

```
LWC / Agent  →  Controller / Action  →  Service  →  SObjects (+ private ledger)
                       ↑ policy (LibraryPolicyService), audit (LibraryOperationAuditService),
                         identity (LibraryMemberSessionService) are called by every layer
```

`with sharing` = runs under the caller's access; `without sharing` = deliberate elevation (the class re-applies scope by member, session token, or custom permission).

---

## 1. Identity, sessions, authentication

| Class                            | Role                                                                                                                                                                                                                                                       |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `LibraryMemberAuthController`    | Public entry points: `register`, `login`, `logout`, `activateAccount`, `forgotPassword`, `resetPassword`, `changePassword`, `issueActivation`, `validateSession`.                                                                                          |
| `LibraryMemberPasswordService`   | Policy check, salt (`newSalt`), hash (`hash(salt,password)`), `matches`, random `token()`, `tokenHash()` (SHA-256). Passwords are salted+hashed, never stored raw.                                                                                         |
| `LibraryMemberSessionService`    | Creates/validates/revokes `Member_Session__c` rows. `getCurrentMember(rawToken)`, `browserMember` (strips secrets before returning to the browser), `revoke`, `revokeAll`.                                                                                 |
| `LibraryMemberIdentityService`   | `resolve()` — maps the current Salesforce user to exactly one active `Member__c` (legacy/community path).                                                                                                                                                  |
| `LibraryMemberSessionController` | **Main member API** (every method takes `sessionToken`): dashboard, catalog search, borrow, reserve, renew, fines, payments, profile, notifications, engagements, reviews, follows, events, rooms, privacy, scan, digital card, accessibility, membership. |
| `LibraryMemberController`        | Older Salesforce-user-based member API (same features without token).                                                                                                                                                                                      |

## 2. Registration & provisioning

| Class                                                                                                                    | Role                                                                                                                                                           |
| ------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `LibraryRegistrationGuestController`                                                                                     | Guest-facing API for the landing/registration pages: plans, interests, stats, currency, payment quote, `submitRegistrationWithPayment`, `searchPublicCatalog`. |
| `LibraryRegistrationController`                                                                                          | Internal (librarian) API: list/approve/reject/retry registrations.                                                                                             |
| `LibraryExternalRegistrationController`                                                                                  | Record-page API used by `libraryRegistrationReview` (approve / reject / retry / fetch).                                                                        |
| `LibraryRegistrationService`                                                                                             | Core: `submit`, `submitGuest`, `approve`, `reject`, `retry`, e-mail normalization, config names. Requires librarian permission for decisions.                  |
| `LibraryRegistrationProvisioningQueueable` → `LibraryRegistrationUserQueueable` → `LibraryRegistrationFinalizeQueueable` | Chained async pipeline that provisions Contact/User and finalises the member.                                                                                  |
| `LibraryRegistrationFailureQueueable`                                                                                    | Records provisioning failures (`record`, `recordNow`) on the registration.                                                                                     |

## 3. Catalog & inventory

| Class                         | Role                                                                                                                     |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `LibraryCatalogService`       | Librarian CRUD: `addBook`, `addCopy`, `retireCopy`, `updateBook`, `updateCopy`.                                          |
| `LibraryBookInventoryService` | `recalculate(bookIds)` — total & available copy counts (called by `BookCopyInventoryTrigger`).                           |
| `LibraryCatalogFuzzySearch`   | Near-miss title search ("A Quite Season").                                                                               |
| `LibraryCatalogImportService` | CSV import: `preview` (≤200 rows, per-row validation), `executeImport` (all-or-nothing, idempotent by `importKey`).      |
| `LibraryMetadataService`      | ISBN normalise/validate + OpenLibrary lookup via `Library_Metadata` Named Credential; `apply` writes only chosen fields. |
| `LibraryRepairService`        | Repair cases for Damaged/Lost/Maintenance copies: `open`, `openByBarcode`, `resolve`, `getAll`.                          |
| `LibraryStocktakeService`     | Shelf audits: `start`, `scan`, `close`, `getAudits`, `getLines`.                                                         |
| `LibraryBranchService`        | Branches, copy assignment, transfer lifecycle (`requestTransfer → shipTransfer → receiveTransfer`).                      |

## 4. Circulation, reservations, fines

| Class                                                                 | Role                                                                                                                                                                                                                                          |
| --------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `LibraryCirculationService`                                           | **Core engine.** `checkout`, `returnLoan`, `returnLoanForMember`, `renewLoan`, `approveBorrowRequest`/`rejectBorrowRequest`, `createReservation`, `cancelReservation`, `processExpiredReservations(Batch)`, `recordFinePayment`, `waiveFine`. |
| `LibraryMemberBorrowService`                                          | Member-initiated `request` and `checkout` for an already-resolved member.                                                                                                                                                                     |
| `LibraryPolicyService`                                                | `require(customPermission)`, `canBorrow(...)` → `PolicyResult`, `holdDurationDays()`.                                                                                                                                                         |
| `LibraryReservationWorkflowService`                                   | `prepareReservation`, `promoteAvailableReservations(bookId)` (queue promotion).                                                                                                                                                               |
| `LibraryReservationEtaService`                                        | Explainable availability estimates (`recalculateForBook(s)`).                                                                                                                                                                                 |
| `LibraryReservationAuditService`                                      | Writes `Reservation_Audit__c`.                                                                                                                                                                                                                |
| `LibraryReservationExpiryBatch` + `LibraryReservationExpiryScheduler` | Expire stale Ready holds and promote next in queue.                                                                                                                                                                                           |
| `LibraryCalendarService`                                              | Closures + `calculateDueDate` / `nextOpenDate` (due dates skip closure ranges).                                                                                                                                                               |
| `LibraryScanService`                                                  | Barcode self-checkout/return: `lookup`, `selfCheckout`, `returnItem` (idempotent).                                                                                                                                                            |
| `LibraryFineAppealService`, `LibraryMembershipHoldService`            | Member appeals and membership holds with librarian decisions.                                                                                                                                                                                 |
| `LibraryTransactionContactService`                                    | Keeps `Contact__c` lookup mirrors on loans/reservations/fines/payments/notifications in sync (used by the 6 contact triggers).                                                                                                                |

## 5. Membership & payments

| Class                             | Role                                                                                               |
| --------------------------------- | -------------------------------------------------------------------------------------------------- |
| `LibraryMembershipPaymentService` | Plan catalog, `payAndUpgrade`, `renewMembership`.                                                  |
| `LibraryPaymentGatewayService`    | Hosted checkout `initiate`, HMAC `processWebhook`, `requestRefund`, safe `getConfigurationStatus`. |
| `LibraryPaymentWebhookRest`       | `@RestResource('/library/payments/webhook')` `@HttpPost receive()`.                                |
| `LibraryPaymentOperationsService` | Receipts, reconciliation exceptions, reasoned `reconcile`.                                         |
| `LibraryDigitalMemberCardService` | Ten-minute hashed card token: `issue`, `validate` (single use).                                    |

## 6. Notifications

| Class                                     | Role                                                                    |
| ----------------------------------------- | ----------------------------------------------------------------------- |
| `LibraryMemberNotificationService`        | Create/dedupe in-app notifications; `markRead`; fan-out helpers.        |
| `LibraryNotificationPreferenceService`    | Channel/type preferences, quiet hours; `shouldDeliver`.                 |
| `LibraryNotificationDeliveryService`      | Delivery summary + recent attempts for the Reports panel.               |
| `LibraryNotificationEmailQueueable`       | Sends the e-mail attempt and records result.                            |
| `LibraryNotificationDeliveryRetryService` | Locked, bounded retries (`retryFailedDeliveries`, `processDueRetries`). |
| `LibraryNotificationScheduler`            | Hourly (:15) due-soon / overdue notices.                                |
| `LibraryNotificationRetryScheduler`       | Hourly retry of failed deliveries.                                      |

## 7. Member engagement & community

| Class                              | Role                                                                     |
| ---------------------------------- | ------------------------------------------------------------------------ |
| `LibraryMemberEngagementService`   | Reading list (state, notes, rating, notify).                             |
| `LibraryMemberAuthorFollowService` | Follow/unfollow authors.                                                 |
| `LibraryMemberReviewService`       | Submit → moderate → publish reviews.                                     |
| `LibraryChallengeService`          | Reading challenges, enrolment, badges, certificates, leaderboard opt-in. |
| `LibraryEventService`              | Events: create, register, waitlist promotion, hashed check-in token.     |
| `LibraryRoomBookingService`        | Rooms/seats: publish, availability, overlap-safe booking, cancel.        |
| `LibraryAccessibilityService`      | Language/timezone/contrast/large text/motion/screen-reader prefs.        |
| `LibraryPrivacyService`            | Export, correction, deletion requests (password re-auth).                |

## 8. Librarian operations, analytics, governance

| Class                                                                            | Role                                                                                                                                         |
| -------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `LibraryLibrarianController`                                                     | **Main librarian API** (dashboard, CRUD, circulation, fines, memberships, reports, payments, import, ISBN, stocktake, repair, audit, risk…). |
| `LibraryLibrarianSessionController`                                              | Room booking oversight for librarians.                                                                                                       |
| `LibrarySettingsController`                                                      | Read/save `Library_Settings__c`.                                                                                                             |
| `LibraryContactController`                                                       | Contact form + branch list for the public Contact page.                                                                                      |
| `LibraryAcquisitionInsightService`                                               | Purchase/replace/weed recommendations (uses the prompt template); decisions; search telemetry.                                               |
| `LibraryRiskInsightService`                                                      | 90-day advisory risk scan + review.                                                                                                          |
| `LibraryRoomInsightService`                                                      | Room utilisation insights and demand forecast.                                                                                               |
| `LibraryExecutiveSummaryService` / `…Scheduler`                                  | Daily aggregate snapshot.                                                                                                                    |
| `LibraryDataCloudService`                                                        | Realtime/Data Cloud analytics DTOs.                                                                                                          |
| `LibraryDataCloudReadinessService`                                               | Source-quality/handoff contract for Data Cloud.                                                                                              |
| `LibraryLedgerMigrationReadinessService` / `LibraryLedgerMigrationReviewService` | Inventory + review of the private-ledger migration.                                                                                          |
| `LibraryOperationAuditService`                                                   | Privileged-operation audit (`record`, `getRecent`).                                                                                          |
| `LibrarySchemaValidation`                                                        | Runtime schema checks (used by `scripts/apex/validate-library-schema.apex`).                                                                 |

## 9. Agentforce & AI

| Class                                                                                                                                              | Role                                                                                                 |
| -------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `LibraryAgentApiController`                                                                                                                        | Starts/sends/ends sessions against the Agentforce Agent API (Named Credential `Library_Agent_API`).  |
| `LibraryMemberAgentController`                                                                                                                     | Member chat controller (adds validated token to agent variables).                                    |
| `LibraryPublicAgentController`                                                                                                                     | Signed-out chat with hashed session tokens and rate limits (30 msgs/chat, 60 chats/hour, 1,500/day). |
| `LibraryAgentCatalogAction`, `LibraryPublicCatalogSummary`                                                                                         | Catalog search action; single-row summary for the public agent.                                      |
| `LibraryAgentAnalyticsAction`, `LibraryAgentCirculationDetailAction`, `LibraryAgentMemberSummaryAction`                                            | Librarian read-only actions.                                                                         |
| `LibraryAgentMyActivityAction`, `…MyLoansAction`, `…MyReservationsAction`                                                                          | Member read-only actions.                                                                            |
| `LibraryAgentPrepareTransactionAction`, `LibraryAgentConfirmationAction`, `LibraryAgentCommitTransactionAction`, `LibraryAgentConfirmationService` | Prepare → confirm → commit flow (tokens hashed, expire, single use).                                 |
| `LibraryAgentRoomAvailabilityAction`, `…RoomForecastAction`, `…RoomInsightsAction`                                                                 | Room actions.                                                                                        |
| `LibraryAgentTimeParser`                                                                                                                           | Natural-language time → `Datetime`.                                                                  |
| `LibraryPublicBranchInfoAction`, `…PoliciesAction`, `…MembershipPlansAction`, `…EventsAction`                                                      | Public-assistant actions.                                                                            |

## 10. Tests

60 `*Test.cls` classes mirror the services (e.g. `LibraryCirculationService` is covered by `LibraryLibrarianOperationsTest`, `LibraryReservationQueuePriorityTest`). `LibraryTestDataFactory` builds plans, contacts, members, registrations. Run with:

```powershell
sf apex run test --target-org library-org --test-level RunLocalTests --wait 30 --result-format human
```

## Rules when editing

1. New librarian action → add the `LibraryPolicyService.require('Manage_Library_…')` call first.
2. New member action → resolve the member from the token (`LibraryMemberSessionService.getCurrentMember`) and filter every query by that member.
3. Anything that mutates twice-safe data → give it an idempotency key.
4. Never log or return tokens, hashes, or secrets.
