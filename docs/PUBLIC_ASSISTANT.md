# Signed-out public assistant

A chat assistant on the public Library site for visitors who are not signed in.
It is read-only: it shows books, genres, branches, policies, plans, events and
library features, and sends anything member-only to Register / Log in.

## Request flow

```
libraryLandingPage (LWC)
  -> LibraryPublicAgentController   startSession / sendMessage / endSession
       -> LibraryAgentApiController (Agentforce Agent API via Named Credential)
            -> Library_Public_Assistant (Agent Script bundle)
                 -> Apex actions (run as the agent user)
```

## Security model

| Concern           | Control                                                                                                                                                                                                            |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Session hijacking | `startSession` returns a random token; only its SHA-256 hash is stored in `Library_Public_Chat_Session__c`. `sendMessage` / `endSession` require it. Unknown id, wrong token and expiry all return the same error. |
| Cost / abuse      | 30 messages per chat, 60 new chats per hour, 1,500 messages per day (constants at the top of `LibraryPublicAgentController`). Failed callouts still count.                                                         |
| Data exposure     | The controller is `without sharing` only so it can reach the private ledger object. It touches nothing else. Actions return catalog data only and never member data.                                               |
| Member features   | Agent instructions route loans, holds, fines, rooms, etc. to a register / sign-in message. No member action is registered on this agent.                                                                           |

Guests cannot query setup objects, so the published agent's id is in the custom
label `Library_Public_Agent_Id`. Update it if the agent is ever recreated.

## Catalog action (`LibraryAgentCatalogAction`)

The Agentforce runtime only surfaces the **first row** of a multi-row action
result. The public assistant is therefore identified by the custom permission
`Library_Public_Agent` (granted by `Library_Public_Agent_Access`) and gets a
single summary row:

- `LibraryPublicCatalogSummary.forBooks` lists up to 8 books; with 3 or fewer
  matches it returns every detail (author, genre, publisher, year, edition,
  language, ISBN, description).
- `category = '*'` returns every genre with its book count
  (`LibraryPublicCatalogSummary.forGenres`).
- `LibraryCatalogFuzzySearch` finds near-miss titles ("A Quite Season").

Member and librarian agents do not hold the permission and keep the original
one-row-per-book result. The action's input/output schema is unchanged, which
matters: the platform freezes an action's schema after its first publish.

## Operations

- Publish: `sf agent publish authoring-bundle --api-name Library_Public_Assistant`
  then `sf agent activate --api-name Library_Public_Assistant`.
- The Experience site must be republished for LWC changes to go live.
- Tests: `LibraryPublicAgentControllerTest`, `LibraryAgentCatalogSummaryTest`,
  `LibraryAgentCatalogFuzzyTest`, plus the landing-page Jest tests.

## Known limits

- No real paging: broad browsing shows the first 8 matches and asks the visitor
  to narrow by genre, author or title.
- The search returns at most 50 books, so "N matching" never exceeds 50.
- Old rows in `Library_Public_Chat_Session__c` are not purged yet.
