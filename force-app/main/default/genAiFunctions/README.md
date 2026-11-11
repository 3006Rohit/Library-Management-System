# `genAiFunctions/` — Agent action registrations

12 **GenAiFunction** definitions. Each folder holds `<Name>.genAiFunction-meta.xml` plus `input/schema.json` and `output/schema.json` describing the JSON the agent sends and receives. The function binds the agent platform to an Apex `@InvocableMethod`.

| Function                              | Apex target                 | Used by                                                       |
| ------------------------------------- | --------------------------- | ------------------------------------------------------------- |
| `LibraryAgentCatalogAction`           | `LibraryAgentCatalogAction` | Public, member                                                |
| `LibraryAgentAnalyticsAction`         | same name                   | Librarian                                                     |
| `LibraryAgentCirculationDetailAction` | same name                   | Librarian (overdue loans, unpaid fines, pending reservations) |
| `LibraryAgentMemberSummaryAction`     | same name                   | Librarian (permission-gated member lookup)                    |
| `LibraryAgentMyActivityAction`        | same name                   | Member                                                        |
| `LibraryAgentMyLoansAction`           | same name                   | Member                                                        |
| `LibraryAgentMyReservationsAction`    | same name                   | Member                                                        |
| `LibraryAgentConfirmationAction`      | same name                   | Member (confirm a prepared transaction)                       |
| `LibraryPublicBranchInfoAction`       | same name                   | Public                                                        |
| `LibraryPublicEventsAction`           | same name                   | Public                                                        |
| `LibraryPublicMembershipPlansAction`  | same name                   | Public                                                        |
| `LibraryPublicPoliciesAction`         | same name                   | Public                                                        |

Other actions (prepare/commit transaction, room actions, time parser) are bound directly in Agent Script via `apex://` targets without a GenAiFunction.

## Rules

- The JSON schemas **must** match the Apex `Request`/`Response` inner classes field-for-field. `scripts/validate-deployment-package.ps1` checks this before each deploy.
- Do not change a schema after the agent was published unless you republish a new bundle.
- Deployed through [`manifest/agentforce-package.xml`](../../../../manifest/README.md), separate from the core package.
