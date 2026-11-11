# Library Management System (Salesforce)

A complete library platform built natively on Salesforce: a public website with an AI assistant, a self-service **member portal** (Experience Cloud, LWR), a **librarian workspace** (Lightning), **Agentforce** agents, and a hardened Apex service layer.

> This file is the entry point. Every folder has its own `README.md` that goes deeper. Start here, then follow the links.

---

## 1. What the system does

| Audience                  | Capability                                                                                                                                                                                                                                                                                                  |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Visitors (signed out)** | Browse the landing page, search the public catalog, read branch/plan info, register with optional payment, chat with the read-only **Public Assistant**.                                                                                                                                                    |
| **Members (signed in)**   | Search/borrow/reserve/renew, see fines & payments, scan-and-borrow, digital member card, reading lists, author follows, reviews, events, study-room booking, reading challenges, notifications, accessibility preferences, privacy center, AI assistant with confirmation-gated transactions.               |
| **Librarians (internal)** | Dashboard & analytics, catalog/copy management, circulation, reservations, fines, registrations approval, payments reconciliation, repair cases, stocktake, CSV import, ISBN enrichment, closures, rooms, holds, privacy requests, risk alerts, acquisition intelligence, executive summaries, audit trail. |
| **Admins / DevOps**       | Manifests, validation scripts, CI workflow, seed scripts, UAT scripts.                                                                                                                                                                                                                                      |

Feature-by-feature technical write-ups live in [`docs/features/`](docs/features/README.md).

## 2. Architecture at a glance

```
                       ┌──────────────────────────────────────────────┐
 Browser ──►  Experience Cloud site "Library" (LWR, digitalExperiences) │
                       │   LWC pages: landing, login, register, portal │
                       └───────────────┬──────────────────────────────┘
                                       │ @AuraEnabled (imperative Apex)
        ┌──────────────────────────────▼──────────────────────────────┐
        │ Controllers  (LibraryMemberSessionController,                 │
        │               LibraryLibrarianController, *GuestController…)  │
        └──────────────────────────────┬──────────────────────────────┘
                                       │
        ┌──────────────────────────────▼──────────────────────────────┐
        │ Services (Circulation, Reservation, Payment, Event, Room…)    │
        │ Policy / Audit / Session / Password helpers                   │
        └───────┬──────────────────────────────────┬──────────────────┘
                │ SOQL/DML                          │ Callouts / Agent API
   ┌────────────▼───────────┐          ┌───────────▼──────────────────┐
   │ Custom objects (__c)    │          │ Named Credentials             │
   │ + private scan ledger   │          │  Library_Metadata (OpenLibrary)│
   └─────────────────────────┘          │  Library_Agent_API (Agentforce)│
                                        └───────────┬──────────────────┘
                                                    ▼
                               Agent Script bundles → Apex @InvocableMethod actions
```

Key design rules (they explain a lot of the code):

1. **Own authentication for members.** Members are _not_ Salesforce community users at runtime. They log in through `LibraryMemberAuthController`, receive an opaque session token (only its SHA-256 hash is stored in `Member_Session__c`), and every protected Apex call resolves exactly one active `Member__c` from that token. Browser-supplied member IDs are never trusted.
2. **Private ledger pattern.** Several newer features (events, rooms, challenges, holds, appeals, privacy, audit, etc.) are stored as JSON rows in `Library_Scan_Transaction__c` (keyed by `Operation__c` + `Idempotency_Key__c`) until dedicated objects are queryable in the org. See [objects/README](force-app/main/default/objects/README.md).
3. **Idempotency everywhere.** Mutations carry idempotency keys so retries are safe.
4. **Permission-gated librarian work.** Four custom permissions (`Manage_Library_Catalog`, `_Circulation`, `_Fines`, `_Registrations`) are enforced in Apex through `LibraryPolicyService.require`.
5. **Agents are read-only unless confirmed.** Member transactions via the assistant use a preview → short-lived single-use token → commit flow.

