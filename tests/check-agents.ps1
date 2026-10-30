#Requires -Version 5.1
<#
.SYNOPSIS
    Checks the installed OpenCode agent set against the doctrine's contract.

.DESCRIPTION
    Runs `<OpenCode> debug agents`, parses the JSON payload, and asserts:
      - all eight expected agents are present;
      - orchestrator denies edit:* and shell:*;
      - verifier, reviewer-correctness and reviewer-adversarial deny edit:*.

    Read-only. Does not modify any file.

.PARAMETER OpenCode
    The OpenCode executable or command name. Defaults to "opencode".

.EXAMPLE
    pwsh -File ./tests/check-agents.ps1

.EXAMPLE
    pwsh -File ./tests/check-agents.ps1 -OpenCode "C:\tools\opencode.exe"

.NOTES
    Exit codes: 0 = PASS, 1 = assertion failure, 2 = could not run or parse.
#>
[CmdletBinding()]
param(
    [string]$OpenCode = 'opencode'
)

$requiredAgents = @(
    'orchestrator',
    'worker',
    'verifier',
    'reviewer-correctness',
    'reviewer-adversarial',
    'scout',
    'merger',
    'researcher'
)

$requiredDenials = @(
    @{ Agent = 'orchestrator'; Action = 'edit' },
    @{ Agent = 'orchestrator'; Action = 'shell' },
    @{ Agent = 'verifier'; Action = 'edit' },
    @{ Agent = 'reviewer-correctness'; Action = 'edit' },
    @{ Agent = 'reviewer-adversarial'; Action = 'edit' },
    @{ Agent = 'scout'; Action = 'edit' },
    @{ Agent = 'researcher'; Action = 'edit' },
    @{ Agent = 'researcher'; Action = 'shell' }
)

$failures = New-Object System.Collections.Generic.List[string]

function Remove-Ansi {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $esc = [regex]::Escape([string][char]27)
    return ($Text -replace "$esc\[[0-9;?]*[a-zA-Z]", '')
}

function ConvertFrom-JsonLoose {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }

    $trimmed = $Text.Trim()

    # Fast path: the whole payload is JSON.
    try {
        $direct = ConvertFrom-Json -InputObject $trimmed -ErrorAction Stop
        if ($direct -is [System.Management.Automation.PSCustomObject] -or $direct -is [array]) {
            return $direct
        }
    }
    catch { }

    # Slow path: skip a banner or log lines before the payload.
    $starts = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $trimmed.Length; $i++) {
        $ch = $trimmed[$i]
        if ($ch -eq '{' -or $ch -eq '[') {
            $starts.Add($i)
            if ($starts.Count -ge 40) { break }
        }
    }

    foreach ($start in $starts) {
        $tail = $trimmed.Substring($start)
        $endObj = $tail.LastIndexOf('}')
        $endArr = $tail.LastIndexOf(']')
        $end = $endObj
        if ($endArr -gt $end) { $end = $endArr }
        if ($end -lt 0) { continue }

        $candidate = $tail.Substring(0, $end + 1)
        try {
            $parsed = ConvertFrom-Json -InputObject $candidate -ErrorAction Stop
            if ($parsed -is [System.Management.Automation.PSCustomObject] -or $parsed -is [array]) {
                return $parsed
            }
        }
        catch { }
    }

    return $null
}

function Get-AgentList {
    param($Parsed)

    if ($null -eq $Parsed) { return @() }
    if ($Parsed -is [array]) { return @($Parsed) }

    $topNames = @($Parsed.PSObject.Properties.Name)

    if ($topNames -contains 'agents') {
        $container = $Parsed.agents
        if ($null -eq $container) { return @() }
        if ($container -is [array]) { return @($container) }

        $list = @()
        foreach ($prop in $container.PSObject.Properties) {
            $agent = $prop.Value
            if ($null -eq $agent -or $agent -is [string]) { continue }
            if (-not (@($agent.PSObject.Properties.Name) -contains 'id')) {
                $agent | Add-Member -NotePropertyName id -NotePropertyValue $prop.Name -Force
            }
            $list += $agent
        }
        return $list
    }

    if ($topNames -contains 'id' -or $topNames -contains 'name') { return @($Parsed) }

    # Map form: { "orchestrator": { ... }, ... }
    $mapList = @()
    foreach ($prop in $Parsed.PSObject.Properties) {
        $agent = $prop.Value
        if ($null -eq $agent -or $agent -is [string]) { continue }
        if (-not (@($agent.PSObject.Properties.Name) -contains 'id')) {
            $agent | Add-Member -NotePropertyName id -NotePropertyValue $prop.Name -Force
        }
        $mapList += $agent
    }
    return $mapList
}

function Get-AgentId {
    param($Agent)
    if ($null -eq $Agent) { return $null }
    $names = @($Agent.PSObject.Properties.Name)
    if ($names -contains 'id' -and -not [string]::IsNullOrWhiteSpace([string]$Agent.id)) {
        return [string]$Agent.id
    }
    if ($names -contains 'name' -and -not [string]::IsNullOrWhiteSpace([string]$Agent.name)) {
        return [string]$Agent.name
    }
    return $null
}

