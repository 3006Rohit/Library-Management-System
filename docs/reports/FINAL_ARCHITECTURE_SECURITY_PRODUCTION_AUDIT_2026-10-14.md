# Final Architecture, Security, and Production Readiness Audit

Date: 2026-10-14  
Scope: all 614 repository files, current working tree, connected `library-org` schema/tests, Experience Cloud, Data Cloud source, and Agentforce source. Existing uncommitted work was preserved.

## 1. Executive Summary

```text
Overall Status:          DEPLOYED; CONDITIONAL PRODUCTION ACCEPTANCE
Production Readiness:    7.4/10
Architecture Rating:     7.5/10
Security Rating:         7.5/10 after fixes
Backend Rating:          8.0/10
Frontend Rating:         7.0/10
Authentication Rating:   8.0/10 after fixes
Testing Rating:          8.5/10
Data Cloud Rating:       6.0/10 (source present; runtime evidence incomplete)
Agentforce Rating:       7.0/10 (source present; runtime acceptance incomplete)
```

The actual member design is custom `Member__c` authentication backed by hashed credentials and hashed, revocable `Member_Session__c` bearer tokens. The active portal is `libraryMemberShell` -> `LibraryMemberSessionController`; it does not trust a browser-supplied member ID. Internal librarian work is permission-gated and uses the librarian controller/service layer. Legacy Salesforce User/Contact member code remains as a documented compatibility path.

Two verified authentication defects were fixed: persistent bearer-token storage in `localStorage`, including incomplete logout cleanup; and missing row locking around login counters and single-use activation/reset token consumption. No plaintext passwords, raw persisted session/reset/activation tokens, hard-coded production record IDs, or repository secrets were found.

Production approval is withheld. Browser/email/isolation UAT is incomplete; the default Code Analyzer profile reports 214 high findings (209 are CRUD/FLS-rule findings that require endpoint-by-endpoint disposition); Data Cloud/Agentforce live configuration and runtime behavior are not fully provable from source; and the current worktree is an extensive, uncommitted release candidate.

## 2. Final Architecture

```text
Experience Cloud / LWR
  public catalog / registration / activation / login / reset
        -> guest/auth controllers
        -> registration + password + session services
        -> Member__c + Member_Session__c (only token hashes persisted)

  authenticated member shell (session token, sessionStorage only)
        -> LibraryMemberSessionController
        -> server-side session-to-member resolution
        -> circulation / reservation / membership / notification services
        -> member-scoped SOQL and ownership checks
        -> Salesforce library objects

Internal Salesforce app
        -> libraryLibrarianWorkspace
        -> LibraryLibrarianController / registration controllers
        -> custom-permission checks
        -> catalog / policy / circulation / reservation / payment services
        -> Salesforce library objects

Book_Copy__c and transaction triggers
        -> inventory/contact synchronization services

CRM objects -> org-configured Data Cloud streams/DMOs/calculated insights
        -> LibraryDataCloudService -> librarian analytics / agent actions

Librarian and member Agentforce definitions
        -> GenAI functions -> bounded Apex actions
        -> librarian permission checks or validated member session context
```

There are no committed Flows, Named Credentials, Remote Site Settings, Auth Providers, Connected Apps, or email templates. These are absent rather than silently assumed.

## 3. Workflow Results

