param(
    [string]$TargetOrg = 'library-org',
    [switch]$SkipOrgTests
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

function Invoke-Check([string]$Label, [scriptblock]$Command) {
    Write-Host "`n=== $Label ===" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE"
    }
}

Invoke-Check 'LWC unit tests' { npm test }
Invoke-Check 'LWC lint' { npm run lint }
Invoke-Check 'Agentforce schemas and manifests' { ./scripts/validate-deployment-package.ps1 }

if (-not $SkipOrgTests) {
    Invoke-Check 'Apex local tests' { sf apex run test --target-org $TargetOrg --test-level RunLocalTests --wait 30 --result-format human }
    Invoke-Check 'Runtime schema validation' { ./scripts/validate-library-schema.ps1 -TargetOrg $TargetOrg }
}

Write-Host "`nUAT automation checks passed for $TargetOrg." -ForegroundColor Green
Write-Host 'Manual browser, email, Data Cloud, and Agentforce runtime gates remain required; see docs/UAT_TEST_PLAN.md.'
