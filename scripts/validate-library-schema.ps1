param([string]$TargetOrg='library-org')
$ErrorActionPreference='Stop'
$query='SELECT Id FROM Library_Schema_Diagnostic__c LIMIT 1'
sf data query --target-org $TargetOrg --query $query --json | Out-Null
sf apex run --target-org $TargetOrg --file scripts/validate-library-schema.apex
