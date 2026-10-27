# Workflows

## New external member

`Create IdP account -> verification email -> verify -> sign in -> complete application -> Pending -> librarian review -> approve/reject -> Active or Rejected -> sign in -> UID resolution -> scoped dashboard`

Approval activates the already linked Member record and membership dates. It does not create a Salesforce community user. Rejected accounts remain linked for audit and cannot access the portal; reapplication/reactivation requires an explicit librarian policy.

## Member access

The profile Notifications tab creates a default In-App and Email matrix, lets a member disable individual channels/types, and saves digest/quiet-hour settings through the session-scoped preference service. Outbound email creation enforces the saved Email preference server-side; in-app notifications remain available.

Every notification now creates separate In-App and Email delivery-attempt records. In-app delivery is marked delivered immediately; email attempts remain pending until the queueable records a provider-accepted or failed result. Disabled channels and missing addresses are marked skipped with a categorical reason. Delivery records are idempotent per notification/channel and the librarian Reports panel shows pending, sent, delivered, failed, and skipped totals without exposing message payloads.

Provider-rejected email attempts are retryable up to the delivery row's maximum-attempt value. Failed rows receive a bounded backoff timestamp, and the retry service claims eligible rows under lock before queueing email work, so concurrent scheduler or librarian retries cannot double-claim a delivery. Exhausted attempts remain failed for exception review; rows without an address are skipped. The Reports panel exposes a permission-gated action for manually queueing retryable failed email deliveries, while `LibraryNotificationRetryScheduler` can process due retries on a schedule.

The target org has one idempotently provisioned hourly `Library Notification Retry Hourly` job in `WAITING` state. The repeatable setup block is stored in `scripts/schedule_notification_retry.apex`; it checks for the named job before calling `System.schedule`.

The profile Accessibility tab stores a member's preferred language and timezone plus high-contrast, larger-text, reduced-motion, and screen-reader preferences. The session-scoped service validates supported values and persists them on `Member__c`; the portal applies visual settings immediately, keeps controls keyboard-friendly, and uses the timezone for member-facing scheduling and notification context. Sensitive flows remain unchanged by presentation preferences.

Members can also open Scan & Borrow, enter a copy barcode or use a supported camera, preview the copy, and confirm checkout. Scanned returns are restricted to the authenticated member's own active loan. Every checkout/return uses a unique scan key and persists a server-side transaction so retries cannot create duplicate circulation records.

The profile Digital Card tab issues a ten-minute opaque member-card token for kiosk or service-desk presentation. Only a SHA-256 hash is stored; the token is never a Salesforce ID or session token. A validation endpoint locks and consumes the token after one successful use, rejects unknown/expired/replayed tokens generically, and returns only the active member's display-safe card details.

Librarians can open Acquisition Intelligence to review explainable purchase/replace recommendations. The service evaluates a rolling 90-day Salesforce evidence window (reservations, checkouts, availability, and damaged/lost copies), assigns a score and confidence, and persists a new snapshot rather than mutating prior evidence. Librarians can accept, defer, or reject each recommendation with an optional note. Catalog searches may record only a one-way query hash and result status for zero-result demand discovery; no raw search text is retained.

Agentforce member transactions are confirmation-gated. The assistant first returns an exact preview for an eligible renewal or reservation cancellation, then accepts a short-lived single-use token only after the member explicitly confirms. The server revalidates the session, target ownership, policy, expiry, and idempotency state before calling the existing circulation service; replayed, altered, expired, or cross-member tokens are rejected.

Members can save a book to a private Reading List directly from book details without creating a reservation. The Reading Lists workspace supports Want to Read, Currently Reading, Completed, and Abandoned states, private notes, optional ratings, and an availability-notification intent. Entries are member-scoped, idempotent per member/book, and removable only by their owner.

Members can follow the linked author from book details and manage those follows from Authors I Follow. Follow and unfollow operations are member-scoped and idempotent, and the portal never exposes another member’s follows.

Members can submit a 1–5 rating and short review from book details. New reviews enter `Pending` status, are never treated as public content before moderation, and can be approved or rejected by a librarian with the catalog-management permission.

Members can open Events to browse upcoming library programs, register once per event, join a waitlist when capacity is full, and cancel their own registration. The service locks the event ledger row before making the capacity decision; event discovery and registration are session-scoped. Librarians with catalog-management permission can publish events with a title, schedule, location, and capacity.

When a registered member cancels, the earliest waitlisted member is promoted under the event lock. A registered member can request a short-lived check-in code from the Events view; a librarian validates that hashed code against the selected event, and the registration becomes `Attended`. Raw codes are never persisted.

Members can open Rooms, choose a future time window and minimum capacity, then reserve an available room with an optional purpose. Room rows are locked before overlap checks, bookings are limited to eight hours, and members can cancel only their own bookings. Librarians with catalog-management permission can publish room inventory with location, capacity, and equipment metadata.

