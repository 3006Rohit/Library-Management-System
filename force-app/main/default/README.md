# `force-app/main/default` — Salesforce metadata

This is the single package directory declared in `sfdx-project.json` (source API 68.0). Everything that is deployed to the org lives here, in Salesforce DX _source format_.

## Folder index

| Folder                                                                                                                       | Metadata type                 | Purpose                                                              | Details                                                         |
| ---------------------------------------------------------------------------------------------------------------------------- | ----------------------------- | -------------------------------------------------------------------- | --------------------------------------------------------------- |
| `classes/`                                                                                                                   | ApexClass                     | Business logic, controllers, agent actions, async jobs, tests        | [README](classes/README.md)                                     |
| `triggers/`                                                                                                                  | ApexTrigger                   | Inventory totals + Contact sharing mirrors                           | [README](triggers/README.md)                                    |
| `lwc/`                                                                                                                       | LightningComponentBundle      | All UI (public site, member portal, librarian workspace)             | [README](lwc/README.md)                                         |
| `objects/`                                                                                                                   | CustomObject / CustomMetadata | Data model                                                           | [README](objects/README.md)                                     |
| `digitalExperiences/`                                                                                                        | DigitalExperienceBundle       | LWR Experience Cloud site `Library1`                                 | [README](digitalExperiences/README.md)                          |
| `aiAuthoringBundles/`                                                                                                        | AiAuthoringBundle             | Agent Script definitions of 6 agents                                 | [README](aiAuthoringBundles/README.md)                          |
| `genAiFunctions/`                                                                                                            | GenAiFunction                 | 12 Apex actions exposed to agents                                    | [README](genAiFunctions/README.md)                              |
| `genAiPlugins/`                                                                                                              | GenAiPlugin                   | 8 generated agent topics (legacy planner)                            | [README](genAiPlugins/README.md)                                |
| `genAiPromptTemplates/`                                                                                                      | GenAiPromptTemplate           | Acquisition advisor prompt                                           | [README](genAiPromptTemplates/README.md)                        |
| `permissionsets/`                                                                                                            | PermissionSet                 | 10 permission sets                                                   | [README](permissionsets/README.md)                              |
| `customPermissions/`                                                                                                         | CustomPermission              | 5 feature gates                                                      | [README](customPermissions/README.md)                           |
| `sharingRules/`, `sharingSets/`                                                                                              | SharingRules / SharingSet     | Record access                                                        | [rules](sharingRules/README.md) · [sets](sharingSets/README.md) |
| `profiles/`, `roles/`, `groups/`                                                                                             | Profile / Role / Group        | `Library Profile`, `Library_Operations`, `Library_Librarians`        | see permissionsets README                                       |
| `namedCredentials/`, `externalClientApps/`, `extlClntAppOauthPolicies/`, `extlClntAppOauthSettings/`, `externalCredentials/` | Integration                   | Callouts and Agent API OAuth                                         | [README](namedCredentials/README.md)                            |
| `customMetadata/`                                                                                                            | CustomMetadata records        | Default experience + payment gateway config                          | [README](customMetadata/README.md)                              |
| `labels/`                                                                                                                    | CustomLabels                  | `Library_Public_Agent_Id`                                            | [README](labels/README.md)                                      |
| `settings/`                                                                                                                  | Settings                      | Apex, email administration, sharing org settings                     | see ui-shell README                                             |
| `staticresources/`                                                                                                           | StaticResource                | `LibraryAuthHero` hero image                                         | see ui-shell README                                             |
| `applications/`, `tabs/`, `flexipages/`, `networks/`, `sites/`                                                               | UI shell                      | Lightning app, tabs, record page, community network, Salesforce site | [README](applications/README.md)                                |

Empty/placeholder folders (`aura/`, `contentassets/`, `layouts/`, `extlClntAppGlobalOauthSets/`, `extlClntAppPolicies/`) currently contain no source files.

## How the layers connect

```
Experience site (digitalExperiences) ──► LWC (lwc/*) ──► Apex controller (classes/*Controller)
                                                           └─► Apex service (classes/*Service) ──► objects/*
Agent (aiAuthoringBundles) ──► GenAiFunction ──► Apex @InvocableMethod (classes/LibraryAgent*Action, LibraryPublic*Action)
Triggers ──► LibraryBookInventoryService / LibraryTransactionContactService
Schedulers / Batch / Queueables ──► services (reservation expiry, notifications, registration provisioning)
```

## Conventions

- **Naming:** everything is prefixed `Library…`; custom objects use `__c`. LWC folders are camelCase (`libraryMemberShell`).
- **Tests:** Apex tests sit next to the class (`FooTest.cls`); LWC tests in `lwc/<cmp>/__tests__`.
- **Sharing:** controllers are `with sharing`; services that must see private ledger rows are `without sharing` and enforce scope manually.
- **READMEs** inside this tree are excluded from deployment by `.forceignore` (`**/README.md`).
