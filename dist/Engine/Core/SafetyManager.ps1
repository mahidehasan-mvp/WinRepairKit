# WinRepairKit - Safety Manager
# Enforces safety contracts, dry-run simulation, and consent verification

function Test-PlanSafety {
    <#
    .SYNOPSIS
        Evaluates whether a plan is safe to execute in the current context.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [RepairPlan]$Plan,

        [Parameter()]
        [switch]$DryRun,

        [Parameter()]
        [switch]$Confirmed
    )

    $isElevated = Test-IsElevated
    $canExecute = $true
    $blockReasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    # Rule 1: Elevation check
    if ($Plan.RequiresAdmin -and -not $isElevated -and -not $DryRun) {
        $canExecute = $false
        $blockReasons.Add("Plan requires Administrator privileges, but current session is not elevated.")
    }

    # Rule 2: Explicit confirmation check for destructive plans
    if ($Plan.MaxRiskLevel -eq [RiskLevel]::Destructive -and -not $Confirmed -and -not $DryRun) {
        $canExecute = $false
        $blockReasons.Add("Plan involves Destructive actions and requires explicit user confirmation (-ConfirmFix).")
    }

    # Rule 3: Elevated risk notification
    if ($Plan.MaxRiskLevel -eq [RiskLevel]::Elevated -and -not $Confirmed -and -not $DryRun) {
        $warnings.Add("Plan makes Elevated system changes.")
    }

    # Rule 4: Data destruction warning
    if ($Plan.DataDestructive) {
        $warnings.Add("Permanent data removal: file contents cannot be restored from metadata snapshots.")
    }

    return [PSCustomObject]@{
        CanExecute   = $canExecute
        IsElevated   = $isElevated
        IsDryRun     = [bool]$DryRun
        IsConfirmed  = [bool]$Confirmed
        BlockReasons = $blockReasons
        Warnings     = $warnings
    }
}

function Assert-PlanExecutionAllowed {
    <#
    .SYNOPSIS
        Throws if the plan fails safety checks.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [RepairPlan]$Plan,

        [Parameter()]
        [switch]$DryRun,

        [Parameter()]
        [switch]$Confirmed
    )

    $safety = Test-PlanSafety -Plan $Plan -DryRun:$DryRun -Confirmed:$Confirmed

    if (-not $safety.CanExecute) {
        $reasonsStr = $safety.BlockReasons -join "`n - "
        $msg = "Execution blocked by Safety Manager:`n - $reasonsStr"
        Write-RepairLog -Message $msg -Level 'ERROR' -Category 'CONSENT' -ModuleName $Plan.ModuleName
        throw [System.InvalidOperationException]::new($msg)
    }
}
