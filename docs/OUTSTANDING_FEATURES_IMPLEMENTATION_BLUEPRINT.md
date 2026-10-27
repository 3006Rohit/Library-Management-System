# Outstanding Features Implementation Blueprint

**Project:** Salesforce Library Management System  
**Document type:** Product and technical implementation roadmap  
**Status:** In progress  
**Scope:** All member, librarian, intelligence, engagement, payment, accessibility, integration, governance, and operational features identified for the next evolution of the project

## 1. Purpose

This document defines how to evolve the existing library application into a differentiated, production-oriented Salesforce solution. It covers the complete feature set, proposed data model, Apex and Lightning Web Component (LWC) responsibilities, automations, security controls, tests, rollout order, and acceptance criteria.

This is an implementation blueprint, not a claim that the proposed features are already deployed. Every release must pass the project's existing deployment, security, Apex, LWC, and user-acceptance gates.

### Implementation progress

The first vertical slice, smart reservation ETA and queue transparency, is implemented and deployed to `library-org`. The additive `Reservation__c` ETA fields, profile/permission-set visibility, dependent Apex services/controllers, and member/librarian LWC views are live. The second slice, a session-scoped notification preference center, is implemented and deployed with the new `Notification_Preference__c` object, server-enforced email decisions, and member portal controls. The third slice, member barcode-assisted self-checkout and return, is also deployed with idempotent scan transactions, a manual-entry/camera progressive-enhancement LWC, and member-scoped circulation enforcement. The fourth slice, acquisition intelligence, is deployed with evidence-windowed `Acquisition_Recommendation__c` snapshots, privacy-minimized `Search_Analytics__c` telemetry, librarian decisions, and an Acquisitions workspace section. The fifth slice, confirmation-gated member Agentforce transactions, is deployed with short-lived hashed tokens, explicit preview/confirm APIs, replay protection, actor binding, and invocable action support for renewals and reservation cancellations. The sixth slice, a private member engagement hub, is deployed with reading-list save/remove actions, progress states, private notes, ratings, availability-notification intent, a Reading Lists member workspace view, followed-author save/unfollow controls with a dedicated Authors I Follow view, and pending-moderation book review submission from book details. Its live runtime ledger is designed to migrate into the planned engagement/review objects once the org metadata index exposes the new fields. The seventh slice, an events foundation, is deployed with librarian event creation, session-scoped upcoming-event discovery, capacity-safe registration, duplicate-registration prevention, waitlisting when full, cancellation with earliest-waitlist promotion, hashed expiring member check-in codes, librarian attendance validation, and an Events member workspace view. The eighth slice, room booking, is deployed with librarian room creation, capacity-filtered availability search, overlap-safe eight-hour bookings, member cancellation, and a Rooms member workspace view. The ninth slice, reading challenges, is deployed with librarian-published goals, idempotent member enrollment, borrowing-history progress calculation, automatic completion state, and a Challenges member workspace view. The tenth slice, multi-branch inventory, is deployed with branch creation, copy-to-branch assignments, idempotent transfer requests, requested/in-transit/received transfer lifecycle, and a Branches member workspace view. The eleventh slice, fine appeals, is deployed with member-owned appeal submission, duplicate prevention, librarian approval/rejection decisions with reasons, and a Fine Appeals member workspace view. The twelfth slice, membership holds and grace periods, is deployed with member-owned 1–90 day requests, overlap and idempotency safeguards, librarian decisions, one-time membership-date extension under lock, policy-version/original-date preservation, and a Membership Holds member workspace plus librarian review panel. The thirteenth slice, no-show processing, is deployed with a safe rerunnable librarian action that expires stale ready reservations through the existing promotion workflow, marks completed room bookings and past event registrations as `No-show`, and records an audit count for each run. The fourteenth slice, holiday-aware due dates, is deployed with idempotent global/branch closure ranges, timezone and emergency metadata, a librarian calendar panel, and centralized due-date calculation for checkout and renewal. The fifteenth slice, member privacy controls, is deployed with password re-authenticated allowlisted exports, expiring protected files, correction workflows, retention-safe account anonymization, session revocation, idempotent request history, and member/librarian Privacy Center panels. The sixteenth slice, immutable-style administrative audit trail, is deployed with centralized safe digest recording, privileged-operation filtering, privacy/closure/no-show/membership-hold integrations, idempotent correlation keys, and a librarian audit viewer. The seventeenth slice, explainable fraud and anomaly alerts, is deployed with bounded 90-day scans for frequent fine waivers and repeated copy-damage patterns, idempotent advisory alerts, evidence and severity scoring, librarian resolution/false-positive disposition, audit integration, and a Risk Alerts dashboard panel. The eighteenth slice, Salesforce-style executive summaries, is deployed with idempotent daily aggregate snapshots, a schedulable Apex entry point, reporting-date and timezone-safe metrics, privacy-preserving history, and a librarian executive summary dashboard panel. The nineteenth slice, payment receipts and reconciliation controls, is deployed with idempotent protected receipts for paid membership transactions, explicit pending/exception settlement decisions, finance permission enforcement, and audit-backed reconciliation history. The twentieth slice, bulk catalog import, is deployed with bounded CSV preview, row-level validation, duplicate/existing ISBN detection, all-or-nothing commit behavior, stable import idempotency keys, audit logging, and a librarian import panel. The twenty-first slice, mobile inventory stocktake, is deployed with explicit audit start/close states, idempotent barcode scan lines, expected-versus-observed discrepancy capture, safe review notes, and a librarian stocktake panel that never silently mutates copy records. The twenty-second slice, missing-book condition and repair lifecycle, is deployed with barcode-based case opening, Borrowed-state protection, Maintenance quarantine, controlled Repaired/Unrepairable outcomes, condition/status transitions, idempotent repair cases, and audit-backed librarian review. Event, room, challenge, branch, appeal, hold, no-show, closure, privacy, audit, risk, summary, payment, import, stocktake, repair, and registration records currently use the migration-safe scan ledger until the planned objects are queryable in the target org. Remaining roadmap slices are still pending.

The twenty-third slice, ISBN metadata lookup and catalog-quality workflow, is now implemented and deployed with ISBN-10/ISBN-13 normalization and checksum validation, Named Credential-backed provider lookup, preview quality warnings, duplicate ISBN detection, explicit field selection, curated-field protection, provider-failure safety, and audit-backed application. The twenty-fourth slice, production payment lifecycle hardening, is implemented and deployed with hosted-checkout initiation states, HMAC-signed REST webhooks, amount/currency validation, event idempotency, dispute/cancellation/refund states, permissioned refund intents, protected gateway configuration, and automated webhook/refund tests. The twenty-fifth slice, advanced reading challenges, is implemented and deployed with idempotent completion badges, certificate files, verified borrowing streaks, opt-in anonymous leaderboards, and member challenge controls. The twenty-sixth slice, accessibility and localization preferences, is implemented and deployed with persisted language/timezone choices, high-contrast, larger-text, reduced-motion, and screen-reader settings, keyboard-friendly profile controls, immediate visual preference application, and session-scoped validation. The twenty-seventh slice, digital member cards, is implemented and deployed with ten-minute opaque card tokens, hashed-at-rest storage, one-time kiosk validation, replay/expiry protection, display-safe member details, and a Digital Card profile tab.

