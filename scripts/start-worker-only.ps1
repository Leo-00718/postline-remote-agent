# TEMPLATE - replace the path placeholders. Save as UTF-8 WITH BOM.
# Start Codex worker - keep this window open.
$ErrorActionPreference = 'Stop'
. "D:\path\to\postline\.secrets.ps1"
$env:CC_DOORBELL_URL = 'http://localhost:9999'
Set-Location -LiteralPath "D:\path\to\scratch-workspace"
Write-Host "[worker] cwd = $(Get-Location)"
Write-Host "[worker] registering Codex worker ..."
node "D:\path\to\postline\packages\cli\dist\bin.js" cc-worker start --agent codex