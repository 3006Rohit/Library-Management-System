# Privacy, accessibility & fine appeals

## Privacy Center — `LibraryPrivacyService`

| Request                                                                                                                                                                                                                                   | Behaviour                                                                                                                                                                                                                                                                                   |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Export** (`requestExport`)                                                                                                                                                                                                              | Needs the member's **current password**. Produces an allow-listed JSON `ContentVersion` with profile, circulation, financial, engagement, event, room and notification data. Excludes password hashes, session/confirmation tokens, risk signals, staff notes. File expires after **24 h**. |
| **Correction** (`requestCorrection`)                                                                                                                                                                                                      | Waits for librarian approval.                                                                                                                                                                                                                                                               |
| **Deletion** (`requestDeletion`)                                                                                                                                                                                                          | On approval: anonymises identity fields, **revokes all sessions**, records why loans/fines/payments/audit/safety records are retained.                                                                                                                                                      |
| Members `getMine` / `cancel` own; librarians `getAll` / `decide` (UI `libraryLibrarianPrivacyReview`, permission `Manage_Library_Registrations`). Member UI: `libraryMemberPrivacyCenter`. All requests are member-scoped and idempotent. |

## Accessibility — `LibraryAccessibilityService`

Fields on `Member__c`: `Preferred_Language__c`, `Timezone__c`, `High_Contrast__c`, `Large_Text__c`, `Reduced_Motion__c`, `Screen_Reader__c`. `get(sessionToken)` / `save(...)` validate supported values. `libraryMemberAccessibility` and `libraryMemberShell` apply CSS classes immediately; timezone is used for scheduling/notification context. Keyboard-friendly controls; sensitive flows are unchanged by presentation settings.

## Fine appeals — `LibraryFineAppealService`

`submit(sessionToken, fineId, reason)` — one appeal per unpaid fine, reason ≥ 10 characters; `getMine`; librarian `getAll` / `decide(appealId, 'Approved'|'Rejected', reason)`. Approval does **not** silently waive the fine; the librarian then uses the normal waive action. Reviewer reasoning is stored separately from the original fine.

## Audit

Privacy decisions and appeals decisions are recorded through `LibraryOperationAuditService` (see [librarian-workspace](../librarian-workspace/README.md)).

## Tests

`LibraryPrivacyServiceTest`, `LibraryAccessibilityServiceTest`, `LibraryFineAppealServiceTest`.
