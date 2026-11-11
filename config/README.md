# `config/`

`project-scratch-def.json` — scratch-org definition: org name "Demo company", **Developer** edition, feature `EnableSetPasswordInApi`, Lightning Experience enabled, mobile encrypted-storage preference off.

```powershell
sf org create scratch --definition-file config/project-scratch-def.json --alias lib-scratch --set-default --duration-days 7
```

Agentforce/Data Cloud features are not enabled by this definition; use a Developer Edition org with them enabled for the full system.
