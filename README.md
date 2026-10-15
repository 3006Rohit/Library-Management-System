# Salesforce DX Project

The library uses the Salesforce Experience Cloud member portal and Salesforce registration/provisioning workflows.

Salesforce DX is a development approach that brings source-driven development, team collaboration, and continuous integration to the Salesforce Platform. Instead of working directly in an org through a web browser, you work with metadata as source files in a local DX project, track changes in version control, and deploy through automated processes.

This project template gets you started with the tools and structure you need to build Salesforce applications using source control, scratch orgs, and the Salesforce CLI.

## Prerequisites

Before you start, make sure you have:

- **Salesforce CLI** - Download from [developer.salesforce.com/tools/salesforcecli](https://developer.salesforce.com/tools/salesforcecli). See [Install Salesforce CLI](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_install_cli.htm) for details.
- **VS Code with Salesforce Extension Pack** - See [Installation Instructions](https://developer.salesforce.com/docs/platform/sfvscode-extensions/guide/install.html) for details. Includes the Agentforce Vibes extension.
- **A development org** - Sign up for a free Developer Edition org [here](https://developer.salesforce.com/signup).
- **Dev Hub enabled** (optional, required to create scratch orgs) - You can enable Dev Hub in your development org under Setup > Dev Hub. See [Provide Developers Access to Salesforce DX Tools](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_setup_dx_tools.htm).

### Security and authentication boundary

The member portal uses Salesforce Experience Cloud LWR custom authentication and `Member__c`/`Member_Session__c`. Never commit or deploy service-account credentials. If credentials have ever been provisioned, revoke them and rotate the associated cloud credentials manually; this project does not generate replacement credentials.

## Project Structure

Your DX project follows this structure:

- **`force-app/main/default/`** - Your metadata source files live in this default package directory. You can configure additional package directories in the `sfdx-project.json` file.
- **`config/`** - Scratch org definitions and project settings
- **`scripts/`** - Automation scripts for common tasks
- **`sfdx-project.json`** - Project manifest that defines package directories, namespace, API version, and other project-level settings

See [Salesforce DX Project Configuration](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_ws_config.htm).

## Get Started

Ready to start developing? The [Get Started with Salesforce DX](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_get_started_dx.htm) guide walks you through your first project, from creating a scratch org to creating a simple Apex class or LWC to deploying your code to a sandbox.

## Common Salesforce CLI Commands

Here are common CLI commands that you'll use the most:

- `sf org login web`: Authorize an org
- `sf org open`: Open your org in a browser
- `sf org create scratch`: Create a scratch org
- `sf project deploy start`: Deploy metadata to your org
- `sf project retrieve start`: Retrieve metadata from your org
- `sf template generate <artifact>`: Scaffold new components, such as Apex classes and triggers, LWC components, Lightning apps, and more
- `sf apex <command>`: Run Apex tests, run anonymous Apex blocks, and view logs
- `sf data <command>`: Work with test data
- `sf alias <command>`: Manage org aliases
- `sf config <command>`: Configure CLI settings

## Release validation

Core validation and deployment automatically place the notification scheduler in a guarded maintenance window and restore its hourly schedule afterward:

```powershell
.\scripts\deploy-library.ps1 -TargetOrg library-org -ValidateOnly
.\scripts\deploy-library.ps1 -TargetOrg library-org
```

If the local process is forcibly terminated by the operating system during the deployment window, verify the job and run the idempotency-checked restore command if it is absent:

```powershell
sf data query --query "SELECT Id, CronExpression, TimeZoneSidKey, State, NextFireTime FROM CronTrigger WHERE CronJobDetail.Name = 'Library Member Notification Scheduler'" --target-org library-org
sf apex run --file scripts/apex/restore-notification-scheduler.apex --target-org library-org
```

The release package is split into core Salesforce metadata and Agentforce actions:

- `manifest/core-package.xml` contains the core library package.
- `manifest/agentforce-package.xml` contains Agentforce agent definitions, definition versions, authoring bundles, and `GenAiFunction` metadata.
- `scripts/validate-deployment-package.ps1` checks Agentforce input/output schemas and manifest XML before deployment.

Run the local package checks with:

```powershell
./scripts/validate-deployment-package.ps1
```

Run check-only validation against an authenticated org with:

```powershell
./scripts/validate-deployment-package.ps1 -RunSalesforceValidation -TargetOrg validation-org
```

Pull requests and `main`/`master` pushes require a configured `SALESFORCE_VALIDATION_ORG` repository variable and `SFDX_AUTH_URL` repository secret. The Salesforce CI job fails closed when either is missing.

## Use Agentforce Vibes to Build Lightning Apps

Transform your ideas into custom Lightning apps that extend CRM workflows directly in Lightning Experience. Through natural conversations with Agentforce Vibes, implement custom objects and fields, complex business logic, and dynamic UI components. See [Build a Lightning App Using Agentforce Vibes](https://developer.salesforce.com/docs/platform/einstein-for-devs/guide/lexapp-overview.html).

## Additional Resources

- [Agentforce Vibes Developer Guide](https://developer.salesforce.com/docs/platform/einstein-for-devs/guide/einstein-overview.html)
- [Salesforce CLI Installation Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/)
- [Salesforce CLI Plugin Development Guide](https://developer.salesforce.com/docs/platform/salesforce-cli-plugin/guide/conceptual-overview.html)
- [Salesforce VS Code Extensions Documentation](https://developer.salesforce.com/tools/vscode/)