| Workflow            | Result  | Evidence / limitation                                                                                                                |
| ------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Registration        | PASS    | Normalization, duplicate handling, lifecycle state, retry/idempotency tests pass.                                                    |
| Activation          | PARTIAL | Hashed, expiring, single-use token with new row lock; external email/link browser UAT remains.                                       |
| Login               | PASS    | Generic failure, salted hash, lockout, server session, and concurrency lock verified.                                                |
| Logout              | PASS    | Server revocation plus both current and legacy browser-token cleanup.                                                                |
| Forgot Password     | PARTIAL | Enumeration-safe response and hashed token; external delivery not verified.                                                          |
| Reset Password      | PASS    | Expiry, one-time consumption, blank rejection, row lock, and session revocation.                                                     |
| Catalog             | PASS    | Public/member/internal paths and inventory rollups have automated tests.                                                             |
| Borrow              | PASS    | Eligibility, row-locked copy selection, ready holds, and ownership tests pass.                                                       |
| Return              | PASS    | Copy transition and overdue fine creation tested.                                                                                    |
| Renew               | PASS    | Limit and reservation blocking tested.                                                                                               |
| Reservation         | PASS    | Duplicate/limit/lifecycle/promotion/cancellation behavior tested.                                                                    |
| Fine                | PASS    | Creation, payment, waiver, and authorization tests pass.                                                                             |
| Membership          | PARTIAL | Plan/renewal/upgrade ledger works; no real payment gateway exists, so UI records simulated/offline payment only.                     |
| Librarian Workspace | PARTIAL | Broad Jest/Apex coverage; real-browser accessibility/responsive/UAT remains.                                                         |
| Member Portal       | PARTIAL | Contracts and isolation tests pass; browser DevTools A/B tampering remains a release gate.                                           |
| Data Cloud          | PARTIAL | Service and CI mapping source exists; streams, identity resolution, mappings, freshness, and failed stream require org verification. |
| Agentforce          | PARTIAL | Definitions, versions, functions, actions, schemas, and tests exist; live channel/runtime/grounding acceptance remains.              |

## 4. File-by-File Audit Summary

Metadata sidecars are grouped with their owning source. Generated/versioned Agentforce and Digital Experience artifacts are grouped where individual rows add no architectural value.

