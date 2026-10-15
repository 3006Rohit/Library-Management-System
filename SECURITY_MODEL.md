# Security Model

## Member controls

- Immutable external UID is unique, case-sensitive, and indexed as an External ID.
- The Salesforce member portal resolves identity through the existing member session and `Member_Session__c` before protected member operations.
- Reads filter by the resolved `Member__c.Id`.
- Profile updates always target the resolved member and ignore submitted Member IDs.
- Loan renewal and reservation cancellation verify target ownership.
- Pending, unverified, rejected, suspended, inactive, missing, or ambiguous identities are denied.
- Browser code contains no Salesforce secret, private key, admin token, or privileged credential.

## Librarian controls

Internal users authenticate through Salesforce. `Library_Librarian` grants object/FLS access plus `Manage_Library_Catalog`, `Manage_Library_Circulation`, `Manage_Library_Fines`, and `Manage_Library_Registrations`. Apex checks the relevant custom permission. Private records are shared to the `Library_Librarians` public group, so authorized users must also have the intended record sharing.

## Integration controls

The removed external portal/API integration is not part of the supported application architecture. No external client application, API integration permission set, or client-credentials user should be provisioned for this Salesforce-only project.

## Web controls

- Helmet CSP/security headers.
- Exact configured CORS origins; no production wildcard.
- JSON request size limit and API rate limiting.
- Bearer tokens in the Authorization header, so cookie CSRF is not the authentication mechanism.
- Output encoding before dynamic HTML insertion.
- Generic upstream error messages; no tokens or secrets in logs.

## Negative guarantees and tests

- A missing integration permission is rejected before UID headers are trusted.
- Member A cannot read Member B loans, reservations, or fines.
- Member A cannot renew Member B's loan or cancel Member B's reservation.
- A browser-supplied Member ID cannot redirect a profile update.
- An unauthorized internal user cannot open librarian server operations.
- Revoked, expired, invalid, missing, and unverified tokens are rejected.

## Operational caveats

External-auth ID fields remain only for historical compatibility with existing registration records and must not be treated as a browser-supplied identity source. The supported member path is authenticated session → `Member__c`.