## 2. Existing foundation to preserve

The project already provides a strong base:

- Experience Cloud member registration, verification, sign-in, session handling, and scoped member access.
- Catalog management for books, physical copies, authors, and categories.
- Checkout, return, renewal, reservation queues, hold expiry, fines, and damaged-copy replacement.
- Membership plans, demonstration payment records, member notifications, and reservation audits.
- Librarian workspace, member portal, operational dashboards, reports, settings, and CSV catalog import.
- Member recommendations and real-time operational analytics, with a Data Cloud implementation blueprint.
- Read-only member and librarian Agentforce actions.
- Custom-permission checks, private transactional data, sharing controls, negative authorization tests, and deployment automation.

All new functionality must follow these boundaries:

1. A member's identity is resolved from the validated `Member_Session__c`; a browser-supplied member ID is never trusted.
2. Internal librarian mutations require the appropriate custom permission and record access.
3. All circulation mutations pass through `LibraryPolicyService` and the relevant domain service.
4. Apex controllers remain thin; business logic belongs in bulk-safe services.
5. Callouts use Named Credentials and External Credentials. Secrets never appear in source, Custom Metadata, LWC code, or debug logs.
6. Real-time operational screens read Salesforce source records. Data Cloud is used for historical, segmentation, recommendation, and predictive workloads where refresh delay is acceptable.
7. Every externally initiated mutation is idempotent and auditable.
8. New member-facing data is private by default and exposed only through session-scoped service methods.

## 3. Outcomes and success measures

| Outcome                       | Suggested measure                                                                                    |
| ----------------------------- | ---------------------------------------------------------------------------------------------------- |
| Faster circulation            | Median scan-to-checkout time under 10 seconds                                                        |
| Better reservation experience | ETA displayed for at least 95% of active queued reservations                                         |
| Better collection decisions   | Purchase recommendations include evidence and are reviewed monthly                                   |
| Higher engagement             | Growth in wishlist-to-reservation conversion and challenge participation                             |
| Reliable communication        | Delivery status recorded for every outbound notification attempt                                     |
| Safer automation              | 100% of assistant write actions have confirmation, policy evaluation, idempotency, and audit records |
| Accessible experience         | WCAG 2.2 AA review completed for all new member and librarian workflows                              |
| Payment integrity             | Webhook-confirmed state is the system of record; no browser-only payment success                     |
| Operational traceability      | All privileged overrides and sensitive operations appear in an immutable-style audit view            |

Do not set numerical business targets until representative baseline data has been collected.

## 4. Target architecture

```text
Experience Cloud member portal       Lightning librarian workspace
              |                                  |
       Session-scoped Apex               Permission-scoped Apex
              |                                  |
              +----------- Domain services ------+
                              |
       Policy | Circulation | Reservation | Payment | Engagement
                              |
        Salesforce transactional custom objects
                 |                         |
       Platform Events / Queueables    Scheduled jobs
                 |                         |
       External providers            Data Cloud / Reports
       (payments, messaging,
        ISBN metadata)
```

### 4.1 Service conventions

New services should use the existing naming style:

- `LibraryScanService`
- `LibraryReservationEtaService`
- `LibraryAcquisitionInsightService`
- `LibraryRecommendationService`
- `LibraryEngagementService`
- `LibraryEventService`
- `LibraryRoomBookingService`
- `LibraryBranchService`
- `LibraryPaymentGatewayService`
- `LibraryNotificationOrchestrator`
- `LibraryInventoryAuditService`
- `LibraryPrivacyService`
- `LibraryOperationAuditService`
- `LibraryRiskInsightService`

Expose separate session-scoped facades for members and permission-scoped facades for librarians. Avoid turning `LibraryLibrarianController` or `LibraryMemberSessionController` into additional monoliths.

### 4.2 Proposed permission model

Add narrowly scoped custom permissions rather than one general administrator permission:

- `Manage_Library_Acquisitions`
- `Manage_Library_Events`
- `Manage_Library_Rooms`
- `Manage_Library_Branches`
- `Manage_Library_Inventory_Audits`
- `Manage_Library_Payments`
- `Manage_Library_Communication`
- `Manage_Library_Privacy_Requests`
- `Manage_Library_Audit`
- `Manage_Library_Risk_Alerts`
- `Override_Library_Policy`

`Override_Library_Policy` must never silently bypass a rule. Require a reason, capture before/after values, record the actor and timestamp, and notify or queue review when appropriate.

## 5. Proposed data-model extensions

The final field set must be confirmed against actual org limits and reporting needs before deployment.

