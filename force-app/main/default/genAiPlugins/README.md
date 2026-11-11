# `genAiPlugins/` — Generated agent topics

Eight `GenAiPlugin` (topic) definitions produced by the Agentforce builder for the first-generation planner agents. The prefix (`p_16jgK000002I31V_…`, `p_16jgK000002I337_…`) is the org-generated planner id.

| Group                       | Topics                                                                            |
| --------------------------- | --------------------------------------------------------------------------------- |
| Librarian planner (`…I31V`) | `Catalog_Search`, `Circulation_Information`, `Library_Analytics`, `Member_Lookup` |
| Member planner (`…I337`)    | `Catalog_Discovery`, `My_Library_Activity`, `My_Loans`, `My_Reservations`         |

They are read-only topics that reference the GenAiFunctions in [`../genAiFunctions`](../genAiFunctions/README.md). Newer agents use Agent Script bundles in [`../aiAuthoringBundles`](../aiAuthoringBundles/README.md); these plugins are kept so existing planner versions keep deploying. Do not hand-edit — regenerate in Agentforce Builder and retrieve.