| File / group                                                           | Purpose                                          | Status        | Problem                                                                              | Change                                                        |
| ---------------------------------------------------------------------- | ------------------------------------------------ | ------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------- |
| `LibraryMemberAuthController.cls`                                      | Registration/auth/token endpoints                | MODIFIED      | Auth counters and one-time tokens lacked row locks; blank tokens not rejected early  | Added `FOR UPDATE` and safe blank rejection                   |
| `LibraryMemberSessionService.cls`                                      | Hash-based session issue/resolve/revoke          | GOOD          | Privileged by design; requires strict caller scoping                                 | No change                                                     |
| `LibraryMemberPasswordService.cls`                                     | Password/token hashing and policy                | REVIEW        | Salted SHA-256 is better than plaintext but not an adaptive password KDF             | No risky migration attempted                                  |
| `LibraryMemberSessionController.cls`                                   | Active member portal API                         | GOOD          | Runs system-mode for guest/custom-session design                                     | Verified member derivation and record ownership               |
| `LibraryMemberController.cls`                                          | Salesforce User/Contact compatibility API        | LEGACY        | Duplicates current portal surface                                                    | Retained; already marked deprecated                           |
| `LibraryMemberIdentityService.cls`                                     | Legacy User/Contact mapping                      | COMPATIBILITY | Old architecture dependency                                                          | Retained for legacy consumers                                 |
| `LibraryMemberBorrowService.cls`                                       | Member checkout enforcement                      | GOOD          | System-mode domain service                                                           | Verified caller-resolved member and locks                     |
| `LibraryCatalogService.cls`                                            | Catalog writes/links                             | REVIEW        | Static analyzer CRUD/FLS findings                                                    | No broad behavior-changing rewrite                            |
| `LibraryCirculationService.cls`                                        | Checkout/return/renew/reserve/fines              | REVIEW        | Large system-mode service and analyzer findings                                      | Existing transaction/ownership tests pass                     |
| `LibraryPolicyService.cls`                                             | Permission and policy gates                      | GOOD          | None verified                                                                        | No change                                                     |
| `LibraryReservationWorkflowService.cls`                                | Queue promotion/lifecycle                        | GOOD          | System-mode by design                                                                | Verified tests and row locking                                |
| Inventory, reservation audit, notification, payment, settings services | Domain support                                   | GOOD/REVIEW   | CRUD/FLS findings need disposition by trust boundary                                 | No unsafe mass change                                         |
| Registration controllers/services/queueables                           | Submit, approve, provision, retry                | GOOD          | Async/email live failure paths need UAT                                              | No change                                                     |
| `LibraryLibrarianController.cls`                                       | Internal workspace facade                        | REVIEW        | Very large facade; many CRUD/FLS analyzer findings                                   | Permission tests pass; no structural rewrite                  |
| Agent action/API classes                                               | Agentforce catalog/member/analytics/chat actions | REVIEW        | Live runtime and some CRUD findings remain                                           | Schemas and member-session isolation verified                 |
| `LibraryDataCloudService.cls`                                          | Calculated insights plus real-time fallback      | REVIEW        | Org configuration/freshness cannot be source-verified                                | No change                                                     |
| 17 Apex test classes                                                   | Behavioral/security tests                        | GOOD          | One reference-data test uses `SeeAllData=true`                                       | Retained because it deliberately validates org reference data |
| 7 triggers + sidecars                                                  | Inventory and Contact sharing-key sync           | GOOD          | Minimal trigger bodies; services are bulk-tested                                     | No change                                                     |
| `libraryMemberLogin`                                                   | Custom member login                              | MODIFIED      | Persisted bearer token in `localStorage`                                             | Session-only storage; legacy token removed                    |
| `libraryLogoutState`                                                   | Logout/revocation route                          | MODIFIED      | Did not clear/revoke legacy persistent token                                         | Clears both stores and revokes either token                   |
| `libraryMemberShell`                                                   | Main member portal                               | MODIFIED      | Read persistent legacy token                                                         | Reads session-only token and removes legacy value             |
| Auth/login/logout Jest tests                                           | Browser auth contracts                           | MODIFIED      | Expected insecure persistence; missing legacy cleanup test                           | Corrected assertions and added regression                     |
| `libraryLibrarianWorkspace`                                            | Full internal UI                                 | GOOD/REVIEW   | Large component; browser/accessibility UAT needed                                    | No change                                                     |
| Other 16 LWC bundles and tests                                         | Public/auth/member/librarian presentation        | GOOD          | Navigation warnings are jsdom limitations                                            | No production change                                          |
| 20 object folders / 80 files                                           | Data model, auth/session/audit/payment fields    | GOOD/REVIEW   | Many legacy objects rely on org-origin monolithic object metadata                    | Runtime schema validator passes                               |
| Permission sets, profile, custom permissions                           | Least-privilege access                           | REVIEW        | Assignments and guest effective access are org state                                 | Source inspected; manual verification required                |
| Sharing settings/rules/sets                                            | Internal and compatibility sharing               | REVIEW        | Custom-session access bypasses sharing intentionally and must stay controller-scoped | No change                                                     |
| Digital Experience/network/site metadata (85 files)                    | LWR site routes/views/site                       | GOOD/REVIEW   | Publish state and effective guest access need browser/org evidence                   | No change                                                     |
| Agentforce definitions/versions/bundles/functions (138 files)          | Two agents and local action schemas              | REVIEW        | Many historical versions; runtime activation unknown                                 | Validated all 55 schema pairs                                 |
| Manifests and deployment scripts                                       | Core/Agentforce deployment gates                 | GOOD          | Full check-only deployment not rerun in this audit                                   | XML/schema validator passes                                   |
| Documentation (18 files)                                               | Architecture, operations, UAT, release evidence  | GOOD          | Some prior evidence predates this remediation                                        | Added this final report and analyzer JSON                     |
| Demo/import/UAT scripts and workbook                                   | Seed, validation, operations                     | REVIEW        | Destructive/use-on-nonproduction controls must be observed                           | No change                                                     |
| Project/CI/Jest/ESLint configuration                                   | Tooling and validation                           | GOOD          | Prettier baseline remains noisy                                                      | No mass formatting                                            |

