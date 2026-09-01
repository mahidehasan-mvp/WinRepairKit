@{
    ModuleName        = 'RecycleBin'
    DisplayName       = 'Recycle Bin Health & Permissions'
    Version           = '0.1.0'
    MinimumOSVersion  = '10.0.17763'
    SupportsScan      = $true
    SupportsPlan      = $true
    SupportsRepair    = $true
    SupportsDryRun    = $true
    RequiresElevation = $false
    MaxRiskLevel      = 'Destructive'
    SupportsSnapshot  = $true
    SupportsRollback  = $false
    DataDestructive   = $true
    Description       = 'Detects and repairs corrupted, inaccessible, or oversized Recycle Bin entries with permission anomalies'
    Author            = 'WinRepairKit Contributors'
}
