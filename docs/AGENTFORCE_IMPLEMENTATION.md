# Agentforce implementation

## Deployed agents

| Agent | API name | Agent ID | Version | Purpose |
| --- | --- | --- | --- | --- |
| Library Member Assistant v3 | `Library_Member_Assistant_V3` | `0XxgK000002QwQb` | 1 (activated) | Public catalog discovery and the authenticated member's own read-only activity, loans, and reservations |
| Library Librarian Assistant v2 | `Library_Librarian_Assistant_V2` | `0XxgK000002QwOz` | 1 (activated) | Read-only catalog, circulation analytics, and authorized member summaries |

The librarian workspace uses the activated agent ID `0XxgK000002QwOz`. Agent IDs are org-specific; update `LibraryAgentApiController` whenever a different org's activated agent is used.

## Registered actions

The six Apex actions are registered as `GenAiFunction` metadata and deployed with `manifest/agentforce-package.xml`:

- `LibraryAgentCatalogAction` — bounded public catalog search.
- `LibraryAgentAnalyticsAction` — aggregate circulation and demand analytics.
- `LibraryAgentMemberSummaryAction` — permission-gated, privacy-safe member summary.
- `LibraryAgentMyActivityAction` — authenticated member activity.
- `LibraryAgentMyLoansAction` — authenticated member loans.
- `LibraryAgentMyReservationsAction` — authenticated member reservations.

The generated `GenAiPlugin` topics are source-controlled under `force-app/main/default/genAiPlugins`. They are read-only and include the platform knowledge action added by Agentforce during agent creation.

The source-controlled refresh bundle at `force-app/main/default/aiAuthoringBundles/Library_Librarian_Agentforce_Refresh` explicitly binds the librarian topics to the Apex targets. `sf agent validate authoring-bundle --api-name Library_Librarian_Agentforce_Refresh --target-org library-org` passes. Publishing it is the supported way to create a new agent version after an action-schema refresh:

```powershell
sf agent publish authoring-bundle --api-name Library_Librarian_Agentforce_Refresh --target-org library-org
```

The target org's Agentforce authoring endpoint returned connection timeouts during the current run, so the bundle remains validated and ready to publish when that service is reachable.

## Security boundaries

- Member actions must receive a server-validated member session context. A member must never be asked to type a session token, Member ID, Contact ID, User ID, or another identity override.
- Librarian member lookup is protected by the `Manage_Library_Circulation` permission and returns only display-safe fields.
- Catalog and analytics actions are bounded to their documented inputs and do not expose security, authentication, or token data.
- No Agentforce action performs a circulation, reservation, payment, or profile write. Existing confirmation-gated transaction services remain separate and require explicit application-side confirmation.

## Verification and operations

1. Deploy action metadata and Apex implementations.
2. Create or update agents from `docs/agent-spec-member.yaml` and `docs/agent-spec-librarian.yaml`.
3. Activate the intended agent version with `sf agent activate`.
4. Preview the published librarian agent with `sf agent preview start --api-name Library_Librarian_Assistant` and `sf agent preview send`.
5. Use `--use-live-actions` only when validating deployed Apex; simulated previews do not prove action execution.
6. Keep the member agent inactive in channels that do not provide a verified member context. The current member action signatures still require a server session token, so public unauthenticated deployment is unsafe.

## Current limitation

The librarian Agentforce definition, action registrations, permissions, and workspace endpoint are deployed. In this org's CLI preview, the planner still falls back to the platform knowledge action because the Agentforce runtime reports the custom action schema as unavailable. The validated refresh bundle is ready, but publishing is currently blocked by a transient Agentforce authoring-service connection timeout; after publishing, activate the new version and rerun the live preview. The member agent definition and actions are activated, but a production member channel still needs a trusted context-variable bridge that binds the authenticated portal session to the action's required session token. Do not expose the member agent to an anonymous channel or collect the token through chat.
