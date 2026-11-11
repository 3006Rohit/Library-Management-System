# `docs/` — documentation hub

## Where to start

| If you want to…                        | Read                                                                                                                                               |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Understand every feature technically   | [`features/`](features/README.md) (one README per functionality)                                                                                   |
| Understand the data                    | [DATA_MODEL.md](DATA_MODEL.md) and [objects README](../force-app/main/default/objects/README.md)                                                   |
| Understand business flows              | [WORKFLOWS.md](WORKFLOWS.md)                                                                                                                       |
| Understand security                    | [SECURITY_MODEL.md](SECURITY_MODEL.md)                                                                                                             |
| Install / configure an org             | [SETUP.md](SETUP.md), [OPERATIONS.md](OPERATIONS.md)                                                                                               |
| Run the demo                           | [DEMO_SCRIPT.md](DEMO_SCRIPT.md)                                                                                                                   |
| Work on agents                         | [AGENTFORCE_IMPLEMENTATION.md](AGENTFORCE_IMPLEMENTATION.md), [PUBLIC_ASSISTANT.md](PUBLIC_ASSISTANT.md), `agent-spec-*.yaml`                      |
| Work on Data Cloud                     | [DATA_CLOUD_IMPLEMENTATION_BLUEPRINT.md](DATA_CLOUD_IMPLEMENTATION_BLUEPRINT.md), [DATA_CLOUD_SOURCE_READINESS.md](DATA_CLOUD_SOURCE_READINESS.md) |
| See the roadmap for remaining features | [OUTSTANDING_FEATURES_IMPLEMENTATION_BLUEPRINT.md](OUTSTANDING_FEATURES_IMPLEMENTATION_BLUEPRINT.md)                                               |

## Files in this folder

| File                                                  | Content                                                                                                                                                |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `DATA_MODEL.md`                                       | Object-by-object model, including the private-ledger features                                                                                          |
| `WORKFLOWS.md`                                        | Registration, circulation, reservations, payments, notifications, events, rooms, privacy, etc.                                                         |
| `SECURITY_MODEL.md`                                   | Member/librarian/integration controls. _Note: the "Web controls" section describes a removed external web portal (Helmet/CORS); it no longer applies._ |
| `SETUP.md`                                            | Org setup checklist. _It links to a `TROUBLESHOOTING.md` that does not exist._                                                                         |
| `OPERATIONS.md`                                       | Deployment gate, async monitoring, incident response, backup                                                                                           |
| `DEMO_SCRIPT.md`                                      | Presenter walkthrough                                                                                                                                  |
| `AGENTFORCE_IMPLEMENTATION.md`                        | Deployed agents, actions, limits                                                                                                                       |
| `PUBLIC_ASSISTANT.md`                                 | Signed-out assistant flow, security, limits                                                                                                            |
| `DATA_CLOUD_*.md`                                     | Blueprint and source-readiness for Data Cloud calculated insights                                                                                      |
| `OUTSTANDING_FEATURES_IMPLEMENTATION_BLUEPRINT.md`    | Phased blueprint for newer features                                                                                                                    |
| `agent-spec-member.yaml`, `agent-spec-librarian.yaml` | Agent specs used to create agents (`sf agent generate`)                                                                                                |
| `testing/`                                            | Test plans and checklists — [README](testing/README.md)                                                                                                |
| `reports/`                                            | Audits and UAT results — [README](reports/README.md)                                                                                                   |
| `presentation/`                                       | Overview deck (`.pptx`) and its generator script — [README](presentation/README.md)                                                                    |

Some docs predate later refactors; when a doc and the code disagree, the code (and the folder READMEs) win.
