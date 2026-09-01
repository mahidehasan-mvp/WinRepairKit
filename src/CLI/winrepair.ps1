<#
.SYNOPSIS
    WinRepairKit CLI - Windows Repair & Maintenance Toolkit
    
.DESCRIPTION
    Safety-first diagnostic, planning, repair, and verification tool for Windows 10 & 11.
    
.EXIT CODES
    0 = Success / Healthy
    1 = Problems detected
    2 = Repair failed
    3 = Repair partially succeeded
    4 = User cancelled / Confirmation missing
    5 = Elevation required / denied
    6 = Stale plan (fingerprint mismatch)
    7 = Invalid arguments
    8 = Internal error
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('scan', 'plan', 'repair', 'verify', 'modules', 'list', 'snapshots', 'transactions', 'report', 'help')]
    [string]$Command = 'scan',

    [Parameter(Position = 1)]
    [string]$Module,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [Alias('y', 'confirm', 'Force')]
    [switch]$ConfirmFix,

    [Parameter()]
    [switch]$Json,

    [Parameter()]
    [switch]$Elevate,

    [Parameter()]
    [string]$DriveLetter,

    [Parameter()]
    [ValidateSet('Text', 'Json', 'Html')]
    [string]$Format = 'Text'
)

# 1. Self-Elevation if requested
if ($Elevate -and -not (Test-IsElevated -ErrorAction SilentlyContinue)) {
    $cliPath = $MyInvocation.MyCommand.Definition
    $argsToPass = @($Command)
    if ($Module) { $argsToPass += @("-Module", $Module) }
    if ($DryRun) { $argsToPass += "-DryRun" }
    if ($ConfirmFix) { $argsToPass += "-ConfirmFix" }
    if ($Json) { $argsToPass += "-Json" }
    if ($DriveLetter) { $argsToPass += @("-DriveLetter", $DriveLetter) }
    
    $exitCode = Invoke-ElevatedCli -CliScriptPath $cliPath -Arguments $argsToPass -Wait
    exit $exitCode
}

# 2. Import Module Engine & Types
$cliDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$engineDir = Join-Path -Path (Split-Path -Path $cliDir -Parent) -ChildPath "Engine"
$typesPs1 = Join-Path -Path $engineDir -ChildPath "Core\Types.ps1"
$enginePsd1 = Join-Path -Path $engineDir -ChildPath "WinRepairKit.psd1"

if (Test-Path -LiteralPath $typesPs1) {
    . $typesPs1
}

if (Test-Path -LiteralPath $enginePsd1) {
    Import-Module -Name $enginePsd1 -Force -Global -DisableNameChecking | Out-Null
}
else {
    Write-Error "WinRepairKit engine not found at $enginePsd1"
    exit 8
}

# If JSON mode is enabled, suppress console Write-Host logs
if ($Json) {
    $global:WinRepairNoConsole = $true
}

# 3. Banner
function Show-Banner {
    if ($Json) { return }
    Write-Host -ForegroundColor Cyan @"
===============================================================================
  WinRepairKit v0.1.0 - Windows 10 & 11 Repair & Maintenance Toolkit
  Diagnose -> Explain -> Plan -> Repair -> Verify
===============================================================================
"@
    $elevated = Test-IsElevated
    if ($elevated) {
        Write-Host -ForegroundColor DarkGreen "  [Privilege: Elevated Administrator]"
    }
    else {
        Write-Host -ForegroundColor DarkYellow "  [Privilege: Standard User (Elevate for destructive repairs)]"
    }
    Write-Host ""
}

# 4. Check for Interrupted Transactions on startup
$interruptedTx = Get-InterruptedTransactions
if ($interruptedTx.Count -gt 0 -and -not $Json) {
    Write-Host -ForegroundColor Red "==============================================================================="
    Write-Host -ForegroundColor Red "  WARNING: INCOMPLETE REPAIR TRANSACTION DETECTED"
    Write-Host -ForegroundColor Red "==============================================================================="
    foreach ($itx in $interruptedTx) {
        Write-Host "  Transaction ID      : $($itx.TransactionId)"
        Write-Host "  Module              : $($itx.ModuleName)"
        Write-Host "  Started At          : $($itx.StartedAtUtc)"
        Write-Host "  Last Completed Step : $($itx.LastCompletedStep)"
        Write-Host ""
    }
    Write-Host "  Note: Incomplete transactions are NOT automatically resumed."
    Write-Host "  Please perform a fresh scan to re-verify current system health."
    Write-Host "-------------------------------------------------------------------------------"
    Write-Host ""
}

