# Register a Scheduled Task that starts the bridge + worker at logon.
# TEMPLATE - adjust $root / $work to the real paths.
# Save as UTF-8 WITH BOM.
$ErrorActionPreference = 'Stop'

$root     = 'D:\path\to\postline'            # <-- postline install dir
$taskName = 'postline-autostart'
$launcher = Join-Path $root 'start-all.ps1'

$action    = New-ScheduledTaskAction -Execute 'powershell.exe' `
               -Argument ('-ExecutionPolicy Bypass -NoProfile -File "' + $launcher + '"')
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
               -DontStopIfGoingOnBatteries -StartWhenAvailable `
               -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
               -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
  -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "[OK] registered scheduled task: $taskName"
Write-Host "Verify:  Start-ScheduledTask -TaskName '$taskName'"
Write-Host "Remove:  Unregister-ScheduledTask -TaskName '$taskName' -Confirm:`$false"