| Object                          | Purpose                                                          | Important fields/relationships                                                                              |
| ------------------------------- | ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `Library_Branch__c`             | Physical or virtual branch                                       | Code, name, address, timezone, active flag, calendar                                                        |
| `Branch_Transfer__c`            | Copy movement between branches                                   | Copy, source, destination, requested/shipped/received dates, status                                         |
| `Search_Analytics__c`           | Privacy-minimized catalog search telemetry                       | Normalized query, filters, result count, timestamp, optional member segment—not raw identity by default     |
| `Member_Book_Engagement__c`     | Wishlist, reading list, reading state, rating, and private notes | Member, book, list type, reading status, rating, visibility, unique member/book/list key                    |
| `Book_Review__c`                | Moderated member review                                          | Member, book, rating, review text, moderation status, published date                                        |
| `Author_Follow__c`              | Followed author preference                                       | Member, author, active flag, unique member/author key                                                       |
| `Recommendation_Event__c`       | Recommendation measurement                                       | Member, book, strategy, reason code, impression/click/reservation/borrow event, occurred at                 |
| `Acquisition_Recommendation__c` | Evidence-based purchase/retirement suggestion                    | Book or query, action, score, recommended quantity, evidence snapshot, status, decision reason              |
| `Library_Event__c`              | Workshop, book club, or program                                  | Branch, capacity, start/end, audience, status, waitlist rules                                               |
| `Event_Registration__c`         | Event registration and attendance                                | Event, member, queue position, status, check-in token/hash, attended at                                     |
| `Library_Room__c`               | Reservable room/resource                                         | Branch, capacity, equipment, accessibility attributes, active flag                                          |
| `Room_Booking__c`               | Room reservation                                                 | Room, member, start/end, status, purpose, check-in/expiry timestamps                                        |
| `Reading_Challenge__c`          | Time-bound reading goal                                          | Goal type/value, dates, eligibility, badge/certificate configuration                                        |
| `Challenge_Enrollment__c`       | Member progress                                                  | Challenge, member, progress, completed date, privacy/leaderboard opt-in                                     |
| `Achievement__c`                | Reusable badge definition                                        | Name, rule type, threshold, image/content reference, active flag                                            |
| `Member_Achievement__c`         | Earned achievement                                               | Member, achievement, earned date, evidence key, unique award key                                            |
| `Notification_Preference__c`    | Member communication choices                                     | Member, channel, notification type, enabled, quiet hours, timezone, digest frequency                        |
| `Notification_Delivery__c`      | Per-channel delivery attempt                                     | Notification, channel, provider ID, attempt, status, sent/delivered/failed timestamps, sanitized error code |
| `Payment_Transaction__c`        | Gateway-neutral payment ledger                                   | Member, purpose, related fine/plan payment, amount/currency, gateway IDs, status, idempotency key           |
| `Payment_Webhook_Event__c`      | Deduplicated webhook processing record                           | Provider event ID, signature result, received/processed dates, outcome, retry count                         |
| `Inventory_Audit__c`            | Stocktake session                                                | Branch, scope, started/completed by and at, status, totals                                                  |
| `Inventory_Audit_Line__c`       | Per-copy stocktake result                                        | Audit, copy, expected/found location, scanned at, discrepancy type                                          |
| `Book_Condition_Event__c`       | Copy condition and repair history                                | Copy, condition, event type, notes, photo/file reference, cost, occurred at                                 |
| `Fine_Appeal__c`                | Member fine dispute                                              | Fine, member, reason, evidence, status, reviewer, decision reason/dates                                     |
| `Membership_Hold__c`            | Membership freeze                                                | Member, start/end, reason, status, approved by, entitlement adjustment                                      |
| `Library_Closure__c`            | Holiday/emergency calendar                                       | Branch, start/end, type, due-date handling rule                                                             |
| `Privacy_Request__c`            | Access/export/correction/deletion workflow                       | Member, request type, verification state, due date, status, decision/legal-hold reason                      |
| `Library_Operation_Audit__c`    | Privileged action ledger                                         | Actor, operation, target type/ID, correlation ID, reason, before/after digest, timestamp                    |
| `Library_Risk_Alert__c`         | Reviewable anomaly signal                                        | Alert type, target, score, evidence, status, disposition, reviewer                                          |
| `Integration_Event__c`          | Generic idempotency and integration observability                | Provider, external ID, operation, status, correlation ID, retry metadata                                    |

### 5.1 Extensions to existing objects

- `Book_Copy__c`: branch, home branch, current location, last scanned at, inventory status, repair status, replacement priority.
- `Book__c`: metadata provider ID, metadata quality status, audience/language/edition attributes, acquisition state.
- `Reservation__c`: pickup branch, estimated available date, ETA confidence, last ETA calculation, notification preference snapshot, no-show count/outcome.
- `Borrow_Record__c`: checkout channel, checkout/return branch, scan correlation ID, receipt status.
- `Member__c`: preferred language, timezone, accessibility preferences, default pickup branch, communication consent version.
- `Membership_Plan__c`: freeze allowance, grace-period rules, branch restrictions, room/event entitlements if required.
- `Member_Notification__c`: category, priority, action URL key, preference decision, correlation ID. Store only allowlisted internal navigation keys, not arbitrary URLs.
- `Fine__c`: appeal state, collection state, gateway-settled amount.
- `Library_Settings__c` or Custom Metadata: ETA parameters, no-show policy, recommendation controls, integration feature flags, retention periods, and channel defaults.

## 6. Feature implementation specifications

### 6.1 Mobile barcode/QR scanning, self-checkout, return, and kiosk mode

**Member and librarian experience**

- Scan a digital member card and `Book_Copy__c.Barcode__c` from a Salesforce mobile experience or supported camera.
- Support rapid librarian checkout, member self-checkout, return, stocktake, and copy lookup modes.
- Display a final transaction summary before commit and a digital receipt afterward.
- Provide visible, audible, and screen-reader success/error feedback.
- Permit an optional condition report/photo during return without exposing Salesforce file URLs publicly.
- Offer a locked-down kiosk interface with automatic session timeout and no access to unrelated member data.

**Implementation**

- Build `libraryScanner`, `librarySelfCheckout`, `libraryKiosk`, and `libraryDigitalMemberCard` LWCs.
- Use the Salesforce mobile barcode-scanning capability where supported. Provide manual code entry as the accessible and desktop fallback.
- Encode an opaque, short-lived member-card token rather than a raw `Member__c.Id` or session token.
- `LibraryScanService` validates token, barcode uniqueness, membership, fines, plan limits, reservation priority, copy state, and duplicate scans.
- Reuse the existing checkout/return domain logic; scanning must not create a second circulation implementation.
- Create a correlation/idempotency key for every scan transaction and write a privileged audit event.
- Produce an in-app receipt and optionally deliver it through the notification orchestrator.

**Acceptance criteria**

- Re-scanning the same operation cannot create a duplicate loan or return.
- A member cannot check out another member's ready hold.
- Invalid, expired, copied, or already-used member-card tokens are rejected generically.
- Manual entry provides feature parity without requiring a camera.
- Loss of connectivity never displays a successful checkout unless the server committed it.

### 6.2 Smart reservation ETA and queue transparency

**Experience**

- Show queue position, estimated availability window, confidence, pickup branch, hold deadline, and last calculation time.
- Notify members when the estimate materially changes.
- Explain the estimate in plain language without exposing other members' identities or borrowing details.

**Implementation**

- `LibraryReservationEtaService` calculates estimates using queue position, active-copy count, due dates, historical return delay, transfer time, closure dates, and expected pickup expiry.
- Store the current estimate on `Reservation__c`; retain aggregate historical accuracy for tuning without retaining unnecessary personal data.
- Recalculate after checkout, return, renewal, reservation create/cancel/expire, copy loss/damage, transfer, and relevant calendar changes.
- Use Queueable processing for large recalculation sets and deduplicated notifications for meaningful changes.
- Start with a deterministic rules model. Introduce Data Cloud prediction only after enough clean history exists and compare it with the rules baseline.

**Acceptance criteria**

- Queue order remains authoritative and consistent with the existing reservation workflow.
- ETA is absent or labelled low-confidence when required inputs are missing.
- No member response contains another member's name, due date, or activity.
- Tests cover multiple copies, overdue copies, renewals, closures, transfers, cancellations, and expired holds.

### 6.3 Acquisition intelligence and collection-development dashboard

**Experience**

- Show books with high demand, long waits, repeated unavailable searches, high utilization, aging/damaged copies, and low circulation.
- Recommend purchase quantity, replacement, transfer, promotion, or review for retirement.
- Display the evidence and confidence behind each suggestion.
- Let an authorized librarian accept, reject, defer, assign, and annotate recommendations.

**Implementation**

