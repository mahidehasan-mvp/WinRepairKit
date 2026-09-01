# WinRepairKit Module Development Guide

Creating a new repair module (e.g. `TempFiles`, `SystemFiles`, `WindowsUpdate`) is plug-and-play.

---

## 1. Directory Structure

Create a folder in `src/Engine/Modules/<ModuleName>/`:

```
src/Engine/Modules/MyModule/
├── MyModule.psd1              # Module manifest
├── Test-MyModule.ps1          # Scan logic (returns RepairResult)
├── Build-MyModulePlan.ps1     # Plan builder (returns RepairPlan)
├── Export-MyModuleSnapshot.ps1# Snapshot capture (optional)
└── Repair-MyModule.ps1        # Fix logic (supports -DryRun, -ConfirmFix)
```

---

## 2. Manifest (`MyModule.psd1`)

```powershell
@{
    ModuleName        = 'MyModule'
    DisplayName       = 'My Module Display Name'
    Version           = '0.1.0'
    MinimumOSVersion  = '10.0.17763'
    SupportsScan      = $true
    SupportsPlan      = $true
    SupportsRepair    = $true
    SupportsDryRun    = $true
    RequiresElevation = $false
    MaxRiskLevel      = 'Elevated'     # Safe | Elevated | Destructive
    SupportsSnapshot  = $true
    SupportsRollback  = $false
    DataDestructive   = $false
    Description       = 'Description of what this module detects and fixes'
    Author            = 'Contributor Name'
}
```

---

## 3. Function Signatures

### Scan: `Test-MyModule.ps1`
```powershell
function Test-MyModule {
    [CmdletBinding()]
    [OutputType([RepairResult])]
    param()

    $result = [RepairResult]::new()
    $result.ModuleName = "MyModule"
    # Inspect system and populate $result.Findings
    return $result
}
```

### Plan: `Build-MyModulePlan.ps1`
```powershell
function Build-MyModulePlan {
    [CmdletBinding()]
    [OutputType([RepairPlan])]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [RepairResult]$ScanResult
    )

    $plan = [RepairPlan]::new()
    $plan.ModuleName = "MyModule"
    # Add [PlanStep] items to $plan
    return $plan
}
```

### Repair: `Repair-MyModule.ps1`
```powershell
function Repair-MyModule {
    [CmdletBinding()]
    [OutputType([RepairResult])]
    param(
        [RepairResult]$ScanResult,
        [RepairPlan]$Plan,
        [switch]$DryRun,
        [switch]$ConfirmFix
    )

    # 1. Evaluate safety
    # 2. Check DryRun
    # 3. Snapshot state
    # 4. Execute fixes
    # 5. Invoke-PostRepairVerify
}
```
