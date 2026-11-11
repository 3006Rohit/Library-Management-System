# Test & Improvement Report: 2026-11-10

Org tested: `library-org` (deployed code). Local branch: `fix/agent-schemas-and-stale-tests`.

## 1. Results summary

| Area                              | Result             | Detail                                                                                                                 |
| --------------------------------- | ------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| Frontend unit (LWC Jest)          | PASS               | 27 suites, 84 passed, 3 skipped, 0 failed                                                                              |
| Frontend lint (ESLint)            | PASS with warnings | 0 errors, 3 warnings: skipped tests in `libraryLibrarianWorkspace.test.js` (lines 411, 460, 499)                       |
| Backend (Apex, RunLocalTests)     | **2 FAIL**         | 260 ran, 258 passed (99%), org-wide coverage 79%                                                                       |
| Public site, signed out (browser) | PASS               | Home, catalog teaser, plans, public assistant answered "Which books are available?" with live data. No console errors. |
| Member side (browser)             | NOT TESTED         | Needs a login. I do not enter passwords. Routes `/login`, `/register`, `/member` return 200.                           |
| Librarian side (browser)          | NOT TESTED         | Needs a login. Workspace is covered only by Jest and Apex.                                                             |
| Agents (compile)                  | 5 of 6 PASS        | `Library_Member_Assistant` fails to compile.                                                                           |
| Agents (behaviour)                | NOT TESTED         | No `AiEvaluationDefinition` tests exist in the org or repo.                                                            |

## 2. Issues found (highest priority first)

### High

1. **Local source is not deployed.** About 60 changed or untracked files, including the librarian commit and prepare actions, the acquisition dashboard and the V2 agent. The org tests above ran against the old deployed code. Deploy them, or validate them first, then re-run everything. A check-only deploy with `RunLocalTests` was not run (blocked by a hook), so the local code is untested.
2. **Two Apex tests fail** (`LibraryAgentCatalogSummaryTest.genreListShowsGenresWithCounts` and `.singleBookSearchReturnsFullDetails`). The error is `MIXED_DML_OPERATION`: the helper `publicAgentUser()` (line 50) inserts a `PermissionSetAssignment` after `Book__c` has been inserted. Fix: create the user and assignment in `@TestSetup`, or insert them inside `System.runAs` before the book data.
3. **`Library_Member_Assistant` does not compile.** Error: `'default_agent_user' is required for AgentforceServiceAgent type agents` (line 9). Add the field, or delete the bundle if it is superseded.
4. **`LibraryAgentConfirmationAction` has 0% coverage.** It is the confirm step for agent writes, so it is the most sensitive code that is untested.

### Medium

5. **Low coverage on critical controllers:** `LibraryMemberSessionController` 55%, `LibraryLibrarianController` 57%, `LibraryPaymentWebhookRest` 69%, `LibraryMetadataService` 70%, `LibraryScanService` 71%, `LibraryDataCloudService` 72%, `LibraryNotificationDeliveryRetryService` 73%, `LibraryPolicyService` 73%. Aim for 85% or more on auth, payment and librarian paths.
6. **No agent behaviour tests.** Add `sf agent test` specs for the public, member and librarian agents. Cover refusal of member-only actions when signed out, the confirm-before-write flow, and Data Cloud failure fallback.
7. **Three skipped Jest tests** in `libraryLibrarianWorkspace` (the main staff screen). Fix and enable them.
8. **Six agent bundles, with overlapping names.** `LibraryMemberAgent`, `Library_Member_Agentforce`, `Library_Member_Assistant`, `Library_Librarian_Agentforce_Refresh` and `Library_Librarian_Assistant_V2` look duplicated. Keep one per role and remove the rest to avoid publishing the wrong one.
9. **Jest noise.** `libraryLogoutState` calls `window.location.replace`, which prints "Not implemented: navigation" errors in tests. Mock `location` in the test.

### Low (UX / content)

10. Plan cards read "Up to 1 reservations" and "1 renewals per loan". Add singular and plural handling.
11. The Monthly/Annually toggle shows only `/year` prices. Hide the toggle or add monthly prices.
12. `/library/books`, `/library/plans` and `/library/check-email` return 404 when opened directly, even though the nav links to "Books" and "Plans". They probably work as in-page anchors. Make deep links work, and show a branded 404 page.
13. `libraryContact.html` has an invalid `value` attribute on `<textarea>` (LWC1057 warning).
14. The home page counts "170 books" while the assistant reports "50 matching" available. That is correct, but label the stats clearly (titles vs. copies).

## 3. Not covered: needs you

- **Member and librarian browser tests.** Log in yourself in the browser pane, or give me test-account steps from your seed script, and I will run the checks in `docs/testing/TESTING_CHECKLIST.md` (the unticked items: password reset, lockout, renew, return, fine payment, librarian analytics, scan, damage).
- **Payment gateway and email relay.** Both are unchecked in the existing checklist.
- **Accessibility and performance.** Run the tools in `docs/testing/WEBSITE_TESTING_TOOLS.md` (WAVE, PageSpeed).

## 4. Suggested next steps

1. Fix issues 2 and 3, deploy local source, then re-run Apex and Jest.
2. Add tests for issues 4 to 6.
3. Do the member and librarian browser pass.
4. Clean up the agent bundles.
