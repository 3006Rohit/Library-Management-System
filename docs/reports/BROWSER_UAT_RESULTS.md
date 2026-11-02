# Browser UAT Results

Date: 2026-10-14

Environment: deployed Experience Cloud site at `https://orgfarm-8a11434b25-dev-ed.develop.my.site.com/library`

## Passed in browser

| Area                                   | Result                  | Evidence                                                                                                                                                                                              |
| -------------------------------------- | ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Login page                             | Pass                    | Page renders email/password fields and navigation actions                                                                                                                                             |
| Invalid login                          | Pass                    | `invalid@example.test` returns `Invalid email or password.` without exposing internals                                                                                                                |
| Registration page                      | Pass                    | Form, membership-plan selector, date field, and required fields render                                                                                                                                |
| Registration validation                | Pass                    | Empty submission marks First Name invalid and shows `Complete this field.`                                                                                                                            |
| Public catalog                         | Pass                    | 40 books load, availability labels render, unavailable copies are shown                                                                                                                               |
| Catalog search                         | Pass                    | `Clean Code` returns exactly 1 book                                                                                                                                                                   |
| Forgot password                        | Pass                    | Unknown email returns generic reset confirmation                                                                                                                                                      |
| Mobile layout                          | Pass                    | Catalog rendered at 375x812 with responsive navigation and controls                                                                                                                                   |
| Site routing                           | Pass                    | `/library/` redirects to the login/registration experience; legacy site path redirects to login                                                                                                       |
| Member login with supplied UAT account | Login pass; portal fail | Credentials authenticated and redirected to `/library/member`, but the portal displayed `No access to entity`; the failing runtime request returned HTTP 400 while other portal requests returned 200 |
| Logout                                 | Pass                    | `/library/logout` rendered the `Logged Out` page and the session was cleared from the browser                                                                                                         |

## Not completed in this browser session

- Authenticated member portal workflows after resolving the `No access to entity` authorization/runtime error
- Two-member browser/session isolation and request-tampering checks
- Librarian workspace and librarian Agentforce assistant
- Authenticated member Agentforce assistant
- Activation/reset email delivery and link expiry/single-use behavior
- Payment gateway and external inbox verification

These require temporary UAT credentials for one librarian and two separate member accounts, plus access to the recipient mailbox. No credentials were created or exposed during this run.
