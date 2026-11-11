# `.github/`

## `workflows/validate.yml` — "Salesforce validation"

Triggers: every pull request, and pushes to `main`/`master`.

| Job          | Steps                                                                                                                                                                                                                                                                                                                          |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `javascript` | checkout → Node 20 → `npm ci` → `npm test` → `npm run lint`                                                                                                                                                                                                                                                                    |
| `salesforce` | checkout → Node 20 → `npm ci` → install `@salesforce/cli` → **fail closed** unless repo variable `SALESFORCE_VALIDATION_ORG` and secret `SFDX_AUTH_URL` exist → `sf org login sfdx-url` as `validation-org` → `scripts/validate-deployment-package.ps1` → `scripts/deploy-library.ps1 -TargetOrg validation-org -ValidateOnly` |

Setup: in GitHub → Settings → Secrets and variables, add `SFDX_AUTH_URL` (from `sf org display --verbose --json`, the _sfdxAuthUrl_ value) as a **secret** and `SALESFORCE_VALIDATION_ORG` as a **variable**.

Local equivalent: `.\scripts\run-uat.ps1`.
