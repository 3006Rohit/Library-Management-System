# Security hardening — 2026-10-15

This branch hardens the Salesforce library source without changing the custom-session authentication model.

## Changes

- Test fixtures no longer use hard-coded Salesforce record IDs.
- LibraryPolicyService and LibraryRegistrationService no longer bypass authorization because a test is running.
- Tests use explicit @TestVisible authorization overrides. Production execution always uses FeatureManagement.checkPermission.
- Added LibrarySecurityService as the shared CRUD/FLS boundary.
- Permission gates now verify object read/create/update access before entering library services.
- Member profile FLS checks delegate to the shared security service.
- Registration code, tests, LWCs, permission metadata, and documentation now use the canonical fields:
  - Normalized_Email__c
  - Provisioning_Status__c
  - Provisioning_Error__c
  - Provisioned_User__c
- Duplicate legacy field definitions were removed from the source metadata.

## Deployment note

Removing a field definition from Salesforce DX source does not delete an already-deployed custom field. The legacy fields must remain unused and should be deleted only through an explicitly reviewed destructive deployment after confirming that no org automation, reports, integrations, or retained data depend on them.

## Verification

Before merging, run:

- npm test
- npm run lint
- npm run prettier:verify
- Salesforce deployment validation against the configured validation org
- Apex tests covering authorization-denied paths and the registration lifecycle