- Capture privacy-minimized zero-result and unavailable-result searches in `Search_Analytics__c`.
- Compute signals such as reservations per available copy, median wait, checkout days per copy, turnaways, condition cost, age, and branch imbalance.
- Use `LibraryAcquisitionInsightService` for current operational evidence and Data Cloud calculated insights for historical trends.
- Persist decision snapshots in `Acquisition_Recommendation__c`; never overwrite the evidence used for an earlier decision.
- Add an Acquisitions section to the librarian workspace with filters, score explanations, trend charts, and CSV/PDF export.
- Treat recommendations as decision support; do not automatically order or retire material.

**Acceptance criteria**

- Every recommendation identifies its evidence window and refresh time.
- Librarians can distinguish live Salesforce metrics from delayed Data Cloud insights.
- Sparse data results in an “insufficient evidence” state, not a fabricated score.
- Search telemetry excludes credentials, session identifiers, and raw sensitive queries according to retention policy.

### 6.4 Confirmation-based Agentforce transactions

Add narrowly bounded member actions for eligible renewals, reservations, reservation cancellations, and notification-preference changes. Optionally add librarian actions for creating a prepared hold or initiating a transfer only after separate authorization review.

**Required action protocol**

1. Resolve identity from the current member session or Salesforce internal user.
2. Retrieve live target data and run policy evaluation.
3. Return a human-readable preview of the exact action and consequences.
4. Create a short-lived, single-use confirmation token bound to actor, action, target, and parameters.
5. Require explicit confirmation.
6. Re-run policy and record-state checks at execution time.
7. Execute through the existing domain service with an idempotency key.
8. Record the outcome and correlation ID in the operation audit.
9. Return the committed record state, not generated prose presented as fact.

**Implementation**

- Create separate invocable action classes rather than adding write methods to the existing read-only actions.
- Add `LibraryAgentConfirmationService` and store only hashes of confirmation tokens.
- Maintain separate read and write permission sets and agent topics.
- Do not allow free-form SOQL, arbitrary record IDs, policy overrides, fine waivers, payment execution, or member identity changes.
- Add prompt-injection, cross-member access, replay, stale confirmation, concurrent update, and duplicate execution tests.

**Acceptance criteria**

- No mutation occurs before explicit confirmation.
- A token cannot be replayed, transferred to a different member, or used for altered parameters.
- The same rules apply whether the action starts in the UI, an assistant, or a scanner.
- Agent unavailability does not affect conventional portal operations.

### 6.5 Personalized engagement hub

**Capabilities**

- Wishlists and named reading lists.
- Want-to-read, currently-reading, completed, and abandoned states.
- Private notes, ratings, and moderated public reviews.
- Followed authors and new-arrival alerts.
- “Notify me when available” without creating a formal reservation.
- Recommendation feedback such as “not interested” and “show me less like this.”
- Explainable recommendations: “because you borrowed…,” followed-author releases, interest matches, and similar categories.

**Implementation**

- Build an Engagement area in `libraryMemberShell` backed only by session-scoped methods.
- Use `Member_Book_Engagement__c`, `Book_Review__c`, `Author_Follow__c`, and `Recommendation_Event__c`.
- Give reviews a moderation queue, profanity/abuse controls, report action, status history, and librarian permission.
- Keep private notes and non-public lists inaccessible to other members and public catalog users.
- Extend `LibraryRecommendationService` to return reason codes and diversity constraints.
- Measure impressions, clicks, saves, reservations, and completed borrowing; respect analytics consent and retention.

**Acceptance criteria**

- Recommendation cards state why they were selected.
- Members can disable personalized recommendations and remove their engagement history subject to retention rules.
- Hidden/rejected reviews never appear publicly.
- Duplicate follows, ratings, and list entries are prevented with unique keys.

### 6.6 Events, workshops, book clubs, attendance, and room booking

**Capabilities**

- Browse and register for events, join a capacity-controlled waitlist, cancel, and receive reminders.
- Automatically promote the next waitlisted member after cancellation.
- QR check-in and attendance reporting.
- Search rooms by branch, time, capacity, equipment, and accessibility features.
- Book, cancel, check in, expire no-shows, and enforce fair-use limits.

**Implementation**

- Add member and librarian LWCs for event discovery, event administration, room availability, and calendar views.
- `LibraryEventService` and `LibraryRoomBookingService` lock the relevant event/room rows before capacity decisions.
- Detect overlapping room bookings server-side; UI checks are advisory only.
- Apply branch timezone and closure calendars.
- Use short-lived hashed check-in tokens and idempotent check-in actions.
- Send confirmation, reminder, promotion, cancellation, and no-show communications through the common notification orchestrator.

**Acceptance criteria**

- Concurrent registrations cannot exceed event or room capacity.
- Waitlist promotion is deterministic and audited.
- Room bookings cannot overlap, cross closure windows, or exceed plan/policy limits.
- Event health/accessibility data is collected only when necessary, protected appropriately, and retained for a defined period.

### 6.7 Multi-branch inventory, pickup, return-anywhere, and transfers

**Capabilities**

- Branch-specific catalog availability and member default pickup branch.
- Place a reservation at a chosen pickup branch.
- Transfer copies between branches with requested, approved, in-transit, received, cancelled, and exception states.
- Return at any allowed branch and route the copy to a local queue or its home branch.
- Compare demand and inventory imbalance by branch.

**Implementation**

- Add `Library_Branch__c`, `Branch_Transfer__c`, and branch fields to copies, transactions, rooms, events, and closures.
- Extend reservation allocation to prefer pickup-branch copies and then eligible transfers.
- Use a transfer state machine; only an authorized receiving scan can mark a copy received.
- Prevent checkout for copies in transit, missing, under repair, or reserved elsewhere.
- Update sharing only if branch staff require regional restriction. Preserve central librarian access where authorized.

**Acceptance criteria**

- A copy has exactly one operational location/state at a time.
- Transfers are idempotent and retain a complete status history.
- Return-anywhere behavior does not violate a ready reservation at the return branch.
- All displayed availability identifies its branch and refresh time.

### 6.8 Production payment gateway, receipts, refunds, and reconciliation

The existing demonstration payment flow must remain clearly labelled until all controls below are complete.

**Implementation**

- Use provider-hosted checkout or tokenization so raw card data never enters Salesforce.
- Configure Named/External Credentials and provider-specific adapters behind `LibraryPaymentGatewayService`.
- Create a `Payment_Transaction__c` in `Initiated` state with a unique idempotency key before redirecting.
- Treat signed webhook confirmation—not the browser redirect—as payment truth.
- Validate signatures, timestamps, amount, currency, merchant account, related record, and provider event uniqueness.
- Store each webhook in `Payment_Webhook_Event__c`; acknowledge duplicates without applying them twice.
- Support initiated, pending, succeeded, failed, cancelled, partially refunded, refunded, disputed, and reconciliation-exception states.
- Allocate settled amounts to membership or fine records in a single transaction and issue a receipt.
- Add daily reconciliation against provider settlement reports and a librarian exception queue.
- Require elevated permission and reason for refunds; never refund more than the settled refundable balance.

