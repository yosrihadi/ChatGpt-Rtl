

$ErrorActionPreference = 'Stop'
$resultFile = Join-Path $env:ProgramData 'chatgpt-rtl-fix-result.txt'

# The actual fix, run in an elevated child process. Kept as literal text so it
# can be passed via -EncodedCommand. Writes a one-word result to a shared file
# (ProgramData resolves to the same path for the user and the elevated process).
$fixBody = @'
$ErrorActionPreference = "Stop"
$TaskName = "chatgpt RT-AI RTL Auto-Update"
$resultFile = Join-Path $env:ProgramData "chatgpt-rtl-fix-result.txt"
try {
    $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $t) { Set-Content -LiteralPath $resultFile -Value "NOTASK" -Encoding ASCII; return }

    # Reuse the patcher path the task already points to - do not re-deploy.
    $act = @($t.Actions)[0]
    if ($act.Arguments -match '-File\s+"([^"]+)"') { $patcher = $Matches[1] }
    else { Set-Content -LiteralPath $resultFile -Value "NOPATH" -Encoding ASCII; return }

    $newArgs = "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$patcher`" -AutoUpdate"
    $newAction = New-ScheduledTaskAction -Execute $act.Execute -Argument $newArgs

    # chatgpt-only AppX deployment-succeeded trigger (EventID 400, PackageDisplayName=chatgpt).
    $cls = Get-CimClass -Namespace "ROOT\Microsoft\Windows\TaskScheduler" -ClassName MSFT_TaskEventTrigger
    $evt = New-CimInstance -CimClass $cls -ClientOnly
    $evt.Enabled = $true
    $evt.Subscription = '<QueryList><Query Id="0" Path="Microsoft-Windows-AppXDeploymentServer/Operational"><Select Path="Microsoft-Windows-AppXDeploymentServer/Operational">*[System[EventID=400] and EventData[Data[@Name="PackageDisplayName"]="Codex"]]</Select></Query></QueryList>'
    $evt.Delay = "PT1M"
    $triggers = @($evt, (New-ScheduledTaskTrigger -AtLogOn), (New-ScheduledTaskTrigger -Daily -At "12:00"))

    Set-ScheduledTask -TaskName $TaskName -Action $newAction -Trigger $triggers | Out-Null

    # Verify what actually got written.
    $v = Get-ScheduledTask -TaskName $TaskName
    $a = @($v.Actions)[0].Arguments
    $sub = ($v.Triggers | Where-Object { $_.CimClass.CimClassName -eq "MSFT_TaskEventTrigger" }).Subscription
    if (($a -match "-WindowStyle Hidden") -and ($sub -match 'PackageDisplayName"\]="chatgpt"')) {
        Set-Content -LiteralPath $resultFile -Value "OK" -Encoding ASCII
    } else {
        Set-Content -LiteralPath $resultFile -Value "VERIFYFAIL" -Encoding ASCII
    }
} catch {
    Set-Content -LiteralPath $resultFile -Value ("ERR: " + $_.Exception.Message) -Encoding ASCII
}
'@

Remove-Item -LiteralPath $resultFile -ErrorAction SilentlyContinue
$enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($fixBody))
$psExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if ($isAdmin) {
    & $psExe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $enc
} else {
    Write-Host "Requesting administrator rights once (approve the UAC prompt)..." -ForegroundColor Cyan
    try {
        Start-Process $psExe -Verb RunAs -Wait `
            -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$enc
    } catch {
        Write-Host "Fix cancelled (administrator rights were not granted)." -ForegroundColor Red
        return
    }
}

$res = if (Test-Path -LiteralPath $resultFile) { (Get-Content -LiteralPath $resultFile -Raw).Trim() } else { 'NORESULT' }
Remove-Item -LiteralPath $resultFile -ErrorAction SilentlyContinue

switch -Wildcard ($res) {
    'OK'         { Write-Host "`n[OK] Fixed. The auto-update task now runs hidden and only fires on a real chatgpt update - no more CMD window pop-ups." -ForegroundColor Green }
    'NOTASK'     { Write-Host "`nNo auto-update task on this machine (the patch is probably not installed) - nothing to fix." -ForegroundColor Yellow }
    'NOPATH'     { Write-Host "`nCould not read the patch.ps1 path from the task. Re-run the installer for a full fix." -ForegroundColor Yellow }
    'VERIFYFAIL' { Write-Host "`nThe task was updated but verification failed. Re-run the installer for a full fix." -ForegroundColor Yellow }
    'NORESULT'   { Write-Host "`nNo result returned (the UAC prompt may have been cancelled)." -ForegroundColor Red }
    default      { Write-Host "`nError: $res" -ForegroundColor Red }
}