# 5. Command Router
switch ($Command) {
    'help' {
        Show-Banner
        Write-Host @"
Usage: winrepair.ps1 <command> [options]

Commands:
  scan          [Module]       Scan all or specific modules for issues
  plan          [Module]       Generate a reviewable step-by-step repair plan
  repair        [Module]       Execute repairs (requires -ConfirmFix or -DryRun)
  verify        [Module]       Re-scan and verify that issues are resolved
  modules                      List available diagnostic & repair modules
  snapshots     [Module]       List saved pre-repair state snapshots
  transactions                 List active and interrupted repair transactions
  report                       Generate system health report (Text, Json, Html)

Options:
  -Module <name>            Target specific module (e.g. RecycleBin, TempFiles)
  -DryRun                   Simulate actions without making any system changes
  -ConfirmFix (-y, -Force)  Explicitly confirm and authorize repair execution
  -Json                     Output results as machine-readable JSON
  -Elevate                  Relaunch CLI with Administrator UAC prompt
  -DriveLetter <C:>         Target a specific drive letter
  -Format <Text|Json|Html>  Output format for reports

Exit Codes:
  0 = Success / Healthy
  1 = Problems detected (on scan)
  2 = Repair failed
  3 = Repair partially succeeded
  4 = User cancelled / Confirmation missing
  5 = Elevation required / denied
  6 = Stale plan (fingerprint mismatch)
  7 = Invalid arguments
  8 = Internal error
"@
        exit 0
    }

    'modules' {
        if (-not $Json) { Show-Banner }
        $mods = Get-WinRepairModules -Name $Module
        if ($Json) {
            $mods | ConvertTo-Json -Depth 4
        }
        else {
            Write-Host -ForegroundColor Yellow "Available Modules:"
            Write-Host "-------------------------------------------------------------------------------"
            foreach ($m in $mods) {
                Write-Host -ForegroundColor Green "* $($m.DisplayName) [$($m.ModuleName)] (v$($m.Version))"
                Write-Host "  $($m.Description)"
                Write-Host "  Max Risk: $($m.MaxRiskLevel) | Requires Admin: $($m.RequiresElevation) | Supports DryRun: $($m.SupportsDryRun)"
                Write-Host ""
            }
        }
        exit 0
    }

    'list' {
        & $MyInvocation.MyCommand.Definition 'modules' -Module $Module -Json:$Json
        exit $LASTEXITCODE
    }

    'snapshots' {
        if (-not $Json) { Show-Banner }
        $snaps = Get-RepairSnapshots -ModuleName $Module
        if ($Json) {
            $snaps | ConvertTo-Json -Depth 4
        }
        else {
            Write-Host -ForegroundColor Yellow "Saved State Snapshots:"
            Write-Host "-------------------------------------------------------------------------------"
            if ($snaps.Count -eq 0) {
                Write-Host "  (No snapshots recorded yet)"
            }
            else {
                foreach ($s in $snaps) {
                    Write-Host -ForegroundColor Green "* $($s.SnapshotId) [$($s.ModuleName)]"
                    Write-Host "  Recorded: $($s.TimestampUtc) | Items: $($s.ItemCount)"
                    Write-Host "  Location: $($s.Path)"
                    Write-Host ""
                }
            }
        }
        exit 0
    }

    'transactions' {
        if (-not $Json) { Show-Banner }
        $txList = Get-InterruptedTransactions
        if ($Json) {
            $txList | ConvertTo-Json -Depth 4
        }
        else {
            Write-Host -ForegroundColor Yellow "Incomplete / Interrupted Transactions:"
            Write-Host "-------------------------------------------------------------------------------"
            if ($txList.Count -eq 0) {
                Write-Host "  (No interrupted transactions detected. Transaction history is clean.)"
            }
            else {
                foreach ($t in $txList) {
                    Write-Host -ForegroundColor Red "* $($t.TransactionId) [$($t.ModuleName)]"
                    Write-Host "  Started: $($t.StartedAtUtc) | Last Step: $($t.LastCompletedStep)"
                    Write-Host "  Location: $($t.FilePath)"
                    Write-Host ""
                }
            }
        }
        exit 0
    }

    'scan' {
        if (-not $Json) { Show-Banner }
        $modParams = @{}
        if ($DriveLetter) {
            $modParams['RecycleBin'] = @{ DriveLetter = $DriveLetter }
        }

        $results = Invoke-WinRepairScan -Module $Module -ModuleParameters $modParams

        if ($Json) {
            $results | ConvertTo-Json -Depth 6
        }
        else {
            Write-Host ""
            Write-Host -ForegroundColor Yellow "==============================================================================="
            Write-Host -ForegroundColor Yellow "  SCAN RESULTS"
            Write-Host -ForegroundColor Yellow "==============================================================================="

            $totalProblems = 0
            foreach ($res in $results) {
                $statusStr = "$($res.Status)"
                $statusColor = if ($statusStr -eq 'Healthy') { 'Green' } else { 'Red' }
                Write-Host -ForegroundColor $statusColor "Module: $($res.ModuleName) - $statusStr"
                
                if ($res.Findings.Count -gt 0) {
                    $totalProblems += $res.Findings.Count
                    foreach ($f in $res.Findings) {
                        $sevStr = "$($f.Severity)"
                        $sevColor = switch ($sevStr) {
                            'Critical' { 'Magenta' }
                            'Error'    { 'Red' }
                            'Warning'  { 'Yellow' }
                            Default    { 'Cyan' }
                        }
                        Write-Host -ForegroundColor $sevColor "  [WARN] [$($f.Id)] $($f.Title)"
                        if ($f.Detail) { Write-Host "    $($f.Detail)" }
                        if ($f.Path) { Write-Host "    Target: $($f.Path)" }
                    }
                }
                else {
                    Write-Host -ForegroundColor Green "  [OK] No problems detected. System component is healthy."
                }
                Write-Host ""
            }

            if ($totalProblems -gt 0) {
                Write-Host -ForegroundColor Yellow "Next steps:"
                Write-Host "  1. Review repair plan:  .\winrepair.ps1 plan $(if ($Module) { $Module })"
                Write-Host "  2. Preview dry-run:     .\winrepair.ps1 repair $(if ($Module) { $Module }) -DryRun"
                Write-Host "  3. Execute repair:      .\winrepair.ps1 repair $(if ($Module) { $Module }) -ConfirmFix"
            }
            else {
                Write-Host -ForegroundColor Green "All scanned components are healthy!"
            }
        }

        $hasProblems = ($results | Where-Object { "$($_.Status)" -ne 'Healthy' }).Count -gt 0
        if ($hasProblems) { exit 1 } else { exit 0 }
    }

    'plan' {
        if (-not $Json) { Show-Banner }
        $plans = Invoke-WinRepairPlan -Module $Module

        if ($Json) {
            $plans | ConvertTo-Json -Depth 6
        }
        else {
            foreach ($p in $plans) {
                Write-Host (Format-RepairPlan -Plan $p)
            }
        }
        exit 0
    }

    'repair' {
        if (-not $Json) { Show-Banner }

        $modParams = @{}
        if ($DriveLetter) {
            $modParams['RecycleBin'] = @{ DriveLetter = $DriveLetter }
        }

        $results = Invoke-WinRepairFix -Module $Module -DryRun:$DryRun -ConfirmFix:$ConfirmFix -ModuleParameters $modParams

        if ($Json) {
            $results | ConvertTo-Json -Depth 6
        }
        else {
            Write-Host ""
            Write-Host -ForegroundColor Yellow "==============================================================================="
            Write-Host -ForegroundColor Yellow "  REPAIR & VERIFICATION REPORT"
            Write-Host -ForegroundColor Yellow "==============================================================================="

            foreach ($res in $results) {
                $statusStr = "$($res.Status)"
                $statusColor = switch ($statusStr) {
                    'RepairSucceeded' { 'Green' }
                    'Healthy'         { 'Green' }
                    'Skipped'         { 'Cyan' }
                    'RepairPartial'   { 'Yellow' }
                    'PlanInvalidated' { 'Magenta' }
                    Default           { 'Red' }
                }
                Write-Host -ForegroundColor $statusColor "Module: $($res.ModuleName) - Result: $statusStr"

                if ($res.Verification) {
                    $vColor = if ($res.Verification.Passed) { 'Green' } else { 'Yellow' }
                    Write-Host -ForegroundColor $vColor "Verification: $($res.Verification.Message)"
                }

                if ($res.Snapshot) {
                    Write-Host "State Snapshot: $($res.Snapshot.SnapshotId) ($($res.Snapshot.ItemCount) items recorded)"
                }

                Write-Host ""
            }
        }

        # Calculate Exit Code
        $anyPlanInvalidated = ($results | Where-Object { "$($_.Status)" -eq 'PlanInvalidated' }).Count -gt 0
        $anyFailed = ($results | Where-Object { "$($_.Status)" -eq 'RepairFailed' -or "$($_.Status)" -eq 'Error' }).Count -gt 0
        $anyPartial = ($results | Where-Object { "$($_.Status)" -eq 'RepairPartial' }).Count -gt 0

        if ($anyPlanInvalidated) { exit 6 }
        if ($anyFailed) { exit 2 }
        if ($anyPartial) { exit 3 }
        exit 0
    }

    'verify' {
        if (-not $Json) { Show-Banner }
        $results = Invoke-WinRepairScan -Module $Module
        if ($Json) {
            $results | ConvertTo-Json -Depth 6
        }
        else {
            Write-Host (Get-WinRepairReport -Results $results -Format 'Text')
        }
        $hasProblems = ($results | Where-Object { "$($_.Status)" -ne 'Healthy' }).Count -gt 0
        if ($hasProblems) { exit 1 } else { exit 0 }
    }

    'report' {
        $results = Invoke-WinRepairScan -Module $Module
        $reportStr = Get-WinRepairReport -Results $results -Format $Format
        Write-Output $reportStr
        exit 0
    }
}