Members can open Reading Challenges to join active reading goals. Progress is calculated from their own borrow history inside each challenge window, enrollment is idempotent, and a completed goal is marked automatically once the target is reached. Librarians with catalog-management permission can publish a challenge with dates, description, and a target book count.

Members can open Branches to view active library locations and assigned-copy counts. Librarians can create branches, assign copies, request transfers, ship them, and receive them; active transfers are idempotent per copy and the destination assignment changes only on receipt.

Members can submit one appeal per unpaid fine with a reason of at least 10 characters. Appeals remain pending until a librarian reviews them and records an Approved or Rejected decision with a reason; approval does not silently waive the fine.

Members can request a future membership hold of 1–90 days with an explanation. Overlapping pending/approved requests are rejected, requests are idempotent for the same member and date range, and members can cancel only their own pending requests. A librarian reviews each request under the circulation permission; approval locks the member, extends the existing membership end date by the inclusive hold duration exactly once, and records the original/adjusted dates plus policy version. Recently expired memberships expose a separate seven-day read-only grace indicator; grace does not silently restore borrowing rights or change account status.

Librarians can run no-show processing from the dashboard. The idempotent processor delegates expired ready-reservation handling to the circulation workflow (including queue promotion), marks completed room bookings and past registered events as `No-show`, records counts in an audit ledger row, and never changes already attended, cancelled, waitlisted, or previously processed records.

Librarians can publish planned or emergency closure ranges globally or for a branch, including the branch timezone. New checkouts and renewals use `LibraryCalendarService`; the requested loan duration is preserved, but a due date landing inside an active closure is moved to the next open date. Closure creation is idempotent for the same branch and date range, and existing loans are not silently rewritten.

The Privacy Center requires the member's current password before accepting an export, correction, or deletion request. Exports are allowlisted JSON files containing member-owned profile, circulation, financial, engagement, event, room, and notification data; password hashes, session/confirmation tokens, risk signals, and unrelated staff notes are excluded, and the protected file expires after 24 hours. Corrections wait for librarian approval. Approved account closure anonymizes profile identifiers, revokes all member sessions, and records the retention reason for loans, fines, payments, audit, and safety records that cannot be deleted. Every request is member-scoped and idempotent.

Privileged operations also write an immutable-style audit entry with the acting user, permission context, operation, target, correlation ID, reason, result, and compact before/after digests. The audit trail is intentionally safe-by-construction: fields containing passwords, tokens, secrets, or hashes are excluded before digesting, and the raw state is never stored. The librarian audit viewer supports operation filtering and is permission-gated.

The risk scanner evaluates explainable patterns over a bounded 90-day window, including repeated replacement-required loans and frequent fine waivers. It creates idempotent, member-scoped alerts with evidence and a review score. Librarians can resolve or mark an alert as a false positive with a rationale; the scanner never changes membership, borrowing eligibility, payment state, or service access automatically.

The executive summary service creates one idempotent aggregate snapshot per reporting day and can also run through `LibraryExecutiveSummaryScheduler`. The librarian dashboard shows the latest metrics and recent history; summaries contain counts and totals only, state the reporting date, and direct authorized staff to Salesforce reports for record-level investigation.

Paid membership transactions can produce an idempotent protected receipt. Transactions marked `Pending` or `Exception` in reconciliation appear in the finance review panel; a librarian must record a reason before marking a transaction `Reconciled` or `Exception`. These operations do not retry or mutate gateway state and are fully audited.

The Payments workspace also displays a read-only gateway readiness check. It is marked ready only when the default configuration is enabled and includes a provider name, checkout Named Credential reference, and webhook secret. The repository deploys a disabled INR-default configuration record as a safe baseline. The check returns only safe status booleans and guidance; it never exposes secret values or turns on a provider automatically.

Bulk catalog import requires a CSV header containing `title` and `isbn`. Librarians preview up to 200 rows, receive row-level validation for missing, duplicate, or already-cataloged ISBNs, and can commit only when every row is valid. A stable import key makes retries idempotent, and the batch is audited after successful insertion.

Stocktake audits are explicitly started and closed. Each barcode scan is idempotent per audit and records expected status, observed status, and an optional discrepancy note. The scan never changes copy status or location; reconciliation is a separate, reasoned action after the audit is closed.

Every protected request validates the token, resolves exactly one active/verified member, and scopes data by that member. Members can browse, view their profile/loans/reservations/fines/membership/payments, edit permitted profile fields, borrow an available copy, reserve a book, renew their own eligible loan, and cancel their own eligible reservation.

## Librarian operations

