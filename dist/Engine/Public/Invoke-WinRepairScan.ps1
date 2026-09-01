# WinRepairKit - Public Cmdlet: Invoke-WinRepairScan
# Scans all or selected modules for system anomalies

function Invoke-WinRepairScan {
    <#
    .SYNOPSIS
        Executes diagnostic scans across WinRepairKit modules.
    #>
    [CmdletBinding()]
    [OutputType([RepairResult[]])]
    param(
        [Parameter(Position = 0)]
        [string]$Module,

        [Parameter()]
        [hashtable]$ModuleParameters = @{}
    )

    $modules = Get-WinRepairModules -Name $Module
    if ($modules.Count -eq 0) {
        Write-RepairLog -Message "No matching modules found for scan query '$Module'." -Level 'WARN' -Category 'SCAN'
        return @()
    }

    $results = [System.Collections.Generic.List[RepairResult]]::new()

    foreach ($m in $modules) {
        Write-RepairLog -Message "Scanning module: $($m.DisplayName) ($($m.ModuleName))..." -Level 'INFO' -Category 'SCAN' -ModuleName $m.ModuleName

        $scanFunction = "Test-$($m.ModuleName)"
        if (Get-Command -Name $scanFunction -ErrorAction SilentlyContinue) {
            try {
                $params = if ($ModuleParameters.ContainsKey($m.ModuleName)) { $ModuleParameters[$m.ModuleName] } else { @{} }
                $modOutput = & $scanFunction @params
                
                # Find the RepairResult object if multiple outputs occurred
                $modResult = $null
                if ($modOutput -is [RepairResult]) {
                    $modResult = $modOutput
                }
                elseif ($modOutput -is [System.Array]) {
                    foreach ($item in $modOutput) {
                        if ($item -is [RepairResult]) {
                            $modResult = $item
                            break
                        }
                    }
                }

                if (-not $modResult) {
                    $modResult = ConvertTo-RepairResult -InputObject $modOutput
                }

                $results.Add($modResult)
            }
            catch {
                $errDetail = $_.ToString()
                Write-RepairLog -Message "Scan error in module $($m.ModuleName) - Error: $($errDetail)" -Level 'ERROR' -Category 'SCAN' -ModuleName $m.ModuleName
                $errResult = [RepairResult]::new()
                $errResult.ModuleName = $m.ModuleName
                $errResult.Status = [RepairStatus]::Error
                $results.Add($errResult)
            }
        }
        else {
            Write-RepairLog -Message "Scan function '$scanFunction' not found." -Level 'WARN' -Category 'SCAN' -ModuleName $m.ModuleName
        }
    }

    return $results.ToArray()
}
