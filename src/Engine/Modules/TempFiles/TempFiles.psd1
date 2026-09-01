@{
    ModuleName        = 'TempFiles'
    DisplayName       = 'Temporary Files & Cache Health'
    Version           = '0.1.0'
    MinimumOSVersion  = '10.0.17763'
    SupportsScan      = $true
    SupportsPlan      = $true
    SupportsRepair    = $true
    SupportsDryRun    = $true
    RequiresElevation = $false
    MaxRiskLevel      = 'Elevated'
    SupportsSnapshot  = $true
    SupportsRollback  = $false
    DataDestructive   = $false
    Description       = 'Contextual scanner and safe cleaner for user temp, system temp, crash dumps, and Windows Update cache'
    Author            = 'WinRepairKit Contributors'
}