The Lightning workspace supports dashboard, books/copies, members, registrations, circulation, reservations, and fines. Catalog, circulation, fine, and registration methods require distinct custom permissions. Librarians can suspend and reactivate verified external portal accounts through a real backend operation. Librarian member selection is valid because it is an internal operational workflow; it is never used as member identity.

The Reports workspace includes a Data Cloud source-readiness panel. `LibraryDataCloudReadinessService` checks that source members are explicitly classified as `Production`, counts unclassified members, non-production loans/reservations/fines, and orphaned child records that would break calculated-insight relationships, and reports missing verified email as a warning. Blockers are shown as `Blocked`; clean sources are `Ready` or `Ready with warnings`. The panel also shows a versioned handoff contract with the exact member/child predicates, governed source objects, deferred sources, and the five approved calculated-insight definitions; Download JSON produces a secret-free checklist for administrator-led Data Cloud setup. Insight statuses mean setup review readiness only—this panel deliberately does not claim that Data Cloud streams, mappings, or calculated insights exist; those remain administrator-owned setup work.

The Reports workspace also shows ledger migration readiness. `LibraryLedgerMigrationReadinessService` inventories the temporary `Library_Scan_Transaction__c` ledger by operation, counts rows with stable migration metadata, checks whether each planned target object is actually deployed, shows planned dedicated-object targets where defined, and blocks planning when an operation is unknown, required metadata is missing, or a row's target object is absent. Download manifest produces a versioned JSON snapshot for migration planning. A librarian with circulation-management permission can record one idempotent review for that manifest, optionally adding a note; the review is written through `LibraryOperationAuditService` and displays the reviewer and timestamp. Review is a planning checkpoint only and does not migrate, rewrite, delete, or authorize ledger rows.

## Checkout

Checks active membership and plan, expiry, borrow limit, outstanding fines, copy availability, and reservation priority. Creates one active loan and changes the copy to Borrowed. Inventory aggregates update automatically.

## Return and fines

Closes the loan. An overdue fine is generated once from the plan's daily rate. If no queue exists the copy becomes Available; otherwise the earliest pending reservation becomes Ready, receives the copy and expiry, and the copy becomes Reserved.

## Renewal

Requires an active/overdue loan owned by the member, eligible membership, remaining renewal allowance, and no blocking reservation from another member. Extends by the plan loan duration.

## Reservations

Enforces membership eligibility, plan reservation limit, and one active reservation per member/book. Queue order is by reservation time then ID. Cancelled/expired ready holds promote the next member and resequence the queue.

Pending and ready reservations also receive an explainable availability estimate through `LibraryReservationEtaService`. The estimate uses currently available copies, known active-loan due dates, queue position, and a conservative default loan duration when no return date is known. It is labelled with High, Medium, or Low confidence and is recalculated after reservation creation/cancellation, checkout, return, promotion, and expiry processing. It is an estimate, never a guarantee, and does not replace queue order or circulation-policy checks.

## Membership and payments

Current payment code records demonstration payments and membership changes. It is not a production payment gateway. Do not represent it as charging real money. Production requires gateway redirect/tokenization, signed webhook confirmation, idempotency, reconciliation, and refund handling.

The hardened gateway workflow creates an `Initiated` hosted-checkout transaction with a unique idempotency key. The REST webhook endpoint accepts only HMAC-signed events, validates amount/currency and event uniqueness, and is the only path that marks a payment `Paid`, `Failed`, `Cancelled`, `Disputed`, or refunded. Refund requests require a reason, permission, idempotency key, and remaining refundable balance; the provider's signed refund event finalizes the payment state. Configure the protected `Payment_Gateway_Config__mdt` secret before enabling a real provider.

Reading challenges automatically award one idempotent completion badge and generate an accessible text certificate when a member reaches a goal. Progress includes a verified borrowing streak. Leaderboards are disabled by default, use anonymous reader aliases, and show only members who explicitly opt in; leaving the leaderboard does not remove private progress or achievements.
## Copy repair and missing-book condition lifecycle

Librarians can open a repair case by barcode only for a copy currently marked `Damaged`, `Lost`, or `Maintenance`; borrowed copies must complete circulation first. Opening a case records the issue and moves the copy to `Maintenance`. A case can be resolved once: `Repaired` returns the copy to `Available` with `Good` condition, while `Unrepairable` retires it with `Poor` condition. Each transition is idempotent, permission-checked, and recorded in the administrative audit trail.

## ISBN metadata and catalog-quality review

Librarians can normalize and checksum-validate an ISBN before any provider callout. A preview retrieves bibliographic values through the `Library_Metadata` Named Credential, reports missing fields and probable existing ISBN matches, and leaves the catalog unchanged during provider failures. Applying metadata requires a target Book record and explicit field selection; curated fields are never overwritten implicitly, duplicate ISBNs are rejected, and the applied field set is audited.
