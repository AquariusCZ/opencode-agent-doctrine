[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$ConfigDir = "$env:USERPROFILE\.config\opencode"
)

$ErrorActionPreference = 'Stop'

$PackageAgents = @(
    'orchestrator.md',
    'worker.md',
    'verifier.md',
    'reviewer-correctness.md',
    'reviewer-adversarial.md',
    'researcher.md',
    'scout.md',
    'merger.md'
)

$DestAgents  = Join-Path $ConfigDir 'agents'
$DestSidecar = Join-Path $ConfigDir 'AGENTS.opencode-doctrine.md'

$Stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir = Join-Path $ConfigDir "agents.uninstall.bak-$Stamp"

$targets = @()
foreach ($name in $PackageAgents) {
    $path = Join-Path $DestAgents $name
    if (Test-Path -LiteralPath $path) { $targets += $path }
}
if (Test-Path -LiteralPath $DestSidecar) { $targets += $DestSidecar }

if ($DryRun) {
    Write-Host '=== DRY RUN: nothing will be deleted ===' -ForegroundColor Yellow
}
Write-Host "config: $ConfigDir"
Write-Host ''

if ($targets.Count -eq 0) {
    Write-Host 'Nothing to remove: none of the package files are installed.'
}
else {
    $prefix = ''
    if ($DryRun) { $prefix = '[dry-run] would ' }
    Write-Host "$($prefix)back up $($targets.Count) file(s) to: $BackupDir"
    Write-Host "$($prefix)remove $($targets.Count) file(s):"
    foreach ($path in $targets) { Write-Host "  $path" }

    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
        foreach ($path in $targets) {
            Copy-Item -LiteralPath $path -Destination (Join-Path $BackupDir (Split-Path -Leaf $path)) -Force
        }
        foreach ($path in $targets) {
            Remove-Item -LiteralPath $path -Force
        }

        if (Test-Path -LiteralPath $DestAgents) {
            $leftovers = @(Get-ChildItem -LiteralPath $DestAgents -Force -ErrorAction SilentlyContinue)
            if ($leftovers.Count -eq 0) {
                Remove-Item -LiteralPath $DestAgents -Force
            }
        }
        Write-Host ''
        Write-Host "removed $($targets.Count) file(s); backup kept at $BackupDir" -ForegroundColor Green
    }
}

Write-Host ''
Write-Host 'AGENTS.md 和 opencode.jsonc 未改动，请手动清理。' -ForegroundColor Yellow
