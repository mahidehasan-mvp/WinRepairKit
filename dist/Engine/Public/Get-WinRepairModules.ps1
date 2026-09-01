# WinRepairKit - Public Cmdlet: Get-WinRepairModules
# Discovers and lists available repair modules and their metadata

function Get-WinRepairModules {
    <#
    .SYNOPSIS
        Retrieves all available WinRepairKit repair modules and their capability manifests.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Position = 0)]
        [string]$Name
    )

    $engineRoot = Split-Path -Path $PSScriptRoot -Parent
    $modulesDir = Join-Path -Path $engineRoot -ChildPath "Modules"

    if (-not (Test-Path -LiteralPath $modulesDir)) {
        return @()
    }

    $moduleDirs = Get-ChildItem -LiteralPath $modulesDir -Directory
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($dir in $moduleDirs) {
        $manifestPath = Join-Path -Path $dir.FullName -ChildPath "$($dir.Name).psd1"
        if (Test-Path -LiteralPath $manifestPath) {
            try {
                $meta = $null
                if (Get-Command -Name 'Import-PowerShellDataFile' -ErrorAction SilentlyContinue) {
                    $meta = Import-PowerShellDataFile -Path $manifestPath -ErrorAction SilentlyContinue
                }
                if (-not $meta) {
                    $raw = Get-Content -LiteralPath $manifestPath -Raw
                    $meta = Invoke-Expression $raw
                }

                if ($meta -and (-not $Name -or $meta.ModuleName -like "*$Name*" -or $dir.Name -like "*$Name*")) {
                    $obj = [PSCustomObject]@{
                        ModuleName        = $meta.ModuleName
                        DisplayName       = $meta.DisplayName
                        Version           = $meta.Version
                        MinimumOSVersion  = $meta.MinimumOSVersion
                        SupportsScan      = [bool]$meta.SupportsScan
                        SupportsPlan      = [bool]$meta.SupportsPlan
                        SupportsRepair    = [bool]$meta.SupportsRepair
                        SupportsDryRun    = [bool]$meta.SupportsDryRun
                        RequiresElevation = [bool]$meta.RequiresElevation
                        MaxRiskLevel      = $meta.MaxRiskLevel
                        SupportsSnapshot  = [bool]$meta.SupportsSnapshot
                        DataDestructive   = [bool]$meta.DataDestructive
                        Description       = $meta.Description
                        DirectoryPath     = $dir.FullName
                    }
                    $results.Add($obj)
                }
            }
            catch {
                $errDetail = $_.ToString()
                Write-RepairLog -Message "Failed to load manifest at $($manifestPath) - Error: $($errDetail)" -Level 'WARN' -Category 'SYSTEM'
            }
        }
    }

    return $results.ToArray()
}