**Acceptance criteria**

- Editing a return URL or client response cannot mark a payment paid.
- Duplicate and out-of-order webhooks produce the same final ledger state.
- Financial amounts reconcile across payment transaction, fine or membership record, and provider settlement.
- Logs and records contain no card number, CVV, secret, access token, or complete sensitive provider payload.
- Failure and recovery scenarios have automated tests using callout mocks.

### 6.9 Reading challenges, goals, badges, certificates, and optional leaderboards

**Capabilities**

- Monthly/yearly book, page, category, or diversity goals.
- Personal progress, streaks, earned badges, and downloadable certificates.
- Staff-created challenges and automatic progress from completed loans.
- Optional leaderboards using display aliases and explicit opt-in.

**Implementation**

- Add `Reading_Challenge__c`, `Challenge_Enrollment__c`, `Achievement__c`, and `Member_Achievement__c`.
- `LibraryChallengeService` processes qualifying returned loans idempotently using an evidence key.
- Allow self-reported books only if the challenge permits them; distinguish them from verified circulation activity.
- Generate accessible certificate files asynchronously and retain them according to policy.
- Make competition optional; the default view is personal progress.

**Acceptance criteria**

- Reprocessing a return never awards duplicate progress or badges.
- Returned/reversed transactions adjust progress according to a documented rule.
- Members can leave public leaderboards without losing private progress.
- Minor-focused deployments require an additional privacy review before enabling leaderboards.

### 6.10 Accessibility, localization, and inclusive UX

**Implementation standard**

- Target WCAG 2.2 AA for new and changed interfaces.
- Provide keyboard-only operation, visible focus, logical focus after dialogs, skip links, semantic headings, labelled controls, and screen-reader live regions.
- Never communicate status using color alone.
- Respect reduced-motion, zoom/reflow, high-contrast, and large-text preferences.
- Provide text/manual alternatives for camera scans and visual charts.
- Store member preferred language and timezone.
- Move UI strings, emails, notifications, receipts, and certificates into Custom Labels/translatable templates.
- Use locale-aware dates, numbers, currency, and pluralization. Store timestamps in UTC and display them in the relevant timezone.
- Include accessibility attributes for rooms and event venues.

**Acceptance criteria**

- Automated accessibility checks are paired with manual keyboard and screen-reader UAT.
- All member-critical flows work at 200% zoom and without a mouse.
- Language switching does not expose untranslated security or payment instructions.
- Focus is restored correctly after modal close, validation failure, and route change.

### 6.11 Omnichannel notification preference center

**Capabilities**

- In-app, email, SMS, WhatsApp, and push channels where configured.
- Due-soon, overdue, reservation-ready, hold-expiry, membership-expiry, payment receipt, event, room, followed-author, and new-arrival categories.
- Quiet hours, timezone, instant/daily/weekly digest options, and channel-specific opt-in.
- Delivery tracking, retry, bounce/failure handling, and librarian exception view.

**Implementation**

- Retain `Member_Notification__c` as the canonical message and add per-channel `Notification_Delivery__c` attempts.
- `LibraryNotificationOrchestrator` evaluates consent, preference, quiet hours, mandatory-service rules, deduplication, and templates.
- Use Queueables or Platform Events for delivery. Configure providers with Named Credentials.
- Use exponential backoff with an upper retry limit and dead-letter/exception state.
- Store provider message IDs and sanitized status codes, not full payloads.
- Version consent and message templates so historical decisions remain explainable.

**Acceptance criteria**

- A disabled optional channel is never used.
- Legally/operationally mandatory messages are clearly separated from marketing preferences.
- Duplicate scheduler runs do not create duplicate messages.
- Quiet hours use the member's timezone and define daylight-saving behavior.

### 6.12 ISBN metadata lookup and catalog-quality workflow

**Capabilities**

- Lookup title, subtitle, edition, authors, publisher, publication date, language, categories, description, and cover by ISBN.
- Preview provider data next to current values and select fields to apply.
- Detect probable duplicate editions and incomplete records.

**Implementation**

- Add a provider-neutral `LibraryMetadataProvider` interface and Named Credential-backed implementation.
- Normalize ISBN-10/ISBN-13 and validate checksum before callout.
- Cache responses within provider terms and store source, fetched date, and field-level provenance where necessary.
- Queue cover ingestion; verify MIME type, size, licensing/usage terms, and safe storage before display.
- Never overwrite librarian-curated data without a preview and explicit selection.

**Acceptance criteria**

- Invalid ISBNs are rejected before callout.
- Provider downtime leaves existing catalog records unchanged.
- Duplicate detection distinguishes editions and formats rather than merging solely by similar title.
- Tests cover malformed, partial, conflicting, and rate-limited responses.

### 6.13 Bulk catalog import with preview and row-level errors

Enhance the existing import to use a staged process:

1. Upload and virus-scan the supported file type.
2. Parse into a temporary batch with row numbers.
3. Validate required fields, ISBN/barcode uniqueness, references, picklists, and date formats.
4. Display proposed creates, updates, skips, warnings, and errors.
5. Require explicit commit.
6. Process in bounded asynchronous chunks.
7. Produce a downloadable result file containing the original row number and outcome.

Use `ContentVersion` for uploads and purpose-built import batch/row objects or a controlled staging mechanism. Do not execute one imperative Apex call per browser row. The commit must be restartable and idempotent.

### 6.14 Mobile inventory stocktake and discrepancy handling

**Capabilities**

- Start a branch, shelf, category, or selected-copy audit.
- Rapidly scan barcodes and show expected location/status.
- Flag missing, unexpected, duplicate, misplaced, and status-mismatch copies.
- Pause/resume, reconcile, and close the audit with a signed summary.

**Implementation**

- Use `Inventory_Audit__c` and `Inventory_Audit_Line__c` with `LibraryInventoryAuditService`.
- Create expected lines asynchronously from a frozen scope snapshot.
- A scan updates only the active audit line; it does not silently alter copy status or location.
- Require explicit reconciliation actions for copy corrections, each with reason and audit trail.

### 6.15 Missing-book investigation, condition, repair, and replacement lifecycle

**State model**

`Available/Borrowed/Reserved -> Reported Missing or Damaged -> Under Investigation -> Under Repair/Replacement Approved -> Available/Replaced/Withdrawn`

**Implementation**

- Record all changes in `Book_Condition_Event__c`, including inspection notes, attachments, vendor/repair cost, and actor.
- Extend the current damage replacement panel into a full lifecycle view.
- Create tasks/alerts for aging investigations and repairs.
- Exclude unavailable states from checkout and ETA supply.
- Connect replacement priority to acquisition intelligence.
- Define when a member may be charged; a good-faith defect report must not automatically generate a fine.

