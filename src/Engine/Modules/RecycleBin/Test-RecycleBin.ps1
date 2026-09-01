# WinRepairKit - RecycleBin Module: Scan
# Multi-signal detection of Recycle Bin permission anomalies and abnormal item buildup

function Test-RecycleBin {
    <#
    .SYNOPSIS
        Scans drives for Recycle Bin corruption, permission denial, and excessive buildup.
    #>
    [CmdletBinding()]
    [OutputType([RepairResult])]
    param(
        [Parameter()]
        [string]$DriveLetter,

        [Parameter()]
        [int]$LargeCountThreshold = 5000,

        [Parameter()]
        [int64]$LargeSizeThresholdBytes = 10GB
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-RepairLog -Message "Starting Recycle Bin scan..." -Level 'INFO' -Category 'SCAN' -ModuleName 'RecycleBin'

    $result = [RepairResult]::new()
    $result.ModuleName = "RecycleBin"
    $result.SupportsDryRun = $true
    $result.CanRepair = $true
    $result.StartedAt = [datetime]::UtcNow

    $driveInfos = Get-DriveRecycleBinInfo -DriveLetter $DriveLetter

    $hasPermissionIssue = $false
    $hasCorruptedRoot = $false
    $hasExcessiveBuildup = $false

    foreach ($drv in $driveInfos) {
        $driveLetterName = $drv.DriveLetter

        if (-not $drv.Exists) {
            continue
        }

        # Check 1: Root container accessibility & structure
        if (-not $drv.IsAccessible) {
            $hasCorruptedRoot = $true
            $finding = [Finding]::new()
            $finding.Id = "RB-003"
            $finding.Severity = [SeverityLevel]::Error
            $finding.Title = "Recycle Bin root container inaccessible on $driveLetterName"
            $finding.Detail = "The `$Recycle.Bin directory on $driveLetterName cannot be accessed due to permission denial or filesystem locks."
            $finding.Path = $drv.RecycleBinPath
            $finding.ExtraData = @{
                DriveLetter = $driveLetterName
                Errors      = $drv.AccessErrors
            }
            $result.Findings.Add($finding)
        }

        # Check 2: Inaccessible items / SID folders (Multi-signal confirmed)
        if ($drv.InaccessibleCount -gt 0 -or $drv.AccessErrors.Count -gt 0) {
            $hasPermissionIssue = $true
            $finding = [Finding]::new()
            $finding.Id = "RB-001"
            $finding.Severity = [SeverityLevel]::Warning
            $finding.Title = "$($drv.InaccessibleCount) inaccessible item(s) detected on $driveLetterName"
            $finding.Detail = "Permission locks prevent standard Windows deletion in $($drv.RecycleBinPath)."
            $finding.Path = $drv.RecycleBinPath
            $finding.FileCount = $drv.InaccessibleCount
            $finding.SizeBytes = $drv.InaccessibleBytes
            $finding.ExtraData = @{
                DriveLetter = $driveLetterName
                Errors      = $drv.AccessErrors
            }
            $result.Findings.Add($finding)
        }

        # Check 3: Large buildup
        if ($drv.TotalItemCount -gt $LargeCountThreshold -or $drv.TotalSizeBytes -gt $LargeSizeThresholdBytes) {
            $hasExcessiveBuildup = $true
            $finding = [Finding]::new()
            $finding.Id = "RB-002"
            $finding.Severity = [SeverityLevel]::Info
            $finding.Title = "Large Recycle Bin buildup on $driveLetterName ($($drv.TotalItemCount) items, $(Format-FileSize $drv.TotalSizeBytes))"
            $finding.Detail = "Recycle Bin contains a large volume of items that may cause explorer latency."
            $finding.Path = $drv.RecycleBinPath
            $finding.FileCount = $drv.TotalItemCount
            $finding.SizeBytes = $drv.TotalSizeBytes
            $finding.ExtraData = @{ DriveLetter = $driveLetterName }
            $result.Findings.Add($finding)
        }
    }

    $stopwatch.Stop()
    $result.DurationMs = $stopwatch.ElapsedMilliseconds
    $result.CompletedAt = [datetime]::UtcNow

    if ($result.Findings.Count -eq 0) {
        $result.Status = [RepairStatus]::Healthy
        $result.RiskLevel = [RiskLevel]::Safe
        $result.RequiresAdmin = $false
        $result.DataDestructive = $false
        Write-RepairLog -Message "Recycle Bin scan completed: All drives are healthy." -Level 'SUCCESS' -Category 'SCAN' -ModuleName 'RecycleBin'
    }
    else {
        $result.Status = [RepairStatus]::ProblemFound

        if ($hasCorruptedRoot -or $hasPermissionIssue) {
            $result.RiskLevel = [RiskLevel]::Destructive
            $result.RequiresAdmin = $true
            $result.DataDestructive = $true
            $result.Recommendations.Add("Reset permissions and remove inaccessible Recycle Bin entries")
        }
        else {
            $result.RiskLevel = [RiskLevel]::Elevated
            $result.RequiresAdmin = $false
            $result.DataDestructive = $true
            $result.Recommendations.Add("Perform safe Recycle Bin cleanup")
        }

        Write-RepairLog -Message "Recycle Bin scan completed: $($result.Findings.Count) problem(s) found." -Level 'WARN' -Category 'SCAN' -ModuleName 'RecycleBin' -Data @{
            FindingsCount = $result.Findings.Count
            DurationMs    = $result.DurationMs
        }
    }

    return $result
}
