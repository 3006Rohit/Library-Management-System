# Integration & authentication metadata

Folders covered by this README: `namedCredentials/`, `externalCredentials/`, `externalClientApps/`, `extlClntAppOauthPolicies/`, `extlClntAppOauthSettings/`.

## Outbound callouts

| Metadata                                                | Endpoint                                                                                                         | Used by                                                              | Notes                                                                                                          |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `Library_Metadata` (Named Credential)                   | `https://openlibrary.org`                                                                                        | `LibraryMetadataService` (ISBN lookup)                               | Public API, no auth. Failures never change the catalog.                                                        |
| `Library_Agent_API` (Named Credential, SecuredEndpoint) | `https://api.salesforce.com`                                                                                     | `LibraryAgentApiController` (Agentforce Agent API sessions/messages) | Authenticates through External Credential `Library_Agent_API`.                                                 |
| `Library_Agent_API` (External Credential)               | OAuth 2.0 **client credentials** (`ClientCredentialsClientSecretBasic`), named principal `LibraryAgentPrincipal` | Named Credential above                                               | The **client id/secret are not in source**; an admin enters them in Setup → External Credentials → Principals. |

## External Client App

| File                                                                            | Meaning                                                                            |
| ------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `externalClientApps/Library_Agent_API.eca-meta.xml`                             | Org-scoped External Client App "Library Agent API" (local distribution).           |
| `extlClntAppOauthSettings/Library_Agent_API_oauth…` + `…Library_Member_Portal…` | OAuth settings (scopes, callback) for the Agent API app and the member portal app. |
| `extlClntAppOauthPolicies/…oauthPlcy…`                                          | OAuth policies (IP relaxation, run-as user, token behaviour).                      |

## Rules

- Never commit client secrets, refresh tokens, or consumer secrets. If any credential was ever exposed, rotate it in Setup.
- Webhook secret for payments is not here — it is in `Payment_Gateway_Config__mdt.Webhook_Secret__c` ([customMetadata](../customMetadata/README.md)).
- The Agent API token URL is org-specific; update the External Credential when deploying to another org.
