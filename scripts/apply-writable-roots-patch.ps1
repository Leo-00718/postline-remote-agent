# Patch postline so the Codex worker can write outside its cwd.
# Idempotent: re-run after a postline update. Then rebuild and restart.
#   .\apply-writable-roots-patch.ps1 -PostlineRoot D:\path\to\postline
param(
  [Parameter(Mandatory = $true)][string]$PostlineRoot
)

$ErrorActionPreference = 'Stop'
$runner = Join-Path $PostlineRoot 'packages\cli\src\cc-worker\runner.ts'
if (-not (Test-Path $runner)) { throw "runner.ts not found at $runner" }

$text = [System.IO.File]::ReadAllText($runner, [System.Text.Encoding]::UTF8)

if ($text -match 'extraWritableRootArgs') {
  Write-Host '[skip] runner.ts already patched'
} else {
  $anchor = 'function codexSpec(opts: RunnerOptions): AgentSpec {'
  $helper = @"
/**
 * Extra writable roots outside the workspace, from CC_WORKER_WRITABLE_ROOTS
 * (a JSON array of absolute paths). Keeps the workspace-write sandbox while
 * allowing writes to directories the operator explicitly opts into.
 */
function extraWritableRootArgs(): string[] {
  const raw = process.env.CC_WORKER_WRITABLE_ROOTS;
  if (!raw) return [];
  try {
    const roots = JSON.parse(raw);
    if (!Array.isArray(roots) || roots.length === 0) return [];
    return ['-c', ('sandbox_workspace_write.writable_roots=' + JSON.stringify(roots))];
  } catch {
    return [];
  }
}

"@
  if (-not $text.Contains($anchor)) { throw 'codexSpec anchor not found - postline layout changed' }
  $text = $text.Replace($anchor, $helper + $anchor)

  $old = "      opts.codexSandbox ?? 'workspace-write',"
  $new = "      opts.codexSandbox ?? 'workspace-write',`n      ...extraWritableRootArgs(),"
  if (-not $text.Contains($old)) { throw 'sandbox arg anchor not found - postline layout changed' }
  $text = $text.Replace($old, $new)

  [System.IO.File]::WriteAllText($runner, $text, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host '[ok] runner.ts patched'
}

Write-Host ''
Write-Host 'Next:'
Write-Host "  1. cd $PostlineRoot; pnpm --filter @postline/cli build"
Write-Host '  2. Set CC_WORKER_WRITABLE_ROOTS at the top of start-all.ps1, e.g.'
Write-Host '     $env:CC_WORKER_WRITABLE_ROOTS = ''["C:/Users/You/Desktop","C:/Users/You/Downloads"]'''
Write-Host '  3. Restart the bridge + worker'