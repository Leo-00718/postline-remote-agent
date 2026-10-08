# TEMPLATE - replace the path placeholders below.
# Save as UTF-8 WITH BOM (PowerShell 5.1 misreads BOM-less UTF-8).
# Stop postline bridge + Codex worker.
$killed = 0
foreach ($port in 9999) {
  $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
  if ($conn) {
    foreach ($procId in ($conn.OwningProcess | Select-Object -Unique)) {
      Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
      Write-Host "[OK] stopped process on port $port (PID $procId)"
      $killed++
    }
  }
}
Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -like '*cc-worker*' } |
  ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] stopped worker (PID $($_.ProcessId))"
    $killed++
  }
if ($killed -eq 0) { Write-Host "nothing was running." } else { Write-Host "[OK] stopped $killed process(es)." }