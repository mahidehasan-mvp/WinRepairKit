# WinRepairKit - Public Cmdlet: Invoke-WinRepairPlan
# Generates actionable repair plans for detected issues

function Invoke-WinRepairPlan {
    <#
    .SYNOPSIS
        Generates step-by-step repair plans for modules with detected issues.
    #>
    [CmdletBinding()]
    [OutputType([RepairPlan[]])]
    param(
        [Parameter(Position = 0)]
        [string]$Module,

        [Parameter(ValueFromPipeline = $true)]
        [RepairResult[]]$ScanResults
    )

    if (-not $ScanResults) {
        $ScanResults = Invoke-WinRepairScan -Module $Module
    }

    $plans = [System.Collections.Generic.List[RepairPlan]]::new()

    foreach ($sr in $ScanResults) {
        $modName = $sr.ModuleName
        $planFunction = "Build-$($modName)Plan"

        if (Get-Command -Name $planFunction -ErrorAction SilentlyContinue) {
            try {
                $plan = & $planFunction -ScanResult $sr
                $plans.Add($plan)
            }
            catch {
                $errDetail = $_.ToString()
                Write-RepairLog -Message "Failed to build plan for module $($modName) - Error: $($errDetail)" -Level 'ERROR' -Category 'PLAN' -ModuleName $modName
            }
        }
        else {
            Write-RepairLog -Message "Plan builder function '$planFunction' not found." -Level 'WARN' -Category 'PLAN' -ModuleName $modName
        }
    }

    return $plans.ToArray()
}
