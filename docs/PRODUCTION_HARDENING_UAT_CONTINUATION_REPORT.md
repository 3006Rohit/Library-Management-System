# Production Hardening and End-to-End UAT Continuation Report

Date: 2026-10-13  
Org: `library-org` / `00DgK00000bjSndUAE`  
API: v68

Scope was limited to production-hardening verification and project-controlled cleanup assessment. Member-session authentication, payments, Data 360 relationship metadata, and Agentforce activation were not changed.

## A. Browser UAT

Not executed. This workspace has no connected browser automation runner, and no Playwright/Cypress project runner is configured. Therefore registration, activation, login, logout, password reset, librarian workspace, circulation, reservation, fine, console, redirect, and route behavior remain unverified in a real browser.

## B. Registration E2E

Automated registration/provisioning tests pass, including idempotent approval and the no-Salesforce-User path. A new public registration was not created because a real browser and recipient inbox were unavailable.

Verified design behavior: active provisioning creates one `Member__c` and activation state without creating a Salesforce `User`.

## C. Email delivery

Not externally verified. No inbox/spam validation was available for activation, reset, approval, or rejection messages. Unit tests prove enqueue/logic behavior only; they do not prove delivery or link usability.

## D. Member isolation

Automated isolation coverage passed, including cross-member read/mutation denial and session expiry/revocation. The required two-member real browser/devtools isolation test was not executed; `MEMBER BROWSER ISOLATION VERIFIED` is therefore not asserted.

## E. Circulation

Automated checkout, return, overdue/fine, renewal, copy lifecycle, borrow-limit, availability, and reservation-conflict coverage passed. Live production-only reconciliation:

| Measure                             | Result |
| ----------------------------------- | -----: |
| Production loans                    |     14 |
| Active loans                        |      3 |
| Returned loans                      |     11 |
| Active loan with available copy     |      0 |
| Duplicate active loans for one copy |      0 |

Real browser checkout/renewal/return cases were not executed.

## F. Reservations

Automated reservation lifecycle, cancellation, promotion, renewal, and audit coverage passed. Live production-only total is 11 (`5 Fulfilled`, `6 Cancelled`). Orphan active reservations are 0. Real browser reservation UAT was not executed.

## G. Fines

Automated fine creation and controlled payment/waiver coverage passed. Live production-only total is 1 (`Paid`). Orphan fines are 0. Real browser fine visibility and cross-member checks were not executed. Payment integration was not changed.

## H. Data 360 UI

The governed production source reconciliation is consistent with the expected dashboard dataset:

| Metric         | Live production value |
| -------------- | --------------------: |
| Total copies   |                   362 |
| Available      |                   350 |
| Borrowed       |                     9 |
| Reserved       |                     2 |
| Lost           |                     1 |
| Loans          |                    14 |
| Active loans   |                     3 |
| Returned loans |                    11 |
| Reservations   |                    11 |
| Fines          |                     1 |

The Data 360 dashboard and member activity panel were not visually rechecked in a browser during this continuation. Existing Data 360 formal relationship persistence remains a Salesforce platform blocker and was not retried.

## I. Failed registration cleanup

| Registration | Status  | Provisioning state | Error                                    | Classification | Action                                         |
| ------------ | ------- | ------------------ | ---------------------------------------- | -------------- | ---------------------------------------------- |
| `REG-00007`  | Pending | Failed             | No Customer Community licenses available | STALE / TEST   | Retain as evidence; no blind delete or rewrite |
| `REG-00009`  | Pending | Failed             | No Customer Community licenses available | STALE / TEST   | Retain as evidence; no blind delete or rewrite |

Both records already have an active `Member__c` with `Member_Type__c = Test`, a linked Contact, and no Salesforce User. They are inconsistent test artifacts, not valid production pending requests. No duplicate registration email count was found. They should be removed or explicitly finalized only under an approved test-data cleanup decision.

## J. Legacy User cleanup

| Artifact                                  | Usage                                        | Runtime dependency                          | Decision                                        |
| ----------------------------------------- | -------------------------------------------- | ------------------------------------------- | ----------------------------------------------- |
| `Member__c.User__c`                       | Legacy bridge and session response scrubbing | Not required by active custom-session login | KEEP_TEMPORARILY / MIGRATE                      |
| `LibraryRegistrationUserQueueable`        | Legacy Salesforce User provisioning          | No active caller found                      | SAFE_TO_REMOVE candidate; do not delete blindly |
| `LibraryRegistrationFinalizeQueueable`    | Legacy finalization path and direct tests    | Test/compatibility dependency               | KEEP_TEMPORARILY                                |
| `External_User__c`, `Provisioned_User__c` | Registration metadata/UI history             | Legacy review and compatibility surfaces    | KEEP_TEMPORARILY / MIGRATE                      |

