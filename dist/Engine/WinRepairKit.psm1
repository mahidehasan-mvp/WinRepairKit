# WinRepairKit - Root Module Loader
# Dot-sources Core, Private helpers, pluggable Modules, and Public Cmdlets

$moduleRoot = $PSScriptRoot

# 1. Load Core Engine
$coreFiles = @(
    "Core\Types.ps1",
    "Core\Logger.ps1",
    "Core\ElevationManager.ps1",
    "Core\SnapshotManager.ps1",
    "Core\PlanManager.ps1",
    "Core\SafetyManager.ps1",
    "Core\VerificationManager.ps1",
    "Core\TransactionManager.ps1",
    "Core\SupportBundleManager.ps1"
)

foreach ($file in $coreFiles) {
    $fullPath = Join-Path -Path $moduleRoot -ChildPath $file
    if (Test-Path -LiteralPath $fullPath) {
        . $fullPath
    }
}

# 2. Load Private Helpers
$privateDir = Join-Path -Path $moduleRoot -ChildPath "Private"
if (Test-Path -LiteralPath $privateDir) {
    $privateScripts = Get-ChildItem -LiteralPath $privateDir -Filter "*.ps1"
    foreach ($script in $privateScripts) {
        . $script.FullName
    }
}

# 3. Load Pluggable Modules
$modulesDir = Join-Path -Path $moduleRoot -ChildPath "Modules"
if (Test-Path -LiteralPath $modulesDir) {
    $moduleScripts = Get-ChildItem -LiteralPath $modulesDir -Recurse -Filter "*.ps1"
    foreach ($script in $moduleScripts) {
        . $script.FullName
    }
}

# 4. Load Public Cmdlets
$publicDir = Join-Path -Path $moduleRoot -ChildPath "Public"
if (Test-Path -LiteralPath $publicDir) {
    $publicScripts = Get-ChildItem -LiteralPath $publicDir -Filter "*.ps1"
    foreach ($script in $publicScripts) {
        . $script.FullName
    }
}

# 5. Export Functions
$exportedFunctions = @(
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

Export-ModuleMember -Function $exportedFunctions
