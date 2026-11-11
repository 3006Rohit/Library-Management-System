# Agentforce assistants

Three experiences share the same Apex action layer.

| Assistant               | Where it appears                         | Bundle                                              | Apex entry                     |
| ----------------------- | ---------------------------------------- | --------------------------------------------------- | ------------------------------ |
| **Public** (signed out) | Landing page chat (`libraryLandingPage`) | `Library_Public_Assistant`                          | `LibraryPublicAgentController` |
| **Member** (signed in)  | Portal chat (`libraryMemberAssistant`)   | `Library_Member_Assistant`, `LibraryMemberAgent`    | `LibraryMemberAgentController` |
| **Librarian**           | Workspace assistant                      | `Library_Librarian_Assistant_V2` (+ refresh bundle) | `LibraryAgentApiController`    |

All three call the Agentforce **Agent API** through Named Credential `Library_Agent_API` (OAuth client-credentials External Credential) — see [integration README](../../../force-app/main/default/namedCredentials/README.md).

## Request flow

```
LWC → *AgentController.startSession / sendMessage / endSession
    → LibraryAgentApiController (HTTP to api.salesforce.com; passes variables such as the session token)
    → Agent Script bundle → topic → apex:// action (runs as the agent user)
```

## Public assistant security

- `startSession` returns a random token; only its SHA-256 is stored in `Library_Public_Chat_Session__c`; `sendMessage`/`endSession` require it; unknown id, wrong token and expiry return the same error.
- Limits: 30 messages per chat, 60 new chats per hour, 1,500 messages per day (constants at top of `LibraryPublicAgentController`); failed callouts still count.
- Agent id is read from custom label `Library_Public_Agent_Id`.
- Catalog action returns **one summary row** (the runtime only surfaces the first row of a multi-row result) when the running user has custom permission `Library_Public_Agent`: up to 8 books, full detail when ≤3 matches, `category='*'` lists genres with counts; fuzzy title search for typos.
- Known limits: no real paging (narrow by genre/author/title); search returns ≤50; old chat session rows not purged.

## Member assistant & confirmed transactions

Read actions: activity, loans, reservations, catalog, rooms. Writes use **prepare → confirm → commit**:

1. `LibraryAgentPrepareTransactionAction` / `LibraryAgentConfirmationService.preview` builds an exact preview (renewal, reservation cancellation, borrow/reservation, room booking) and a short-lived single-use token (hash in `Agent_Confirmation__c`, bound to member + action + target + parameter hash).
2. Member says yes → `LibraryAgentConfirmationAction` / `confirm`.
3. `LibraryAgentCommitTransactionAction` / `commitConfirmed` re-validates session, ownership, policy, expiry, idempotency, then calls the normal circulation service. Replayed, altered, expired or cross-member tokens fail.
   The agent never asks for or shows tokens/IDs; the portal supplies the validated session token as an agent variable. `LibraryAgentTimeParser` converts phrases like "tomorrow at 3pm" for room actions.

## Librarian assistant

Read-only: analytics, catalog, member summary (requires `Manage_Library_Circulation`; display-safe fields), circulation detail (overdue, unpaid fines, pending reservations), room insights.

## Publishing & testing

```powershell
./scripts/validate-deployment-package.ps1          # schemas must match Apex Request/Response
sf project deploy start --manifest manifest/agentforce-package.xml --target-org library-org
sf agent publish authoring-bundle --api-name <Bundle> --target-org library-org
sf agent activate --api-name <Bundle> --target-org library-org
sf agent preview start --api-name <Bundle> --use-live-actions   # live actions prove Apex runs
```

Schemas freeze after first publish. Details: [AGENTFORCE_IMPLEMENTATION](../../AGENTFORCE_IMPLEMENTATION.md), [PUBLIC_ASSISTANT](../../PUBLIC_ASSISTANT.md).

## Tests

`LibraryAgentActionsTest`, `LibraryPublicActionsTest`, `LibraryAgentApiControllerTest`, `LibraryAgentConfirmationServiceTest`, `LibraryAgentTransactionsTest`, `LibraryAgentTransactionsAgentUserTest`, `LibraryAgentCatalog*Test`, `LibraryPublicAgentControllerTest`, `LibraryAgentPublishTest`.