## 5. Changes Implemented

```text
FILE: force-app/main/default/classes/LibraryMemberAuthController.cls
CHANGE: Lock login/activation/reset member rows; reject blank one-time tokens.
REASON: Prevent lost lockout increments and concurrent token replay.
IMPACT: Stronger authentication consistency; public method contracts unchanged.

FILE: force-app/main/default/lwc/libraryMemberLogin/libraryMemberLogin.js
CHANGE: Store bearer token only in sessionStorage and delete legacy localStorage token.
REASON: Persistent bearer credentials survived browser restarts and expanded XSS impact.
IMPACT: Members sign in again after the browser session ends.

FILE: force-app/main/default/lwc/libraryLogoutState/libraryLogoutState.js
CHANGE: Revoke either current or legacy token and clear both stores.
REASON: Dedicated logout previously left a localStorage token behind.
IMPACT: Reliable cleanup for users upgrading from an older release.

FILE: force-app/main/default/lwc/libraryMemberShell/libraryMemberShell.js
CHANGE: Stop accepting persistent tokens and remove legacy tokens on load.
REASON: Enforce session-bound browser credentials.
IMPACT: Old persistent sessions intentionally expire client-side.

FILE: related login/logout Jest tests
CHANGE: Assert session-only storage and legacy cleanup.
REASON: Prevent regression.
IMPACT: Jest total increased from 43 to 44 tests.

FILE: docs/code-analyzer-results.json
CHANGE: Added complete Salesforce Code Analyzer output.
REASON: Preserve reproducible static-analysis evidence.
IMPACT: Makes remaining findings reviewable and triageable.
```

## 6. Security Findings

### CRITICAL

None proven in the reviewed source after remediation.

### HIGH

- **FIXED:** Persistent bearer token in `localStorage` and incomplete logout cleanup.
- **FIXED:** Race window in login failure counting and activation/reset token consumption.
- **REMAINING:** Code Analyzer reports 209 `ApexCRUDViolation` findings. Many are expected system-mode operations behind custom session or custom-permission boundaries, but each must be documented or remediated; the count cannot be dismissed as false positive wholesale.
- **MANUAL CONFIGURATION REQUIRED:** Effective Experience Cloud guest Apex access and CRUD/FLS must be checked in the target org.

### MEDIUM

- **REMAINING:** Password hashing is salted SHA-256, not an adaptive password KDF. Salesforce Apex has no native bcrypt/Argon2; migration needs a deliberately designed external/native alternative and hash-version field.
- **REMAINING:** No browser-level A/B IDOR, session theft/replay, CSP, or open-redirect evidence.
- **REMAINING:** `LibraryLibrarianController` and `libraryLibrarianWorkspace` are large change hotspots.
- **REMAINING:** Numerous system-mode (`without sharing`) services are justified by guest/custom-session or trigger/async execution, but require maintained caller-boundary tests.

### LOW

- **REMAINING:** Jest emits expected jsdom navigation console noise.
- **REMAINING:** Broad formatting debt and complexity/documentation warnings reduce maintainability.

### INFORMATIONAL

- **FIXED/VERIFIED:** Passwords are not stored in plaintext; tokens are random and only digests are persisted.
- **VERIFIED:** Member operations resolve identity from the validated server session; ownership/tampering tests pass.
- **VERIFIED:** Librarian endpoint denial tests pass for an unauthorized internal user.

## 7. Legacy Code

