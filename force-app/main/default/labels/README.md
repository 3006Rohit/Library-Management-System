# `labels/`

`CustomLabels.labels-meta.xml` contains one label:

| Label                     | Purpose                                                                                                                                                                                                                                               |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Library_Public_Agent_Id` | The Agentforce **agent id** of the published `Library_Public_Assistant`. Guest users cannot query setup objects, so `LibraryPublicAgentController` reads the id from this label. **Update it if the agent is ever recreated** (ids are org-specific). |