### 6.16 Fine appeals and librarian decisions

- Members can appeal only their own eligible fine and upload controlled evidence.
- An appeal may pause collection reminders according to policy without marking the fine paid or waived.
- Librarians can approve, partially approve, reject, or request information with a decision reason.
- Approval uses the existing fine waiver/payment rules and records the financial adjustment separately.
- Prevent the same fine from having multiple open appeals.
- Separate the appeal submitter, reviewer, and privileged waiver actor where segregation of duties is required.

### 6.17 Membership freeze and grace-period policies

- Define plan-level freeze allowance, maximum duration, eligible reasons, approval rules, and annual count.
- `LibraryMembershipHoldService` checks overlapping holds and calculates any membership-end-date extension once.
- Preserve the original and adjusted membership dates and the policy version used.
- Define borrowing, renewal, reservation, event, and room rights during a hold.
- Add grace-period behavior for recently expired memberships without conflating membership status and account status.

### 6.18 Holiday-aware due dates and branch calendars

- Store closures by branch and timezone in `Library_Closure__c`.
- Centralize due-date calculation in `LibraryCalendarService`; replace direct `Date.today().addDays(...)` calculations in circulation services.
- Define whether closures extend due dates to the next open day and how emergency closures affect existing loans and ready holds.
- Batch-recalculate affected records when an emergency closure is added, recording the old/new dates and sending deduplicated notices.
- Test weekends, leap years, midnight boundaries, daylight-saving transitions, and multi-branch transactions.

### 6.19 Reservation and booking no-show processing

- A scheduler identifies expired ready holds, room bookings, and event registrations.
- Re-query and lock each record before transition to avoid racing a pickup/check-in.
- Promote the next queue member using the existing deterministic ordering.
- Track no-show counts for reporting; apply penalties only through explicit, configurable, appealable policy.
- Send expiry and promotion notices through the notification orchestrator.
- Make the batch idempotent and safe to rerun.

### 6.20 Member data export, correction, and deletion requests

**Implementation**

- Add a portal privacy center backed by `Privacy_Request__c`.
- Re-authenticate or otherwise verify identity before accepting sensitive requests.
- Generate exports asynchronously from an allowlist of member-owned profile, loan, reservation, fine, payment, engagement, event, room, and notification data.
- Place exports in protected files with short expiry and record access/download events.
- Route corrections through domain-specific workflows rather than permitting arbitrary field edits.
- Deletion/anonymization must honor financial, audit, safety, and legal-retention obligations. Record why retained data could not be deleted.
- Revoke sessions and integration tokens as part of approved account closure.

**Acceptance criteria**

- Member A cannot request or download Member B's data.
- Authentication secrets, hashes, session tokens, internal risk signals, and unrelated staff notes are excluded.
- Export and deletion tasks are resumable, monitored, and fully audited.

### 6.21 Immutable-style administrative audit trail

- Use `Library_Operation_Audit__c` for privileged changes not already covered by reservation audit/history.
- Capture actor, permission context, operation, target, correlation ID, reason, result, and safe before/after digests.
- Prevent updates/deletes through normal permission sets; grant read access only to appropriate auditors/admins.
- Never store passwords, tokens, payment secrets, full sensitive payloads, or unnecessary personal data.
- Define retention and archive/export procedures.
- Provide filters for policy overrides, payment/refund operations, member status changes, privacy requests, transfers, and bulk imports.

### 6.22 Fraud and anomaly alerts

Start with explainable rules, not opaque automated punishment:

- Repeated lost/damaged-copy patterns.
- Unusually frequent fine waivers or refunds by an operator.
- Excessive manual policy overrides.
- Repeated payment failures or webhook mismatches.
- Rapid account/session anomalies already observable within approved security telemetry.
- Inventory discrepancy clusters by shelf, branch, or time.

`LibraryRiskInsightService` creates a reviewable `Library_Risk_Alert__c` with evidence and score. Alerts must never automatically suspend a member, accuse a person, deny service, or trigger a financial action. Restrict access, define retention, support false-positive disposition, and audit reviewer actions.

### 6.23 Salesforce reports and scheduled executive summaries

Create report types, dashboards, and scheduled summaries for:

- Circulation, renewals, overdue rates, and turnaround time.
- Reservation demand, ETA accuracy, wait time, expiry, and no-shows.
- Inventory utilization, condition cost, losses, transfers, and stocktake discrepancies.
- Membership acquisition, approval funnel, retention, expiry, and plan movement.
- Payments, refunds, reconciliation exceptions, fines, appeals, and waivers.
- Recommendation engagement and wishlist-to-borrow conversion.
- Events, room utilization, attendance, and waitlists.
- Notification delivery, failure, preference, and digest performance.
- Acquisition recommendations and decision outcomes.
- Accessibility feedback and support incidents without storing sensitive medical detail.

Scheduled executive summaries should link authorized recipients to Salesforce reports instead of emailing sensitive record-level datasets. Use aggregate counts, clearly state the reporting window/timezone, and flag stale or incomplete data.

## 7. Data Cloud evolution

Extend the existing Data Cloud plan only after source-object governance is complete.

### 7.1 Candidate new streams

- Privacy-approved engagement events and recommendation outcomes.
- Search aggregates, preferably already minimized/aggregated at source.
- Event registrations and room utilization.
- Branch inventory and transfers.
- Acquisition decisions.
- Notification engagement/delivery aggregates.

Do not ingest authentication fields, session data, confirmation tokens, payment secrets, raw gateway payloads, private member notes, sensitive appeal evidence, or unrestricted risk-investigation details.

### 7.2 Calculated insights

- Demand per available copy and branch.
- Median reservation wait and ETA error.
- Copy utilization and idle time.
- Member category affinity with minimum evidence thresholds.
- Recommendation conversion by strategy.
- Collection gaps from zero-result searches.
- Event/room utilization and no-show trends.
- Membership retention and engagement cohorts.

Use Data Cloud insights for recommendations and planning, not as the only source of live copy availability, current queue position, payment status, or permission decisions.

## 8. Shared automation and integration requirements

### 8.1 Idempotency

Require stable idempotency keys for scans, assistant actions, payment initiation/webhooks, check-ins, challenge awards, notifications, imports, privacy jobs, and scheduled transitions. Add unique fields where Salesforce supports them and handle duplicate-key outcomes as an already-processed result.

### 8.2 Concurrency

Use row locking and short transactions for copy checkout/return, queue promotion, capacity allocation, room booking, transfer receipt, payment allocation, and stocktake reconciliation. Re-check state after locks are acquired.

### 8.3 Integration resilience

- Timeouts and bounded retries with backoff.
- Circuit-breaking/feature flags for nonessential providers.
- Provider correlation IDs and sanitized failure codes.
- Dead-letter or exception queues for manual recovery.
- Callout mocks for every success, failure, timeout, duplicate, and malformed response path.
- No retry of a mutation unless idempotency is guaranteed.

