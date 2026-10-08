# TEMPLATE - replace the path placeholders below.
# Save as UTF-8 WITH BOM (PowerShell 5.1 misreads BOM-less UTF-8).
# Start postline Feishu bridge - keep this window open.
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath "D:\path\to\postline"
. "$PSScriptRoot\.secrets.ps1"
if ($env:POSTLINE_FEISHU_APP_SECRET -eq 'PASTE_YOUR_APP_SECRET_HERE') {
  Write-Host "[ERROR] App Secret not set. Edit .secrets.ps1 first." -ForegroundColor Red
  exit 1
}
Write-Host "[bridge] starting Feishu bridge ..." -ForegroundColor Cyan
node packages/cli/dist/bin.js feishu