The active registration path does not create Salesforce Users. No authentication redesign was made.

## K. Legacy Contact cleanup

Contact remains required today. `Member__c.Contact__c` is used by transaction synchronization, Contact-based sharing sets, member/transaction access, notification/payment bridges, legacy Experience Cloud compatibility, and tests. `Borrow_Record__c.Contact__c`, `Reservation__c.Contact__c`, and `Fine__c.Contact__c` are maintained by active synchronization triggers/services.

Recommendation: KEEP the Contact bridge until sharing and Experience Cloud dependencies are formally migrated and regression-tested. Do not remove these fields now.

## L. Dead metadata

SAFE_TO_REMOVE candidates after a separate dependency-approved change:

- unreferenced legacy Salesforce-User provisioning queueable;
- obsolete test-only scripts and stale compatibility metadata after confirming no deployment/package dependency.

KEEP_FOR_NOW:

- active member/session/auth controllers and LWCs;
- Contact bridge fields, triggers, sharing sets, and Experience Cloud metadata;
- legacy finalization and external-registration review surfaces used by tests or librarian UI;
- six permanent Agentforce GenAiFunctions (agents remain inactive).

Salesforce-blocked diagnostic Apex cleanup remains pending. The temporary diagnostic GenAiFunctions and runtime diagnostic test were removed successfully; two diagnostic Apex classes remain undeletable because Salesforce reports stale internal Generative AI Function references.

## M. Test results

| Suite                              | Passed | Failed |
| ---------------------------------- | -----: | -----: |
| Apex RunLocalTests                 |    101 |      0 |
| Org-wide Apex coverage             |    83% |      — |
| LWC Jest                           |     20 |      0 |
| ESLint                             |   pass |      0 |
| Targeted deployment validation     |   pass |      0 |
| Authentication/session tests       |   pass |      0 |
| Registration tests                 |   pass |      0 |
| Circulation/reservation/fine tests |   pass |      0 |
| Data Cloud service tests           |   pass |      0 |

Prettier verification remains non-zero because 382 existing files have style warnings. The malformed/base64 Agentforce payload parsing issue was excluded safely; this is a formatting backlog, not a deployment failure.

## N. Remaining application defects

| ID      | Severity | Defect                                                       | Status                              | Release blocking                      |
| ------- | -------- | ------------------------------------------------------------ | ----------------------------------- | ------------------------------------- |
| APP-001 | P1       | Real browser UAT has not been executed                       | Open                                | Yes, until executed                   |
| APP-002 | P1       | External email delivery/link lifecycle has not been verified | Open                                | Yes, until verified                   |
| APP-003 | P2       | Two stale failed test registrations remain in org data       | Contained; cleanup decision pending | No production-data impact established |
| APP-004 | P4       | Legacy User/Contact compatibility metadata remains           | Documented migration debt           | No, while dependencies remain         |
| APP-005 | P4       | Repository-wide Prettier warnings remain                     | Open                                | No runtime impact                     |

## O. Salesforce platform blockers

- Data 360 formal custom-DMO relationship persistence remains the previously documented Salesforce support issue.
- Agentforce custom-object Apex runtime support fails for the affected catalog actions.
- Agentforce protected session actions fail with entity-access errors.
- Two old diagnostic Apex classes cannot be deleted because of stale internal Generative AI Function references.

No risky workaround or repeated relationship retry was performed. Agentforce remains inactive.

## P. Release impact

| Blocker                                  | Core app impact                          | Optional feature impact                       |
| ---------------------------------------- | ---------------------------------------- | --------------------------------------------- |
| Data 360 formal relationship persistence | None demonstrated in CRM workflows       | Data 360 relationship navigation/formal model |
| Agentforce custom-object runtime issue   | None                                     | Blocks Agentforce activation/catalog actions  |
| Stale diagnostic metadata references     | None                                     | Blocks cleanup only                           |
| Browser UAT not executed                 | Release evidence incomplete              | Affects release decision until run            |
| Email delivery not verified              | Registration/reset confidence incomplete | Affects release decision until run            |

## Q. Final release decision

**PRODUCTION RELEASE BLOCKED**

The automated and live-data quality baseline is strong, but the required real-browser UAT, member-isolation browser test, registration E2E, and external email-delivery verification were not completed in this environment. The core application must not be declared production-ready solely from unit tests. Once those tests pass, the Salesforce Data 360 and Agentforce issues can remain deferred without blocking the core library workflows.
