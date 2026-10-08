# TEMPLATE - replace the path placeholders below.
# Save as UTF-8 WITH BOM (PowerShell 5.1 misreads BOM-less UTF-8).
# Start postline bridge + Codex worker in background (no windows).
$ErrorActionPreference = 'Continue'
$root   = "D:\path\to\postline"
$work   = "D:\path\to\scratch-workspace"
$logDir = "$root\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$diag = "$logDir\start-all.diag.log"
"[$(Get-Date -Format o)] start-all invoked" | Out-File $diag -Append

# Resolve node robustly: PATH -> known fallback path.
$node = $null
try { $node = (Get-Command node -ErrorAction Stop).Source } catch {}
if (-not $node) {
  $cand = Get-ChildItem "$env:USERPROFILE\.cache\codex-runtimes" -Recurse -Filter node.exe -ErrorAction SilentlyContinue |
          Select-Object -First 1 -ExpandProperty FullName
  if ($cand) { $node = $cand }
}
if (-not $node) {
  "[$(Get-Date -Format o)] ERROR: node not found" | Out-File $diag -Append
  exit 1
}
"[$(Get-Date -Format o)] node = $node" | Out-File $diag -Append

# --- Bridge ---
$bridgeCmd = ". '$root\.secrets.ps1'; Set-Location -LiteralPath '$root'; & '$node' 'packages/cli/dist/bin.js' feishu"
try {
  Start-Process -FilePath "powershell" -ArgumentList "-ExecutionPolicy","Bypass","-NoProfile","-Command",$bridgeCmd `
    -WindowStyle Hidden -RedirectStandardOutput "$logDir\bridge.out.log" -RedirectStandardError "$logDir\bridge.err.log"
  "[$(Get-Date -Format o)] bridge spawned" | Out-File $diag -Append
} catch { "[$(Get-Date -Format o)] bridge spawn FAILED: $_" | Out-File $diag -Append }

Start-Sleep -Seconds 6

# --- Worker ---
$workerCmd = ". '$root\.secrets.ps1'; `$env:CC_DOORBELL_URL='http://localhost:9999'; Set-Location -LiteralPath '$work'; & '$node' '$root\packages\cli\dist\bin.js' cc-worker start --agent codex"
try {
  Start-Process -FilePath "powershell" -ArgumentList "-ExecutionPolicy","Bypass","-NoProfile","-Command",$workerCmd `
    -WindowStyle Hidden -RedirectStandardOutput "$logDir\worker.out.log" -RedirectStandardError "$logDir\worker.err.log"
  "[$(Get-Date -Format o)] worker spawned" | Out-File $diag -Append
} catch { "[$(Get-Date -Format o)] worker spawn FAILED: $_" | Out-File $diag -Append }

Start-Sleep -Seconds 2
"[$(Get-Date -Format o)] done" | Out-File $diag -Append
Write-Host "[OK] bridge + worker started."