| Legacy file/area                                        | Why legacy                                                                 | Still referenced by                                            | Action                                                               |
| ------------------------------------------------------- | -------------------------------------------------------------------------- | -------------------------------------------------------------- | -------------------------------------------------------------------- |
| `LibraryMemberController`                               | Salesforce User/Contact identity, replaced by custom member session portal | `libraryMemberNotifications`, legacy Experience metadata/tests | Keep as compatibility; migrate final consumer before deletion        |
| `LibraryMemberIdentityService`                          | Resolves User/Contact member mapping                                       | Legacy controller/tests                                        | Keep until compatibility surface is removed                          |
| `Member__c.User__c`, Contact sync triggers/sharing sets | Prior Experience User model and sharing keys                               | Compatibility APIs, reporting/sharing metadata                 | Do not delete without org/reference migration                        |
| Registration User provisioning queueables               | Older external-user provisioning path                                      | Lifecycle metadata/tests may still reference it                | Classify MIGRATION/COMPATIBILITY; retain pending org reference proof |
| Historical Agentforce definition versions               | Deployment/runtime history                                                 | Agent metadata may reference active version                    | Do not delete from source without active-version confirmation        |

No file was deleted merely because a direct Apex/LWC reference was absent.

## 8. Test Results

```text
Apex tests (connected library-org, RunLocalTests):
Passed: 103
Failed: 0
Org-wide coverage: 81%

Targeted check-only deployment after auth change:
Component compile: PASS
LibraryMemberAuthControllerTest: 7 passed, 0 failed
Relevant auth class coverage: 97%

Jest after changes:
Suites: 18 passed, 0 failed
Tests: 44 passed, 0 failed

ESLint: PASS, 0 errors
Schema runtime validator: PASS
Agentforce/deployment schema validator: PASS (55 output/input pairs)

Salesforce Code Analyzer (default Recommended profile, after remediation):
Total: 3,265
Severity 1: 0
Severity 2 / High: 209
Severity 3: 822
Severity 4: 2,231
Severity 5: 3
Primary high category: ApexCRUDViolation (209)
Result: FAILED configured high-severity threshold
```

The Analyzer did not apply the repository ESLint flat config; the normal repository ESLint command passed independently. The first analyzer invocation used an invalid CLI flag after the CLI auto-installed the analyzer plugin; the corrected run completed and its JSON is retained.

## 9. Remaining Manual Salesforce Configuration

1. Publish the intended LWR site version; test every public/private route, 404, expired token, logout, and session-expiry redirect.
2. Inspect the site Guest User profile: grant only required Apex classes; keep Member, session, loan, reservation, fine, and payment object access denied for the custom-session design.
3. Assign `Library_Librarian` and the four custom permissions only to authorized staff; verify Apex class access and field permissions.
4. Verify org-wide defaults, sharing rules/sets, and compatibility Contact keys in the production target.
5. Verify email deliverability, org-wide sender/reply-to behavior, external activation/reset delivery, expiry, and one-time use. Current messages provide a token rather than a repository-defined full URL.
6. Configure/validate Data Cloud CRM streams, DLO/DMO mappings, Individual and Contact Point Email identity, identity resolution, calculated insights, schedules, data graphs, and access. Resolve the previously observed failed/warning streams.
7. Activate the intended Agentforce versions; verify functions/actions, topics, grounding, channel/messaging setup, permissions, member session context, and librarian authorization in live conversations.
8. Schedule reservation expiry and notification jobs; test failure/retry monitoring.
9. Confirm whether membership payments are intentionally offline/simulated. If real payment is required, add an approved gateway via Named Credential and webhook idempotency/reconciliation; none exists in source.
10. Execute backup/export and restore rehearsal, release rollback, monitoring, and alert ownership.

## 10. Production Blockers

