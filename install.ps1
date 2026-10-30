[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$ConfigDir = "$env:USERPROFILE\.config\opencode"
)

$ErrorActionPreference = 'Stop'

$RepoRoot       = $PSScriptRoot
$SourceAgents   = Join-Path $RepoRoot 'agents'
$SourceDoctrine = Join-Path $RepoRoot 'AGENTS.md'
$SourceExample  = Join-Path $RepoRoot 'config\opencode.example.jsonc'

foreach ($required in @($SourceAgents, $SourceDoctrine, $SourceExample)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Package file missing: $required"
    }
}

$agentFiles = @(Get-ChildItem -LiteralPath $SourceAgents -Filter '*.md' -File | Sort-Object Name)
if ($agentFiles.Count -eq 0) {
    throw "No agent files found in $SourceAgents"
}

$DestAgents   = Join-Path $ConfigDir 'agents'
$DestDoctrine = Join-Path $ConfigDir 'AGENTS.md'
$DestSidecar  = Join-Path $ConfigDir 'AGENTS.opencode-doctrine.md'
$DestConfig   = Join-Path $ConfigDir 'opencode.jsonc'

$Stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir = Join-Path $ConfigDir "agents.bak-$Stamp"

function Copy-AsUtf8 {
    param([string]$From, [string]$To)
    $text = Get-Content -LiteralPath $From -Raw -Encoding UTF8
    [System.IO.File]::WriteAllText($To, $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Say {
    param([string]$Message)
    if ($DryRun) { Write-Host "[dry-run] $Message" } else { Write-Host $Message }
}

$existingAgents = @($agentFiles | Where-Object { Test-Path -LiteralPath (Join-Path $DestAgents $_.Name) })
$doctrineExists = Test-Path -LiteralPath $DestDoctrine
$sidecarExists  = Test-Path -LiteralPath $DestSidecar
$configExists   = Test-Path -LiteralPath $DestConfig

if ($DryRun) {
    Write-Host '=== DRY RUN: no files will be written ===' -ForegroundColor Yellow
}
Write-Host "package: $RepoRoot"
Write-Host "config : $ConfigDir"
Write-Host ''

Say "create directory: $DestAgents"

if ($existingAgents.Count -gt 0) {
    Say "back up $($existingAgents.Count) existing agent file(s) to: $BackupDir"
    foreach ($file in $existingAgents) {
        Say "  backup $($file.Name)"
    }
}
else {
    Say 'no existing agent files to back up'
}

foreach ($file in $agentFiles) {
    Say "install agent: $($file.Name) -> $(Join-Path $DestAgents $file.Name)"
}

if ($doctrineExists) {
    Say "AGENTS.md exists, writing sidecar instead: $DestSidecar"
    if ($sidecarExists) { Say "  overwrite existing sidecar (backed up first): $DestSidecar" }
}
else {
    Say "AGENTS.md not found, install as: $DestDoctrine"
}

if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $DestAgents | Out-Null

    if ($existingAgents.Count -gt 0 -or $sidecarExists) {
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    }

    foreach ($file in $existingAgents) {
        Copy-Item -LiteralPath (Join-Path $DestAgents $file.Name) -Destination (Join-Path $BackupDir $file.Name) -Force
    }

    foreach ($file in $agentFiles) {
        Copy-AsUtf8 -From $file.FullName -To (Join-Path $DestAgents $file.Name)
    }

    if ($doctrineExists) {
        if ($sidecarExists) {
            Copy-Item -LiteralPath $DestSidecar -Destination (Join-Path $BackupDir 'AGENTS.opencode-doctrine.md') -Force
        }
        Copy-AsUtf8 -From $SourceDoctrine -To $DestSidecar
    }
    else {
        Copy-AsUtf8 -From $SourceDoctrine -To $DestDoctrine
    }
}

Write-Host ''
if ($doctrineExists) {
    $mergePrompt = '已安装为 AGENTS.opencode-doctrine.md。请把它合并进你的 AGENTS.md，或加入 instructions。'
    if ($DryRun) { Write-Host "[dry-run] would: $mergePrompt" -ForegroundColor Yellow }
    else { Write-Host $mergePrompt -ForegroundColor Yellow }
    Say "sidecar: $DestSidecar"
}
else {
    if ($DryRun) { Write-Host "[dry-run] would install doctrine: $DestDoctrine" }
    else { Write-Host "installed doctrine: $DestDoctrine" }
}

Write-Host ''
Write-Host '=== config/opencode.example.jsonc (merge manually; opencode.jsonc was NOT modified) ===' -ForegroundColor Cyan
Get-Content -LiteralPath $SourceExample -Raw -Encoding UTF8 | Write-Host
Write-Host '=== end of example config ===' -ForegroundColor Cyan
if ($configExists) {
    Write-Host "existing config left untouched: $DestConfig" -ForegroundColor Yellow
}
Write-Host 'Merge the keys you need into your opencode.jsonc by hand.'
