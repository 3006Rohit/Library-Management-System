param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$RunSalesforceValidation,
    [string]$TargetOrg = 'validation-org'
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Error $Message
    exit 1
}

$agentRoot = Join-Path $ProjectRoot 'force-app/main/default/genAiFunctions'
$bundleRoot = Join-Path $ProjectRoot 'force-app/main/default/aiAuthoringBundles'
$manifestRoot = Join-Path $ProjectRoot 'manifest'

if (-not (Test-Path -LiteralPath $agentRoot)) {
    Fail "Agentforce source directory not found: $agentRoot"
}
if (-not (Test-Path -LiteralPath $bundleRoot)) {
    Fail "Agentforce authoring-bundle directory not found: $bundleRoot"
}

$schemaErrors = @()
$outputSchemas = Get-ChildItem -LiteralPath $agentRoot -Recurse -Filter 'schema.json' -File |
    Where-Object { $_.FullName -match '[\\/]output[\\/]schema\.json$' }
foreach ($outputSchema in $outputSchemas) {
    $actionDirectory = Split-Path -Parent (Split-Path -Parent $outputSchema.FullName)
    $inputSchema = Join-Path $actionDirectory 'input/schema.json'
    if (-not (Test-Path -LiteralPath $inputSchema)) {
        # Salesforce omits an input schema for valid no-input Apex actions,
        # such as aggregate analytics actions invoked with an empty request.
        continue
    }

    foreach ($schemaPath in @($inputSchema, $outputSchema.FullName)) {
        try {
            $schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json
            if ($null -eq $schema.'lightning:type') {
                $schemaErrors += "Missing lightning:type: $schemaPath"
            }
        } catch {
            $schemaErrors += "Invalid JSON schema: $schemaPath ($($_.Exception.Message))"
        }
    }
}

if ($schemaErrors.Count -gt 0) {
    $schemaErrors | ForEach-Object { Write-Error $_ }
    exit 1
}

foreach ($manifestName in @('core-package.xml', 'agentforce-package.xml')) {
    $manifestPath = Join-Path $manifestRoot $manifestName
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        Fail "Required deployment manifest not found: $manifestPath"
    }
    try {
        [xml](Get-Content -LiteralPath $manifestPath -Raw) | Out-Null
    } catch {
        Fail "Invalid deployment manifest XML: $manifestPath ($($_.Exception.Message))"
    }
}

$agentforceManifest = [xml](Get-Content -LiteralPath (Join-Path $manifestRoot 'agentforce-package.xml') -Raw)
$agentforceTypes = @($agentforceManifest.Package.types | ForEach-Object { [string]$_.name })
foreach ($requiredType in @('GenAiFunction', 'GenAiPlugin')) {
    if ($agentforceTypes -notcontains $requiredType) {
        Fail "Agentforce manifest is missing metadata type: $requiredType"
    }
}

$versionType = @($agentforceManifest.Package.types | Where-Object { [string]$_.name -eq 'AiAgentDefinitionVersion' })
if ($versionType.Count -gt 0) {
    Fail "Do not deploy AiAgentDefinitionVersion from the wildcard Agentforce manifest. Publish the AiAuthoringBundle to generate a supported agent version."
}

Write-Host "Deployment package checks passed: $($outputSchemas.Count) Agentforce output schema(s) have matching valid input schemas."
Write-Host "Core and Agentforce manifests are present and valid XML."

if ($RunSalesforceValidation) {
    sf project deploy start --manifest (Join-Path $manifestRoot 'core-package.xml') --target-org $TargetOrg --dry-run --test-level RunLocalTests --wait 30
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    sf project deploy start --manifest (Join-Path $manifestRoot 'agentforce-package.xml') --target-org $TargetOrg --dry-run --test-level RunLocalTests --wait 30
    exit $LASTEXITCODE
}