### 8.4 Configuration

Use Custom Metadata for deployable policy defaults and provider mappings; use protected credential facilities for secrets; use custom settings/objects for administrator-editable runtime settings where appropriate. Every setting needs validation, permission enforcement, a default, and an audit strategy.

## 9. User-interface changes

### 9.1 Member portal navigation

Proposed sections:

- Home
- Discover
- My Loans
- Reservations
- Lists & Reviews
- Challenges
- Events
- Rooms
- Payments & Fines
- Notifications
- Profile & Preferences
- Privacy Center

Keep the navigation responsive and permission/feature-flag aware. Do not load every section's data on initial page load.

### 9.2 Librarian workspace navigation

Add:

- Scan / Kiosk
- Acquisitions
- Events
- Rooms
- Branches & Transfers
- Inventory Audits
- Appeals
- Communication
- Payment Reconciliation
- Privacy Requests
- Risk Alerts
- Audit Trail

Split large sections into lazy-loaded child LWCs. Preserve global search but make result categories and permissions explicit.

## 10. Delivery roadmap

All features are included; phases express dependency and risk, not optional scope.

### Phase 0 — Architecture and guardrails

- Confirm target-org licenses and integration/provider choices.
- Add feature flags, new custom permissions, shared audit, idempotency, calendar, and integration patterns.
- Establish accessibility test tooling and performance baselines.
- Resolve outstanding Data Cloud stream/mapping errors before expanding ingestion.

**Exit gate:** architecture/security review, schema validation, deployment validation, and rollback plan approved.

### Phase 1 — High-value member and circulation improvements

- Smart reservation ETA.
- Notification preferences and delivery tracking.
- ISBN metadata lookup.
- Staged bulk catalog import.
- Wishlist/reading lists, author follows, availability alerts, and recommendation explanations.
- Holiday-aware due dates.

**Exit gate:** member isolation, queue integrity, localization, accessibility, notification deduplication, and bulk-load tests pass.

### Phase 2 — Physical library transformation

- Barcode/QR scanner and digital member card.
- Self-checkout, return, and kiosk mode.
- Inventory stocktake.
- Missing/damaged/repair/replacement lifecycle.
- Multi-branch catalog and transfers.

**Exit gate:** concurrency, duplicate-scan, offline/failure-state, branch-state, and stock reconciliation tests pass on supported devices.

### Phase 3 — Engagement and community services

- Ratings, moderated reviews, and reading-status tracking.
- Events, waitlists, check-in, and attendance.
- Room search, booking, and no-show processing.
- Reading challenges, badges, certificates, and opt-in leaderboards.
- Accessibility and localization completion for all added flows.

**Exit gate:** moderation, capacity, privacy, timezone, accessibility, and abuse-case UAT passes.

### Phase 4 — Intelligence and governed automation

- Acquisition intelligence dashboard.
- Expanded Data Cloud calculated insights and recommendation measurement.
- Confirmation-based Agentforce actions.
- Risk/anomaly review queue.
- Expanded operational and executive reporting.

**Exit gate:** explainability, stale-data handling, action-confirmation, replay, false-positive, and cross-member security tests pass.

### Phase 5 — Financial and privacy maturity

- Production gateway payments, refunds, webhooks, receipts, and reconciliation.
- Fine appeals.
- Membership freezes and grace policies.
- Privacy export/correction/deletion workflows.
- Full privileged operation audit experience.

**Exit gate:** payment-provider certification where applicable, finance reconciliation sign-off, privacy/legal review, restore test, penetration/security review, and production runbooks complete.

## 11. Testing strategy

### 11.1 Apex

- Positive, negative, bulk, concurrency-sensitive, sharing, CRUD/FLS, custom-permission, and rollback tests.
- Member A versus Member B isolation for every new member-scoped object and action.
- Boundary dates, timezones, closures, capacity, queue ordering, and state-machine transitions.
- Callout mocks and webhook signature/idempotency tests.
- Scheduled/batch rerun and partial-failure recovery tests.

### 11.2 LWC Jest

- Loading, empty, partial, success, validation, permission-denied, stale-data, and server-error states.
- Confirmation and cancellation paths for every mutation.
- Keyboard operation, focus behavior, accessible names, and live-region messages.
- Scanner unavailable/permission denied/manual fallback states.
- Localization-safe rendering without text-content assumptions in business logic.

### 11.3 End-to-end UAT journeys

1. Register, verify, approve, sign in, set preferences, create a wishlist, reserve, receive ETA, pick up by scan, return, and receive a receipt.
2. Create a high-demand queue, change copy availability, recalculate ETA, transfer a copy, and promote the next member.
3. Import a catalog batch, correct validation errors, enrich by ISBN, and complete a stocktake.
4. Register for a full event, join the waitlist, cancel a seat, promote and notify, then check in.
5. Book a room across timezone/closure boundaries and verify collision/no-show behavior.
6. Initiate payment, process signed/duplicate/out-of-order webhooks, issue a partial refund, and reconcile.
7. Ask the assistant to renew/reserve, review the preview, confirm, retry the token, and validate audit results.
8. Submit a fine appeal and privacy export while proving cross-member access is denied.
9. Complete a challenge and verify idempotent progress/badge awarding.
10. Complete all critical journeys with keyboard and screen reader.

### 11.4 Nonfunctional tests

- Peak search, scan, reservation, notification, import, and scheduler load.
- Salesforce governor-limit behavior with bulk record sets.
- Provider timeout and outage simulations.
- Accessibility review against WCAG 2.2 AA.
- Security review for IDOR, injection, XSS, replay, privilege escalation, sensitive logging, and file access.
- Backup/restore exercises for all new transactional and audit objects.

## 12. Observability and operations

Add dashboards/alerts for:

- Failed Queueables, batches, schedulers, and Platform Event subscribers.
- Notification failure rate and retry backlog.
- Payment webhook/reconciliation exceptions.
- Stuck transfers, imports, privacy jobs, appeals, repairs, and acquisition reviews.
- ETA calculation age and error against actual availability.
- Agent confirmation failures/replay attempts without logging token material.
- Integration latency, rate limits, and circuit state.
- Storage growth and retention jobs.

Each asynchronous workflow needs an owner, retry procedure, maximum age, escalation path, and correlation ID. Extend `docs/OPERATIONS.md` as features enter deployment; do not wait until the final phase.

## 13. Data retention and privacy classification

Before implementation, classify every proposed field as public catalog data, member-private data, staff-confidential data, financial data, security data, or analytics telemetry. Define retention and purge/anonymization schedules for:

- Search and recommendation events.
- Notification delivery attempts.
- Payment webhook payload derivatives.
- Check-in tokens and attendance.
- Review moderation history.
- Risk alerts and investigation evidence.
- Audit records.
- Privacy export files.
- Import staging data and result files.

Collect the minimum data required. Prefer categorical evidence and hashes over raw payloads. Verify that downstream Data Cloud, reports, files, sandboxes, and backups follow the same classification.

