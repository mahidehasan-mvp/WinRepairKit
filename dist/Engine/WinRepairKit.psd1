@{
    RootModule           = 'WinRepairKit.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'e98a58a2-a0b4-4e2a-89a1-77114b7e8d19'
    Author               = 'WinRepairKit Contributors'
    CompanyName          = 'WinRepairKit'
    Copyright            = '(c) 2026 WinRepairKit Contributors. MIT License.'
    Description          = 'Transparent, safety-first Windows 10 & 11 diagnostic and repair toolkit.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    ScriptsToProcess     = @('Core\Types.ps1')

    FunctionsToExport    = @(
        'Invoke-WinRepairScan',
        'Invoke-WinRepairPlan',
        'Invoke-WinRepairFix',
        'Get-WinRepairReport',
        'Get-WinRepairModules',
        'Test-RecycleBin',
        'Build-RecycleBinPlan',
        'Repair-RecycleBin',
        'Export-RecycleBinSnapshot',
        'Test-TempFiles',
        'Build-TempFilesPlan',
        'Repair-TempFiles',
        'Export-TempFilesSnapshot',
        'Test-PlanSafety',
        'Format-RepairPlan',
        'Get-FindingFingerprint',
        'Test-PlanFingerprintMatch',
        'Start-RepairTransaction',
        'Update-RepairTransaction',
        'Complete-RepairTransaction',
        'Get-InterruptedTransactions',
        'Export-WinRepairSupportBundle',
        'Test-IsSafeTargetPath',
        'Test-IsElevated',
        'Write-RepairLog',
        'Get-RepairSnapshots',
        'Get-DriveRecycleBinInfo'
    )

    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags       = @('Windows', 'Repair', 'Diagnostics', 'RecycleBin', 'TempFiles', 'Maintenance', 'SysAdmin')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = 'https://github.com/winrepairkit/winrepairkit'
        }
    }
}
