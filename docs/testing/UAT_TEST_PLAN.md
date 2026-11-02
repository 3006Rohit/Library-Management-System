# Library Management System UAT

## Environment

- Salesforce org: `library-org` (use a sandbox or scratch org for destructive scenarios)
- Local prerequisites: Salesforce CLI, Node.js, and the installed dependencies
- Test data: use the existing `scripts/apex/prepare-5-auth-uat-members.apex` and the library workbook import only in a dedicated UAT org
- Automated runner: `./scripts/run-uat.ps1 -TargetOrg library-org`

The runner validates LWC behavior, lint, Agentforce schemas/manifests, Apex tests, and runtime schema compatibility. It does not claim browser or external-service acceptance.

## UAT scenarios

### Member portal

1. Open the Experience Cloud site and verify catalog load, search, category/author filtering, and empty results.
2. Register a new member with valid and invalid data; verify duplicate and unsafe input handling.
3. Verify activation email delivery, link expiry, single-use behavior, login, logout, lockout, password reset, and password change.
4. Verify a member can see and update only their own profile, loans, reservations, fines, notifications, and payments.
5. Borrow, return, renew, reserve, cancel, and verify queue promotion, inventory counts, due dates, and fine creation.
6. In two browsers, repeat direct-request and URL/ID tampering tests with Member A and Member B.

### Librarian workspace

1. Verify dashboard metrics, catalog management, member lookup, circulation, reservations, fines, payments, notifications, and settings.
2. Verify invalid transitions, unauthorized users, duplicate actions, defective-copy replacement, and bulk operations.
3. Verify the assistant opens only for the librarian and displays a safe error if the live runtime is unavailable.

### Data Cloud

1. Confirm all configured streams have a successful recent run.
2. Confirm source-to-data-model mappings, refresh timestamps, calculated insights, and safe behavior when a stream or insight is unavailable.
3. Compare a sample of member, loan, reservation, fine, and catalog totals between Salesforce and Data Cloud.

### Agentforce

1. Test librarian catalog search, member summary, analytics, and circulation-information prompts.
2. Test member activity, loans, reservations, and catalog prompts with valid and invalid sessions.
3. Confirm unsupported write requests are refused and sensitive fields, session objects, password data, and tokens are never disclosed.
4. Record runtime errors separately from Apex action-test results; passing Apex tests does not prove Agentforce runtime compatibility.

## Exit criteria

- Automated runner passes.
- All critical browser, email, authorization/isolation, Data Cloud, and Agentforce scenarios have evidence.
- No open critical or high defects, or each has an approved release decision.
- Product owner, librarian representative, and security owner sign off.
