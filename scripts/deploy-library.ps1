param([string]$TargetOrg='library-org',[switch]$ValidateOnly)
$ErrorActionPreference='Stop'
$schedulerName = 'Library Member Notification Scheduler'
$expectedCron = '0 15 * * * ?'
$unscheduled = $false
$deploymentExitCode = 1

try {
    $query = "SELECT Id, CronExpression, TimeZoneSidKey, State FROM CronTrigger WHERE CronJobDetail.Name = '$schedulerName' AND State IN ('WAITING','ACQUIRED','PAUSED','BLOCKED','PAUSED_BLOCKED')"
    $jobResult = & sf data query --query $query --target-org $TargetOrg --result-format json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $jobResult.status -ne 0) { throw 'Unable to inspect the notification scheduler.' }
    if ($jobResult.result.totalSize -gt 1) { throw "More than one active '$schedulerName' job exists; refusing to modify an ambiguous schedule." }
    if ($jobResult.result.totalSize -eq 1) {
        $job = $jobResult.result.records[0]
        if ($job.CronExpression -ne $expectedCron) { throw "The active scheduler uses '$($job.CronExpression)', not the expected '$expectedCron'. Refusing to change it." }
        Write-Host "Temporarily unscheduling '$schedulerName' ($($job.Id))."
        sf apex run --file scripts/apex/unschedule-notification-scheduler.apex --target-org $TargetOrg
        if ($LASTEXITCODE -ne 0) { throw 'The notification scheduler could not be unscheduled.' }
        $unscheduled = $true
    }

    if ($ValidateOnly) {
        sf project deploy start --manifest manifest/core-package.xml --target-org $TargetOrg --dry-run --test-level RunLocalTests --wait 30
    }
    else {
        sf project deploy start --manifest manifest/core-package.xml --target-org $TargetOrg --test-level RunLocalTests --wait 30
    }
    $deploymentExitCode = $LASTEXITCODE
}
finally {
    if ($unscheduled) {
        Write-Host "Restoring '$schedulerName' with cron '$expectedCron'."
        try {
            sf apex run --file scripts/apex/restore-notification-scheduler.apex --target-org $TargetOrg
            if ($LASTEXITCODE -ne 0) { throw 'The restore Apex script failed.' }
        }
        catch {
            Write-Error "CRITICAL: Deployment finished, but the notification scheduler could not be restored. $($_.Exception.Message)"
            $deploymentExitCode = 1
        }
    }
}

exit $deploymentExitCode
