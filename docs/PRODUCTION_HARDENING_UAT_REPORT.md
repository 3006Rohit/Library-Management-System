# Production Hardening and End-to-End UAT Report

Date: 2026-10-13

Org: `00DgK00000bjSndUAE` (`library-org`)

## A. Authentication

| Component                        | Purpose                                                                | Security status                                              | Issue                                                                                         |
| -------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------ | --------------------------------------------------------------------------------------------- |
| `LibraryMemberAuthController`    | Login, registration bridge, activation, reset, logout                  | Strong server-side validation; generic login/reset responses | `without sharing`; intentionally required for guest custom authentication                     |
| `LibraryMemberPasswordService`   | Salted password hashing, token generation, constant-time comparison    | Pass                                                         | SHA-256 password hashing should remain a documented risk decision; no plaintext storage found |
| `LibraryMemberSessionService`    | Opaque token hash lookup, expiry, revocation, member status validation | Pass                                                         | Raw token is returned only at login and stored in browser session storage                     |
| `LibraryMemberSessionController` | Session-scoped member reads and existing member operations             | Pass in Apex isolation tests                                 | Guest profile has access to this broad controller; review endpoint exposure before production |
| Login LWC                        | Login and session bootstrap                                            | Pass in unit coverage                                        | Browser test pending                                                                          |
| Activation/reset LWC             | One-time route-token flows                                             | Pass in unit coverage                                        | Browser/email test pending                                                                    |
| Logout LWC                       | Remove browser token and revoke server session                         | Pass by inspection/unit coverage                             | Browser test pending                                                                          |

There is one supported browser authentication path: `Member__c` plus
`Member_Session__c`. The Contact/User identity path remains in legacy internal
controllers and metadata and must not be used for member authentication.

## B. Guest security

The Guest User profile has no general CRUD access to `Member_Session__c`,
`Borrow_Record__c`, `Reservation__c`, `Fine__c`, or `Membership_Payment__c`.
It has read access to `Member__c`, catalog objects, and plans, plus create/read
access to `Library_Registration__c` for the public registration surface.

| Public route    | Apex                                 | Required guest access                               | Status                             |
| --------------- | ------------------------------------ | --------------------------------------------------- | ---------------------------------- |
| Login           | `LibraryMemberAuthController`        | Class access; session object remains unpermissioned | Unit-tested; browser pending       |
| Registration    | `LibraryRegistrationGuestController` | Registration create and plan/catalog reads          | Unit-tested; browser pending       |
| Activation      | `LibraryMemberAuthController`        | Class access; token resolved server-side            | Unit-tested; email/browser pending |
| Forgot password | `LibraryMemberAuthController`        | Class access; generic response                      | Unit-tested; email/browser pending |
| Reset password  | `LibraryMemberAuthController`        | Class access; token hash lookup                     | Unit-tested; email/browser pending |

## C. Member isolation

`LibraryMemberAuthControllerTest`, `LibraryMemberControllerTest`,
`LibraryMemberApiTest`, and `LibraryAgentActionsTest` pass Member A/B and
invalid-token isolation checks. URL, browser JavaScript, and live HTTP
tampering were not executed in this environment.

Therefore the required final label `MEMBER ISOLATION VERIFIED` is not issued.

## D. Librarian authorization

Librarian custom permissions and Apex enforcement are covered by passing tests,
including unauthorized internal-user denial. The librarian permission set has
functional create/edit/read access for operational objects and no Modify All or
View All grants.

Hardening issue: `Library_Librarian` still grants editable/readable access to
`Member__c.User__c` and readable access to legacy external-auth fields. This is
not needed by the canonical session design and is classified P2 hardening debt.

## E. Registration

Automated registration, approval, rejection, retry, idempotency, duplicate,
validation, and no-user-creation tests passed.

Live data contains two `Pending` registrations in `Failed` provisioning state.
Their stored message says no Customer Community licenses are available. These
are pre-existing failed records and require operational disposition before UAT.

## F. Activation/reset

Automated activation, reset, expiry, reuse, lockout, and revocation tests
passed. Real email delivery and browser navigation were not verified.

## G. Books/copies

Book and copy lifecycle tests passed. Current reconciliation counts:

- Available copies: 350
- Borrowed copies: 9
- Reserved copies: 2
- Lost copies: 1

No duplicate active loan was found for the same copy.

## H. Checkout

Automated successful checkout and negative-path tests passed, including plan
duration, borrow limits, unavailable copies, inactive members, and atomic copy
handling. Browser UAT is pending.

## I. Renewal

Automated renewal and reservation-conflict tests passed. Browser UAT is pending.

## J. Return

Automated return and overdue-fine tests passed. One active lost loan is expected
to remain without a return date. Browser UAT is pending.

## K. Reservations

Automated reservation creation, cancellation, promotion, queue ordering,
fulfillment, expiry, and renewal tests passed. Current records include 3
Pending, 2 Ready, 7 Fulfilled, 8 Cancelled, and 1 Expired reservation.

No orphan pending/ready reservation was found.

## L. Fines

Automated fine generation, balance, payment-state, and waiver tests passed.
Current records include 2 Unpaid, 1 Partially Paid, 3 Paid, and 1 Waived fine.
No orphan fine was found.