## 14. Migration and rollout

1. Deploy additive schema and permissions with all new features disabled.
2. Backfill branches, copy locations, language/timezone defaults, and required unique keys using idempotent scripts.
3. Validate counts and referential integrity before enabling code paths.
4. Pilot with test/UAT members and one branch or librarian group.
5. Enable read-only views before mutations where practical.
6. Monitor errors, limits, queue depth, and user feedback.
7. Expand using feature flags; retain a documented rollback path for each integration.
8. Remove temporary staging/backfill permissions and data after verification.

Never enable production payments, public reviews, leaderboards, external messaging, or transactional agent actions by default immediately after metadata deployment.

## 15. Definition of done for every feature

A feature is complete only when:

- Data model, sharing, CRUD/FLS, custom permissions, and retention are defined.
- Business rules are implemented in a reusable service and documented.
- Member identity or librarian authorization is enforced server-side.
- Idempotency, concurrency, audit, and failure recovery are addressed.
- LWC loading, empty, success, validation, permission, and error states exist.
- Apex and Jest tests cover positive and adversarial paths.
- Accessibility, localization, mobile/responsive behavior, and performance are verified.
- Reports/monitoring, operating procedure, support ownership, and rollback steps exist.
- UAT evidence is recorded and release validation passes.
- Documentation and manifests are updated.

## 16. Recommended implementation artifacts

For each phase, add or update:

- `DATA_MODEL.md` for deployed objects, fields, keys, and relationships.
- `WORKFLOWS.md` for committed state machines and user journeys.
- `SECURITY_MODEL.md` for access boundaries and negative guarantees.
- `docs/OPERATIONS.md` for schedulers, integrations, recovery, and incident procedures.
- `docs/UAT_TEST_PLAN.md` for end-to-end journeys.
- Deployment manifests and schema/package validation scripts.
- Permission sets, sharing rules/sets, report types, reports, dashboards, Custom Metadata, LWCs, Apex services, and tests.

This blueprint should remain the planning source until each feature is delivered. Once a feature is deployed, move its authoritative details into the existing architecture, workflow, security, operations, and UAT documents and mark the corresponding roadmap item complete.

### Current implementation status

The implementation slices described in this blueprint are deployed through ledger migration readiness visibility. Remaining work is actual provider credential setup, administrator-created/validated Data Cloud resources, and approved migration from the temporary scan ledger to dedicated objects when the target-org metadata is ready.

The twenty-eighth slice, notification delivery tracking, is implemented and deployed with per-channel `Notification_Delivery__c` attempts, idempotent delivery keys, provider-safe outcome codes, queueable email status updates, librarian delivery-health summaries, and notification regression coverage.

The twenty-ninth slice, notification delivery retry hardening, is implemented and deployed with bounded retry metadata, lock-claimed due retries, queueable backoff processing, a schedulable retry entry point, a permission-gated librarian retry action, regression coverage for retry claiming and UI behavior, and an idempotently provisioned hourly org schedule.

The thirtieth slice, payment gateway readiness visibility, is implemented and deployed with provider/enabled/Named Credential metadata fields, a disabled INR-default baseline record, a secret-safe Apex readiness DTO, a librarian Payments status panel, and regression coverage for incomplete and ready configuration states. Actual provider credentials remain an administrator-owned setup step.

The thirty-first slice, Data Cloud source readiness, is implemented and deployed with explicit production-member isolation checks, unclassified-member and non-production child-record contamination counts, verified-email quality warnings, a permission-gated librarian Reports panel, and Apex/LWC regression coverage. It is intentionally source-side governance only; it does not create or claim Data Cloud streams, mappings, or calculated insights.

The thirty-second slice, Data Cloud ingestion handoff, is implemented and deployed as a versioned source-safe contract in the readiness response and Reports panel. It publishes the exact production predicates, governed/deferred source lists, current blockers/warnings, and a JSON download for administrator review without exposing secrets or claiming that Data Cloud resources exist.

The thirty-third slice, calculated-insight relationship integrity, is implemented and deployed with production row counts and orphan detection for loans, reservations, and fines. Orphaned child rows are explicit readiness blockers, surfaced as relationship gaps in Reports, and covered by an Apex regression test so downstream DMO/insight counts cannot be treated as trustworthy until relationships are complete.

The thirty-fourth slice, calculated-insight setup catalog, is implemented and deployed with five governed insight definitions (active loans, overdue count/days, outstanding fine balance, reservation activity, and book popularity), source mappings, purpose text, and blocked/ready-for-setup-review statuses. It is a setup contract only; actual Data Cloud calculated insights still require administrator creation and runtime validation.

The thirty-fifth slice, ledger migration readiness, is implemented and deployed with a permission-gated read-only inventory of temporary scan-ledger operations, known/migratable row counts, malformed metadata detection, unknown-operation blockers, a librarian Reports panel, and Apex/LWC regression coverage. It does not mutate or delete ledger data; dedicated-object migration remains an approved future operation.

The thirty-sixth slice, ledger migration manifest export, is implemented and deployed with a versioned JSON download containing the source ledger, operation inventory, candidate counts, blockers, and generation timestamp. It is a planning artifact only and does not authorize or execute migration.

The thirty-seventh slice, ledger migration target mapping, is implemented and deployed with planned dedicated-object targets for the documented operation types, explicit metadata-pending labels where no target is indexed, an expanded Reports inventory, and regression coverage. These are architecture mappings, not proof that target objects exist or authorization to migrate records.

The thirty-eighth slice, ledger migration plan review, is implemented and deployed with a permission-gated, idempotent review action, optional planning note, reviewer/timestamp visibility, compact audit persistence through `LibraryOperationAuditService`, and Apex/LWC regression coverage. It records that the current manifest was reviewed; migration remains a separately approved operation.

The thirty-ninth slice, ledger migration target metadata validation, is implemented and deployed with read-only `Schema.getGlobalDescribe()` checks for every planned target, explicit target availability in the migration manifest, blocker messages for rows whose target object is absent, and regression coverage. It prevents a planning review from being mistaken for migration readiness when the target-org metadata is incomplete.

The fortieth slice, Agentforce action registration and activation, is implemented with six registered `GenAiFunction` Apex actions and input/output schemas, generated read-only `GenAiPlugin` topics, activated librarian/member agent versions, a repeatable Agentforce manifest, permission-set access, an explicitly bound librarian Agent Script refresh bundle, and preview/deployment documentation. The internal workspace is pointed at the activated librarian agent. The refresh bundle passes CLI compilation; publishing it is currently waiting on a transient Agentforce authoring-service connection timeout. Until the new version is published and activated, the org's CLI preview still reports the custom action schema as unavailable and falls back to the platform knowledge action. Member private actions remain channel-gated until a trusted portal-session context bridge is configured; the assistant must never request a session token or identity override in chat.