function Get-PermissionEffect {
    param($Agent, [string]$Action)

    if ($null -eq $Agent) { return $null }
    $permProp = $Agent.PSObject.Properties['permissions']
    if ($null -eq $permProp) { return $null }

    $perms = $permProp.Value
    if ($null -eq $perms) { return $null }

    # List form: [ { action, resource, effect }, ... ]
    if ($perms -is [array]) {
        foreach ($rule in $perms) {
            if ($null -eq $rule) { continue }
            $ruleNames = @($rule.PSObject.Properties.Name)
            if (-not ($ruleNames -contains 'action')) { continue }

            $ruleAction = [string]$rule.action
            $ruleEffect = ''
            if ($ruleNames -contains 'effect') { $ruleEffect = [string]$rule.effect }
            if ($ruleEffect -ne 'deny') { continue }

            $ruleResource = '*'
            if ($ruleNames -contains 'resource') { $ruleResource = [string]$rule.resource }

            $actionMatches = ($ruleAction -eq $Action -or $ruleAction -eq '*' -or $ruleAction -eq 'all')
            $resourceMatches = ($ruleResource -eq '*' -or $ruleResource -eq '')
            if ($actionMatches -and $resourceMatches) { return 'deny' }
        }
        return $null
    }

    if ($perms -is [string]) {
        if ($perms -eq 'deny') { return 'deny' }
        return $null
    }

    # Map form: { "edit": { "*": "deny" }, ... }
    $names = @($perms.PSObject.Properties.Name)

    if ($names -contains '*') {
        $starNode = $perms.'*'
        if ($starNode -is [string] -and $starNode -eq 'deny') { return 'deny' }
    }

    if (-not ($names -contains $Action)) { return $null }

    $node = $perms.$Action
    if ($null -eq $node) { return $null }
    if ($node -is [string]) {
        if ($node -eq 'deny') { return 'deny' }
        return $null
    }

    $inner = $node.PSObject.Properties['*']
    if ($null -ne $inner -and [string]$inner.Value -eq 'deny') { return 'deny' }
    return $null
}

# --- run -------------------------------------------------------------------

$previousEap = $ErrorActionPreference
$previousOutputEncoding = [Console]::OutputEncoding
$rawOutput = $null
$exitCode = $null

try {
    $ErrorActionPreference = 'Continue'
    # OpenCode emits UTF-8. Force the console decoder to UTF-8 so a CP936
    # (or other non-UTF-8) console does not corrupt JSON that contains CJK.
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
    $rawOutput = & $OpenCode debug agents 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
}
catch {
    Write-Host "FAIL: could not run '$OpenCode debug agents'." -ForegroundColor Red
    Write-Host "      $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "      Pass the executable with -OpenCode <path> if it is not on PATH."
    exit 2
}
finally {
    try { [Console]::OutputEncoding = $previousOutputEncoding } catch { }
    $ErrorActionPreference = $previousEap
}

if ($null -ne $exitCode -and $exitCode -ne 0) {
    Write-Host "FAIL: '$OpenCode debug agents' exited with code $exitCode." -ForegroundColor Red
    $preview = (Remove-Ansi ([string]$rawOutput)).Trim()
    if ($preview.Length -gt 800) { $preview = $preview.Substring(0, 800) + '...' }
    Write-Host $preview
    exit 2
}

$cleanOutput = Remove-Ansi ([string]$rawOutput)
$parsed = ConvertFrom-JsonLoose -Text $cleanOutput

if ($null -eq $parsed) {
    Write-Host "FAIL: could not parse JSON from 'debug agents'." -ForegroundColor Red
    $preview = $cleanOutput.Trim()
    if ($preview.Length -gt 800) { $preview = $preview.Substring(0, 800) + '...' }
    Write-Host $preview
    exit 2
}

$agents = @(Get-AgentList -Parsed $parsed)
$byId = @{}
foreach ($agent in $agents) {
    $id = Get-AgentId -Agent $agent
    if (-not [string]::IsNullOrWhiteSpace($id)) { $byId[$id] = $agent }
}

Write-Host "OpenCode debug agents: $($agents.Count) agent(s) reported."
Write-Host ''

# Presence
$missing = @()
foreach ($name in $requiredAgents) {
    if ($byId.ContainsKey($name)) {
        Write-Host ("  ok    {0}" -f $name)
    }
    else {
        Write-Host ("  FAIL  {0} (missing)" -f $name) -ForegroundColor Red
        $missing += $name
        $failures.Add("agent '$name' is missing")
    }
}

Write-Host ''

# Permissions
foreach ($check in $requiredDenials) {
    $label = "$($check.Agent): $($check.Action):* = deny"
    if (-not $byId.ContainsKey($check.Agent)) {
        # Already reported as missing; do not double count.
        Write-Host ("  skip  {0}" -f $label)
        continue
    }

    $effect = Get-PermissionEffect -Agent $byId[$check.Agent] -Action $check.Action
    if ($effect -eq 'deny') {
        Write-Host ("  ok    {0}" -f $label)
    }
    else {
        $actual = 'none'
        if ($null -ne $effect -and $effect -ne '') { $actual = $effect }
        Write-Host ("  FAIL  {0} (got: {1})" -f $label, $actual) -ForegroundColor Red
        $failures.Add("$($check.Agent) does not deny $($check.Action):* (got: $actual)")
    }
}

Write-Host ''

if ($failures.Count -eq 0) {
    Write-Host 'PASS: all agents present and required denials in place.' -ForegroundColor Green
    exit 0
}

Write-Host ("FAIL: {0} problem(s)." -f $failures.Count) -ForegroundColor Red
foreach ($failure in $failures) { Write-Host ("  - {0}" -f $failure) -ForegroundColor Red }
exit 1