- **P0 — must fix before deployment:** None remaining as a proven source vulnerability; any Analyzer CRUD finding that exposes an ungated public mutation becomes P0 during disposition.
- **P1 — should fix before production:** Disposition/remediate all 214 high Analyzer findings; complete real-browser end-to-end UAT and member A/B tampering tests; verify activation/reset email delivery; verify guest/profile/custom-permission effective access; validate live Data Cloud and Agentforce runtime.
- **P1 — should fix before production:** Freeze and commit a reviewed release candidate. The current worktree contains extensive pre-existing modified/untracked implementation and documentation.
- **P2 — recommended:** Migrate remaining legacy `LibraryMemberController` consumers to the session controller, then retire User/Contact compatibility only after metadata/org reference proof.
- **P2 — recommended:** Split the librarian facade/workspace into bounded modules and establish an intentional Code Analyzer configuration/baseline.
- **P2 — recommended:** Design versioned adaptive password hashing if an approved Salesforce-compatible implementation is available.
- **P3 — optional:** Remove jsdom navigation noise, normalize formatting incrementally, and archive inactive Agentforce versions after org confirmation.

**Superseded by the live closure record below.** The core release has been deployed and the listed runtime gates were subsequently exercised. Human inbox confirmation and interactive multi-browser acceptance remain operational acceptance checks, not source/deployment blockers.

## Remediation Addendum — Gap Closure Pass

The following source-fixable gaps were closed after the initial report:

- Removed exception class names and internal exception messages from all three librarian Agentforce action responses (`LibraryAgentCatalogAction`, `LibraryAgentMemberSummaryAction`, and `LibraryAgentAnalyticsAction`). Detailed diagnostics remain server-side only.
- Removed unnecessary direct `@AuraEnabled` exposure from Data Cloud service entry points. Member analytics can no longer be called from a client with an arbitrary `memberId`; member UI access remains routed through `LibraryMemberSessionController`, which derives the member from the validated session.
- Replaced the dynamic SOQL schema probe in `LibrarySchemaValidation` with Describe-based allowlisted field validation, eliminating the analyzer's SOQL-injection finding without reducing schema coverage.
- Added `runtimeSchemaContractIsComplete` to `LibrarySettingsControllerTest`; it asserts every required schema finding is `PASS` instead of merely executing the validator.
- Replaced `SeeAllData=true` in `LibraryAgentCatalogReferenceTest` with isolated test-owned Author, Book, and junction data.
- Replaced three empty test catch blocks with explicit denial assertions.
- Re-ran the full Recommended analyzer profile. High findings fell from 214 to 209; every remaining high finding is `ApexCRUDViolation`. The SOQL-injection, `SeeAllData`, and empty-catch high findings are now zero.
- Targeted check-only deployment of the seven changed Apex classes with `RunLocalTests` succeeded. A narrower `RunSpecifiedTests` validation correctly failed only the deployment coverage gate for `LibrarySchemaValidation` and `LibraryDataCloudService`; using the production-equivalent local-test level passed.
- **RESOLVED:** `scripts/deploy-library.ps1` now validates/deploys the core manifest inside a guarded scheduler maintenance window. It verifies that exactly one expected `Library Member Notification Scheduler` exists with cron `0 15 * * * ?`, unschedules only that job, and restores it in `finally`. Separate idempotency-checked Apex scripts perform the unschedule and restore operations.
- A dependency-complete settings validation (object metadata + controller + validator + test) passed with all three `LibrarySettingsControllerTest` methods, proving that settings Apex must be deployed with its object metadata rather than as an isolated class.

Updated automated evidence:

```text
Jest: 18 suites, 44 tests passed
ESLint: passed
Changed Apex check-only deployment + RunLocalTests: passed
Full core-manifest check-only deployment: passed (391 components, 99 tests, 0 failures)
Focused PMD rules (SOQL injection, empty catch, SeeAllData): 0 findings
Recommended analyzer: 3,265 total; 209 high, all ApexCRUDViolation
```

Scheduler maintenance-window verification:

```text
Original job: 08egK00000jK7i4QAC
Restored job: 08egK00000k9BMtQAM
Cron: 0 15 * * * ?
Timezone: America/Los_Angeles
State after validation: WAITING
Next fire time verified: 2026-10-14T19:15:00Z
```

The first broad source-directory dry run also proved why the deployment script must use `manifest/core-package.xml`: deploying all of `force-app/main/default` mixes historical Agentforce versions into the core transaction. Agentforce remains a separate package and validation path.