Payment implementation was not modified.

## M. Membership

Plan-driven duration, borrow-limit, renewal, reservation, fine, and fee logic
passed automated tests. At least two plan paths are covered by the service test
suite. Browser UAT is pending.

## N. Data 360 regression

Existing Data 360 UI integration and Calculated Insights implementation remain
unchanged. The formal DMO relationship metadata remains a Salesforce Support
blocker. Transactional application behavior remains functional when analytics
are unavailable, as shown by passing Data Cloud service tests.

## O. Browser E2E

Not completed. No browser automation dependency or browser execution harness is
configured in the project. The four LWC Jest suites are not a substitute for
browser, guest, member, and librarian HTTP validation.

Required follow-up: execute public, member, and librarian flows in a real
browser against the target site and capture console/Apex errors.

## P. Email delivery

Email paths are unit-tested for activation, reset, approval, rejection, and
failure handling. Real recipient delivery, link validity, and token exposure in
delivered mail were not verified.

## Q. Data consistency

Reconciliation results:

| Check                                 |                                                        Result |
| ------------------------------------- | ------------------------------------------------------------: |
| Active loan with Available copy       |                                                             0 |
| Duplicate active loans on one copy    |                                                             0 |
| Orphan pending/ready reservations     |                                                             0 |
| Orphan fines                          |                                                             0 |
| Active member without membership plan |                                                             0 |
| Pending duplicate registration email  |                                                             0 |
| Returned loan with Borrowed copy      | 3 historical rows; each copy is reused by a later active loan |

The three historical returned/Borrowed pairs are not treated as defects because
the same copy has subsequently been borrowed.

## R. Tests and coverage

| Test type              |                                                               Passed |    Failed |
| ---------------------- | -------------------------------------------------------------------: | --------: |
| Local Apex tests       |                                                                  101 |         0 |
| Org-wide Apex coverage |                                                                  83% |         — |
| LWC Jest tests         |                                                                   20 |         0 |
| ESLint                 |                                                                 Pass |         0 |
| Prettier verification  | 0 files failed to parse after ignore; 381 formatting warnings remain | Not clean |

Authentication coverage is 97–100% for the canonical auth/session classes.
`LibraryMemberController` is 87%, `LibraryLibrarianController` 80%, and
`LibraryDataCloudService` 76% in the org-wide run.

## S. Deployment cleanup

Classified legacy artifacts:

| Artifact                                     | Classification                   | Reason                                                                                            |
| -------------------------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------- |
| `LibraryMemberIdentityService`               | KEEP temporarily / MIGRATE later | Still referenced by `LibraryMemberController` and tests                                           |
| `LibraryMemberController`                    | KEEP temporarily                 | Existing LWCs and tests still reference it                                                        |
| `LibraryRegistrationUserQueueable`           | DEAD CODE candidate              | Active provisioning queueable does not call it; legacy Salesforce User creation remains in source |
| `LibraryRegistrationFinalizeQueueable`       | TEST-ONLY / legacy               | Active path does not enqueue it; lifecycle tests still exercise it                                |
| `Member__c.User__c`                          | LEGACY / MIGRATE later           | Data model and permission metadata still retain it                                                |
| `Member__c.Contact__c`                       | KEEP as sharing bridge           | Existing transaction/contact synchronization depends on it                                        |
| `Provisioned_User__c`, `Provisioned_User__c`    | LEGACY / MIGRATE later           | Registration metadata and review UI still expose them                                             |
| Temporary Agentforce diagnostic Apex classes | PLATFORM CLEANUP PENDING         | Salesforce stale internal references block deletion                                               |

The malformed/base64 Agentforce graph is now excluded from Prettier input via
`.prettierignore`. Repository-wide formatting still has 381 warnings and
should be cleaned in a separate controlled formatting change.

## T. Open Salesforce platform blockers

1. Agentforce Apex actions reject supported custom objects at runtime.
2. Member Agent private actions receive `NoAccessException` when the protected
   session object is intentionally not permissioned.
3. Salesforce stale Generative AI Function Definition references block cleanup
   of two temporary Apex classes.
4. Data 360 formal relationship metadata remains under Salesforce Support.

## U. Defect list by severity

### P0

No P0 exposure was found in the automated/static audit.

### P1

- Production UAT cannot be signed off without real browser/API tampering tests.
- Agentforce activation remains blocked by runtime defects; agents stay inactive.

### P2

- Guest profile exposes the broad session controller surface; endpoint-level
  review is required before production.
- Librarian permission metadata still exposes legacy `Member__c.User__c` and
  external-auth fields.
- Two failed pending registrations require operational cleanup or retry.
- Real activation/reset email delivery is unverified.

### P3/P4

- 381 Prettier formatting warnings remain.
- Legacy Contact/User registration artifacts remain in source and metadata.
- Temporary diagnostic Apex classes remain in the org because Salesforce blocks
  deletion through stale internal references.

## Final status

`PRODUCTION HARDENING BLOCKED`

The core automated application suite is green, but browser/API UAT, real email
verification, Agentforce runtime support, and legacy authorization cleanup are
not complete enough for production-quality UAT sign-off.
