# Library Management System Operations

## Deployment gate

Run the validation workflow and a Salesforce check-only deployment before production deployment. Do not cancel scheduled jobs to force a deployment. If Salesforce reports pending Apex jobs, wait for completion or have an administrator enable the org's deployment setting for Apex jobs after confirming the affected schedules are safe.

The removed external portal artifacts have been removed from source. If the Salesforce org still contains an external client application or integration user from an earlier deployment, inventory it in Setup before decommissioning it; do not remove an org credential until ownership and usage are confirmed.

## Member identity requirements

The supported member path is the existing Salesforce member session → `Member_Session__c` → `Member__c`. External authentication IDs are retained only for historical data compatibility and are not a supported browser identity mechanism.

## Async operations

Monitor `AsyncApexJob`, scheduled Apex, registration provisioning failures, and notification email failures. Retry only idempotent operations. Do not retry a registration or circulation mutation without checking its current record state first.

## UAT authentication preparation

Use `scripts/apex/prepare-5-auth-uat-members.apex` only in an isolated UAT execution window. Set a one-time password in the execution window, run it, and clear the editor immediately. The password is intentionally not stored in the repository.

## Incident response

1. Capture the Salesforce request ID and affected record ID.
2. Inspect `AsyncApexJob` and reservation audit records where relevant.
3. For provisioning failures, resolve the stated license/configuration issue before retrying.
4. For identity failures, revoke affected member sessions and review the member record.
5. For data corruption concerns, stop the relevant scheduler and preserve audit records before remediation.

## Backup and recovery

Schedule regular Salesforce data exports including Member, Registration, Borrow Record, Reservation, Reservation Audit, Fine, and Notification records. Test restoration into a non-production org at least quarterly and document the recovery point and recovery time achieved.
