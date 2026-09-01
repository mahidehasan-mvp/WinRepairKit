# WinRepairKit - Public Cmdlet: Invoke-WinRepairFix
# Executes repairs for modules following safety contracts and dry-run requirements

function Invoke-WinRepairFix {
    <#
    .SYNOPSIS
        Executes repairs for modules with verified safety plans and user consent.
    #>
    [CmdletBinding()]
    [OutputType([RepairResult[]])]
    param(
        [Parameter(Position = 0)]
        [string]$Module,

        [Parameter()]
        [switch]$DryRun,

        [Parameter()]
        [switch]$ConfirmFix,

        [Parameter()]
        [hashtable]$ModuleParameters = @{}
    )

    $modules = Get-WinRepairModules -Name $Module
    if ($modules.Count -eq 0) {
        Write-RepairLog -Message "No matching modules found for repair query '$Module'." -Level 'WARN' -Category 'REPAIR'
        return @()
    }

    $results = [System.Collections.Generic.List[RepairResult]]::new()

    foreach ($m in $modules) {
        $repairFunction = "Repair-$($m.ModuleName)"
        if (Get-Command -Name $repairFunction -ErrorAction SilentlyContinue) {
            try {
                $params = if ($ModuleParameters.ContainsKey($m.ModuleName)) { $ModuleParameters[$m.ModuleName] } else { @{} }
                $modResult = & $repairFunction -DryRun:$DryRun -ConfirmFix:$ConfirmFix @params
                $results.Add($modResult)
            }
            catch {
                Write-RepairLog -Message "Repair error in module $($m.ModuleName): $_" -Level 'ERROR' -Category 'REPAIR' -ModuleName $m.ModuleName
                $errResult = [RepairResult]::new()
                $errResult.ModuleName = $m.ModuleName
                $errResult.Status = [RepairStatus]::Error
                $results.Add($errResult)
            }
        }
        else {
            Write-RepairLog -Message "Repair function '$repairFunction' not found." -Level 'WARN' -Category 'REPAIR' -ModuleName $m.ModuleName
        }
    }

    return $results.ToArray()
}
