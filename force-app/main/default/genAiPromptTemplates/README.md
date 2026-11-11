# `genAiPromptTemplates/` — Prompt templates

## `Library_Acquisition_Advisor`

Type `einstein_gpt__flex`, visibility Global, model `sfdc_ai__DefaultGPT4Omni`, status Published. One required input: `signals` (a JSON array, one object per title).

The prompt is the "collection development advisor". It treats all input as data (prompt-injection guard) and applies these rules:

| Type         | Rule                                                                                                                                         |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| **Purchase** | holds per lendable copy > 3:1, or a reader waiting ≥ 21 days, or ≥ 4 loans/copy in 90 days with empty shelf; buy up to ~3 holds/copy, max 10 |
| **Replace**  | damaged/lost/poor copies only while still wanted                                                                                             |
| **Weed**     | titles acquired ≥ 2 years ago, no holds and no loans in 90 days; keep one copy per loan in last 12 months                                    |
| **None**     | nothing needed                                                                                                                               |

Output: JSON array of `{bookId, type, quantity, score(1-100), confidence(High/Medium/Low), rationale}`.

**Consumer:** `LibraryAcquisitionInsightService` builds the `signals` from a rolling 90-day window and stores the answer as immutable `Acquisition_Recommendation__c` snapshots (unique `Snapshot_Key__c`). The UI is `libraryAcquisitionDashboard`.

The source file is currently untracked in git (new work) — commit it with the acquisition changes.
