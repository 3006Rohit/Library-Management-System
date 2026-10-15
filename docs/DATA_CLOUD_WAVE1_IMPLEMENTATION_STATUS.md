# Wave 1 Data Cloud Implementation Status

Audit date: 2026-10-13  
Target Salesforce org: `library-org` (`00DgK00000bjSndUAE`)  
Status: **WAVE 1 BLOCKED — MANUAL DATA CLOUD SETUP REQUIRED**

## A. Environment discovery

| Check                                         | Result                                                                    |
| --------------------------------------------- | ------------------------------------------------------------------------- |
| Data Cloud/Data 360 provisioned               | Yes — `CustomerDataPlatformSettings.IsCustomerDataPlatformEnabled = true` |
| Connected user                                | `arohit3009c.58934d09bdef@agentforce.com`                                 |
| Data Cloud permission                         | `GenieAdmin` / Data Cloud Architect assigned                              |
| Salesforce CRM connection                     | Not present                                                               |
| Existing connections                          | `UploadedFiles`; `MarketingDataConnection`                                |
| CRM-backed Wave 1 streams                     | None found                                                                |
| CRM-backed Wave 1 DLOs                        | None found                                                                |
| Custom Wave 1 DMOs                            | None found                                                                |
| Agentforce/Data Graph/Calculated Insight work | Not started                                                               |

The five existing DLOs are platform/default objects (`Account_Home`, `Contact_Home`, `EngagementAggregation`, `IndividualGDPRState`, and `StaticCurrencyRates_Home`) and have no CRM data-source object connection. They are not Wave 1 library streams.

Two Salesforce aliases are authenticated locally. `library-org` (`00DgK00000bjSndUAE`) is the project target and contains the verified 41-member population. `lms library` (`00Dbm000011k7obEAA`) is a separate Developer Edition with one `Member__c` record. Neither org has a Salesforce CRM Data Cloud connection; the existing connection names in `library-org` are only `UploadedFiles` and `MarketingDataConnection`.

The Tooling API exposes Data Cloud metadata entities, but Data Space row enumeration and creation are not available through the connected Salesforce API surface. The Data Cloud UI must be used to confirm the default Data Space name and access policy.

## B. Blocking step

Create a Salesforce CRM connection in Data Cloud Setup before creating streams. Current org metadata has no CRM connection to select, so Wave 1 streams cannot be created or activated from this workspace without fabricating configuration.

Manual navigation:

1. Open the Data Cloud/Data 360 app and go to **Data Cloud Setup → Salesforce Integrations → Salesforce CRM**.
2. Click **New**, choose the connected production/developer Salesforce org, and assign an immutable alias such as `LibraryCRM`.
3. Complete the OAuth consent and confirm the Data 360 org identifier.
4. Confirm the default Data Space is appropriate for production library data. Do not create another Data Space unless tenant governance requires it.
5. Confirm the Data Cloud Salesforce Connector permission set has read access to the approved Wave 1 objects and fields. Do not grant access to authentication/session fields.

Salesforce documents that the CRM alias is used in generated stream/DLO names and cannot be changed after connection setup; it also documents that CRM data streams create DLOs and that batch/stream processing have different refresh behavior. [CRM connection setup](https://help.salesforce.com/s/articleView?id=sf.c360_a_set_up_crm_connection.htm&language=en_US&release=246.6.0&type=5), [CRM stream creation](https://help.salesforce.com/s/articleView?id=sf.c360_a_create_crm_data_stream.htm&language=en_US&type=5), [CRM connector considerations](https://help.salesforce.com/s/articleView?id=data.c360_a_managing_crm_connections.htm&language=en_US&type=5).

## C. Wave 1 configuration to apply after the connection exists

Create only these Salesforce CRM streams in the approved production Data Space:

| Stream                       | Source               | Category         | Filter/governance                                                     |
| ---------------------------- | -------------------- | ---------------- | --------------------------------------------------------------------- |
| `Member_LibraryCRM`          | `Member__c`          | Profile          | `Member_Type__c = 'Production'`; exclude auth/session/security fields |
| `Membership_Plan_LibraryCRM` | `Membership_Plan__c` | Other            | Include approved plan policy fields and historical plans              |
| `Borrow_Record_LibraryCRM`   | `Borrow_Record__c`   | Engagement/Other | Related member must be Production                                     |
| `Reservation_LibraryCRM`     | `Reservation__c`     | Engagement/Other | Related member must be Production                                     |
| `Fine_LibraryCRM`            | `Fine__c`            | Engagement/Other | Related member must be Production; internal restricted data           |
| `Book_LibraryCRM`            | `Book__c`            | Other            | Approved catalog fields only; Wave 2 enrichment excluded              |

The CRM connector’s related-object filter capability must be tested before activation. If it cannot enforce `Member__r.Member_Type__c = 'Production'` at source ingestion, keep the child stream in a governed staging/production-isolated design and do not claim that the physical DLO is production-only. Separate physical DLO totals from production-eligible totals.

## D. Required mappings after stream ingestion

- `Member__c.Id` → Individual source/reconciliation key.
- `Member__c.Email__c` → Contact Point Email, with `Email_Verified__c` retained as a verification attribute.
- No Contact Point Phone mapping.
- No Identity Resolution ruleset.
- No Calculated Insights or Data Graphs.
- No Agentforce agents, topics, actions, prompt templates, or permissions.

Wave 1 custom DMO names and relationships are defined in [DATA_CLOUD_IMPLEMENTATION_BLUEPRINT.md](DATA_CLOUD_IMPLEMENTATION_BLUEPRINT.md). CRM streams must create their DLOs; do not manually create duplicate DLOs.

## E. Required post-setup verification

| Verification          | Required result                                                                              |
| --------------------- | -------------------------------------------------------------------------------------------- |
| Stream status         | Active, or exact failure recorded                                                            |
| DLO counts            | Reconciled to Salesforce source counts; physical and production-eligible totals separated    |
| Member isolation      | Production ≈ 7 in production context; Demo/Test/UAT = 0 in production context                |
| Child isolation       | Demo/Test/UAT loans, reservations, and fines unavailable to production grounding             |
| Key integrity         | `Member__c.Id` and transaction IDs populated and stable                                      |
| Mapping               | Individual, email, and approved custom DMO mappings active                                   |
| Relationship checks   | Production sample resolves plan, loans, reservations, fines, loan→fine, and reservation→book |
| Sensitive-field check | No password, token, lockout, external-auth, session, payment, or phone fields mapped         |

## F. Explicit deferred items

- Contact Point Phone — **DEFERRED**
- Payments — **DEFERRED**
- Identity Resolution — **DEFERRED**
- Calculated Insights — **NOT STARTED**
- Data Graphs — **NOT STARTED**
- Agentforce — **NOT STARTED**

No Data Cloud resources were created in this phase because the required Salesforce CRM connection and Data Space verification are not available through the current org/API state.