### Production deployment record

The core package was deployed successfully to `library-org` after the remediation pass.

```text
Deployment ID: 0AfgK00000WS5YdSAL
Status: Succeeded
Components: 366/366
Component errors: 0
RunLocalTests: 99/99 passed
Test errors: 0
Post-deployment runtime schema validation: PASS
Restored scheduler job: 08egK00000k9BQCQA2
Scheduler state: WAITING
Scheduler cron/timezone: 0 15 * * * ? / America/Los_Angeles
```

This deployment covers `manifest/core-package.xml`. Agentforce remains intentionally separated into `manifest/agentforce-package.xml` and was not represented as deployed by this core release.

The remaining CRUD/FLS findings are not one homogeneous defect. They span three trust models and must be resolved accordingly:

1. Custom-session guest endpoints deliberately run in system mode because the guest profile must not receive direct CRUD/FLS. These require explicit DTO/query allowlists and server-session ownership checks, not guest CRUD grants.
2. Internal librarian endpoints use custom permissions as the operation boundary. Each controller/service path must retain its permission check; user-mode conversion must be tested against the librarian permission set before adoption.
3. Trigger, scheduler, queueable, and inventory/domain services intentionally execute in system context. Their public callers and input constraints require documentation and tests rather than UI-user FLS checks.

The class-by-class disposition is recorded in `CRUD_FLS_BOUNDARY_REVIEW_2026-10-14.md`. No finding was blanket-suppressed.

### Live production gap-closure record

Executed against `library-org` on 2026-10-14 after the core deployment:

- **Guest effective permissions:** corrected the live Library guest profile. All 15 sensitive library objects now have create/read/edit/delete/view-all/modify-all denied. Effective `ObjectPermissions` queries return no grants. Guest Apex access is limited to `LibraryRegistrationGuestController`, `LibraryMemberAuthController`, and `LibraryMemberSessionController`. Profile deployment `0AfgK00000WSR1FSAX` succeeded.
- **Experience Cloud:** the `Library` network and both sites are active. The published LWR site root, `/explore-books`, `/register`, and `/login` return HTTP 200 anonymously with no framework error marker. Private member routes return 404 anonymously, as expected. Full mouse/keyboard/visual checks remain a human browser acceptance activity.
- **A/B member isolation:** live-org regression run `707gK00000z585V` passed 20/20 tests. It includes session expiry/isolation, own-record-only reads and mutations, explicit cross-member denial, invalid-ID mutation denial, and member Agentforce session scoping.
- **Email:** `Messaging.reserveSingleEmailCapacity(1)` succeeded and Salesforce accepted/queued a production verification email to the authenticated user's address. The reusable check is `scripts/apex/verify-email-delivery.apex`. External inbox receipt must be confirmed by the mailbox owner.
- **Data Cloud:** 11 library data streams are live with `DataStreamStatus=ACTIVE`, latest `ImportRunStatus=SUCCESS`, refreshes on 2026-10-14, and no `LastDataChangeStatusErrorCode`. They currently report zero processed rows; ingestion configuration is healthy, but business-data population is not claimed.
- **Agentforce:** live metadata contains both agent families, 18 stored versions, and generated actions. `Library_Member_Agent_v2#1` was changed from Inactive to Active after a successful check-only deployment. Production deployment `0AfgK00000WRdpGSAT` succeeded. Librarian active versions were already present.
- **CRUD/FLS:** all 209 analyzer findings were mapped to their 23 owning classes and dispositioned by trust boundary in `CRUD_FLS_BOUNDARY_REVIEW_2026-10-14.md`. No suppression was added; compensating controls and invalidation conditions are explicit.

Residual operational checks requiring a person or real business data are: inbox receipt/link-click confirmation, visual/accessibility testing across supported browsers, and Data Cloud row/identity/calculated-insight acceptance once source records are populated.