## 3. Repository map

| Path                                                                                                                            | What it holds                                                                                                                                                            | README                                                                                                                                                                                     |
| ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [`force-app/main/default/`](force-app/main/default/README.md)                                                                   | All Salesforce metadata (source format)                                                                                                                                  | ✔                                                                                                                                                                                          |
| ├ `classes/`                                                                                                                    | 154 Apex classes (about 94 production + 60 test classes incl. the test data factory)                                                                                     | [README](force-app/main/default/classes/README.md)                                                                                                                                         |
| ├ `lwc/`                                                                                                                        | 46 Lightning Web Components (+27 Jest suites)                                                                                                                            | [README](force-app/main/default/lwc/README.md)                                                                                                                                             |
| ├ `objects/`                                                                                                                    | Custom objects & custom metadata types                                                                                                                                   | [README](force-app/main/default/objects/README.md)                                                                                                                                         |
| ├ `triggers/`                                                                                                                   | 7 Apex triggers                                                                                                                                                          | [README](force-app/main/default/triggers/README.md)                                                                                                                                        |
| ├ `aiAuthoringBundles/`                                                                                                         | Agentforce Agent Script (`.agent`) bundles                                                                                                                               | [README](force-app/main/default/aiAuthoringBundles/README.md)                                                                                                                              |
| ├ `genAiFunctions/`, `genAiPlugins/`, `genAiPromptTemplates/`                                                                   | Agent action registrations, topics, prompt template                                                                                                                      | [functions](force-app/main/default/genAiFunctions/README.md) · [plugins](force-app/main/default/genAiPlugins/README.md) · [prompts](force-app/main/default/genAiPromptTemplates/README.md) |
| ├ `digitalExperiences/`                                                                                                         | Experience Cloud (LWR) site bundle `Library1`                                                                                                                            | [README](force-app/main/default/digitalExperiences/README.md)                                                                                                                              |
| ├ `permissionsets/`, `customPermissions/`, `profiles/`, `roles/`, `groups/`                                                     | Access control                                                                                                                                                           | [permissionsets](force-app/main/default/permissionsets/README.md) · [customPermissions](force-app/main/default/customPermissions/README.md)                                                |
| ├ `sharingRules/`, `sharingSets/`                                                                                               | Record visibility                                                                                                                                                        | [rules](force-app/main/default/sharingRules/README.md) · [sets](force-app/main/default/sharingSets/README.md)                                                                              |
| ├ `namedCredentials/`, `externalClientApps/`, `extlClntApp*`, `externalCredentials/`                                            | Outbound/inbound integration config                                                                                                                                      | [README](force-app/main/default/namedCredentials/README.md)                                                                                                                                |
| ├ `customMetadata/`, `labels/`, `settings/`, `staticresources/`, `tabs/`, `applications/`, `flexipages/`, `networks/`, `sites/` | Config & UI shell                                                                                                                                                        | [customMetadata](force-app/main/default/customMetadata/README.md) · [labels](force-app/main/default/labels/README.md) · [ui shell](force-app/main/default/applications/README.md)          |
| [`scripts/`](scripts/README.md)                                                                                                 | PowerShell automation, ad-hoc Apex (`apex/`), demo data seeds (`seed/`)                                                                                                  | [scripts](scripts/README.md) · [apex](scripts/apex/README.md) · [seed](scripts/seed/README.md)                                                                                             |
| [`manifest/`](manifest/README.md)                                                                                               | `package.xml` manifests for core vs Agentforce deploys                                                                                                                   | ✔                                                                                                                                                                                          |
| [`config/`](config/README.md)                                                                                                   | Scratch-org definition                                                                                                                                                   | ✔                                                                                                                                                                                          |
| [`data/`](data/README.md)                                                                                                       | Demo workbook (100 books)                                                                                                                                                | ✔                                                                                                                                                                                          |
| [`docs/`](docs/README.md)                                                                                                       | Design docs, test plans, audit reports, deck                                                                                                                             | ✔                                                                                                                                                                                          |
| [`.github/`](.github/README.md)                                                                                                 | CI workflow                                                                                                                                                              | ✔                                                                                                                                                                                          |
| Root files                                                                                                                      | `sfdx-project.json`, `package.json`, `jest.config.js`, `eslint.config.js`, `.prettierrc`, `.forceignore`, `.husky/`, `CHANGELOG.md`, `skills-lock.json`, `graphify-out/` | see §6                                                                                                                                                                                     |

