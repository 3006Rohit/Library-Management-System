param([string]$TargetOrg='library-org',[string]$SiteName='Library')
$ErrorActionPreference='Stop'
sf project retrieve start --metadata "ExperienceBundle:$SiteName" --target-org $TargetOrg --wait 30
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$experienceRoot=Join-Path (Get-Location) 'force-app/main/default/experiences'
if (-not (Test-Path $experienceRoot) -or -not (Get-ChildItem $experienceRoot -Recurse -File -ErrorAction SilentlyContinue)) {
  throw "ExperienceBundle '$SiteName' was not returned by the org. The site must be exposed as deployable ExperienceBundle metadata before site automation can be enabled."
}
