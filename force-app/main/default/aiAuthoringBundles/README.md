# `aiAuthoringBundles/` — Agentforce agents (Agent Script)

Each sub-folder is an **AiAuthoringBundle**: `<Name>.agent` (the Agent Script source) + `<Name>.bundle-meta.xml`. Agent Script defines variables, a start router, sub-agents (topics), their reasoning instructions, and `actions` whose `target: "apex://ClassName"` points at an Apex `@InvocableMethod`.

| Bundle                                 | Audience                                                     | Start node                | Sub-agents (topics)                                                                                                                         | Apex targets                                                                                                                                                                |
| -------------------------------------- | ------------------------------------------------------------ | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Library_Public_Assistant`             | Signed-out visitors                                          | `agent_router`            | `library_info`, `membership`, `events`, `book_search`, `library_features`, `account_redirect`                                               | `LibraryPublicBranchInfoAction`, `LibraryPublicPoliciesAction`, `LibraryPublicMembershipPlansAction`, `LibraryPublicEventsAction`, `LibraryAgentCatalogAction`              |
| `Library_Member_Assistant`             | Authenticated members                                        | `agent_router`            | `Catalog_Discovery`, `My_Loans`, `My_Reservations`, `My_Library_Activity`, `Member_Transactions`                                            | `LibraryAgentCatalogAction`, `LibraryAgentMyActivityAction`, `LibraryAgentMyLoansAction`, `LibraryAgentMyReservationsAction`, `LibraryAgentConfirmationAction`              |
| `LibraryMemberAgent`                   | Members (server-validated session token variable)            | `agent_router`            | `my_library_activity`, `my_loans`, `my_reservations`, `catalog_discovery`, `room_busy_times`, `general_conversation`, `member_transactions` | member read actions + `LibraryAgentPrepareTransactionAction`, `LibraryAgentCommitTransactionAction`, `LibraryAgentRoomAvailabilityAction`, `LibraryAgentRoomForecastAction` |
| `Library_Member_Agentforce`            | Members (earlier generation)                                 | `member_router`           | `catalog_search`, `member_activity`, `view_loans`, `view_reservations`                                                                      | catalog + three member read actions                                                                                                                                         |
| `Library_Librarian_Assistant_V2`       | Librarians                                                   | `agent_router`            | `Library_Analytics`, `Catalog_Search`, `Member_Lookup`, `Circulation_Information`, `Room_Insights`, `General_Conversation`                  | `LibraryAgentAnalyticsAction`, `…CatalogAction`, `…MemberSummaryAction`, `…CirculationDetailAction`, `…RoomAvailabilityAction`, `…RoomInsightsAction`                       |
| `Library_Librarian_Agentforce_Refresh` | Librarians (refresh bundle used to republish action schemas) | `circulation_information` | `library_analytics`, `catalog_search`, `member_lookup`, `circulation_information`                                                           | `LibraryAgentAnalyticsAction`, `…CatalogAction`, `…MemberSummaryAction`                                                                                                     |

Common sub-agents in every bundle: `escalation`, `off_topic`, `ambiguous_question`.

## Safety model

- Agents are **read-only**; mutations are only through the prepare → confirm → commit actions, with hashed single-use tokens bound to member + action + target (`Agent_Confirmation__c`, `LibraryAgentConfirmationService`).
- The member session token is injected by the portal through Agent API variables (`LibraryMemberAgentController`). The agent is told never to show or repeat it.
- The public agent has the custom permission `Library_Public_Agent` (granted by permission set `Library_Public_Agent_Access`) and sees summary rows only. Rate limits live in `LibraryPublicAgentController`.

## Operations

```powershell
sf agent validate authoring-bundle --api-name Library_Public_Assistant --target-org library-org
sf agent publish  authoring-bundle --api-name Library_Public_Assistant --target-org library-org
sf agent activate --api-name Library_Public_Assistant --target-org library-org
sf agent preview start --api-name Library_Public_Assistant --target-org library-org
```

- The Agentforce platform **freezes an action's input/output schema after its first publish**; change Apex return shapes carefully or publish a refresh bundle.
- Agent IDs are org-specific: the librarian ID is in `LibraryAgentApiController`, the public ID in custom label `Library_Public_Agent_Id`.
- Details: [docs/AGENTFORCE_IMPLEMENTATION.md](../../../../docs/AGENTFORCE_IMPLEMENTATION.md), [docs/PUBLIC_ASSISTANT.md](../../../../docs/PUBLIC_ASSISTANT.md).
- Validate schemas offline: `./scripts/validate-deployment-package.ps1`.