## 4. Quick start

Prerequisites: Salesforce CLI (`sf`), Node 20+, PowerShell, a Developer Edition (or sandbox) org with **Agentforce** and (optionally) **Data Cloud** enabled.

```powershell
npm install                                   # Jest, ESLint, Prettier, Husky
sf org login web --alias library-org          # authorise the target org
.\scripts\validate-deployment-package.ps1     # local checks of agent schemas + manifests
.\scripts\deploy-library.ps1 -TargetOrg library-org -ValidateOnly   # check-only deploy + RunLocalTests
.\scripts\deploy-library.ps1 -TargetOrg library-org                 # real deploy
sf agent publish authoring-bundle --api-name Library_Public_Assistant --target-org library-org
```

Then assign permission sets (`Library_Librarian`, `Library_Member`), activate the Experience site, load demo data (`scripts/seed/` or `scripts/import-library-workbook.ps1`). Full steps: [docs/SETUP.md](docs/SETUP.md).

## 5. Everyday commands

| Task              | Command                                                                          |
| ----------------- | -------------------------------------------------------------------------------- |
| LWC unit tests    | `npm test` (`sfdx-lwc-jest --runInBand`)                                         |
| LWC lint          | `npm run lint`                                                                   |
| Format everything | `npm run prettier`                                                               |
| Whole UAT gate    | `.\scripts\run-uat.ps1 -TargetOrg library-org`                                   |
| Apex tests in org | `sf apex run test --target-org library-org --test-level RunLocalTests --wait 30` |
| Retrieve site     | `.\scripts\retrieve-experience-site.ps1`                                         |

## 6. Root-level files explained

| File                | Purpose                                                                                                       |
| ------------------- | ------------------------------------------------------------------------------------------------------------- |
| `sfdx-project.json` | One package directory `force-app`, source API **68.0**, no namespace.                                         |
| `package.json`      | npm scripts (lint, Jest, Prettier), `lint-staged` rules, dev-dependencies.                                    |
| `jest.config.js`    | Extends `@salesforce/sfdx-lwc-jest`; maps `lightning/accApi` to a mock in `force-app/test/jest-mocks`.        |
| `eslint.config.js`  | ESLint 9 flat config for Aura/LWC/Jest files.                                                                 |
| `.prettierrc`       | Prettier with Apex + XML plugins, LWC HTML parser.                                                            |
| `.forceignore`      | Excludes `package.xml`, `jsconfig.json`, `__tests__`, `node_modules`, and every `README.md` from deployments. |
| `.husky/pre-commit` | Runs `npm run precommit` (lint-staged: Prettier, ESLint, related Jest tests).                                 |
| `CHANGELOG.md`      | Release notes (v1.0.0, 2026-10-27).                                                                           |
| `skills-lock.json`  | Lock file for installed Claude Code skills (tooling only).                                                    |
| `graphify-out/`     | Generated knowledge-graph output (tooling only).                                                              |
| `.vscode/`          | Editor settings, recommended extensions, launch config.                                                       |

## 7. Security boundaries (read before changing code)

- Never commit credentials; payment webhook secret lives in protected custom metadata (`Payment_Gateway_Config__mdt`).
- `without sharing` services exist deliberately and always scope by the resolved member or a custom permission.
- Agents never ask for tokens or member IDs; the portal injects the validated session token.
- See [docs/SECURITY_MODEL.md](docs/SECURITY_MODEL.md) and [permissionsets README](force-app/main/default/permissionsets/README.md).
