# WinRepairKit - TempFiles Module: Scan
# Contextual diagnostics distinguishing safe removable cache from active/in-use installer files

function Test-TempFiles {
    <#
    .SYNOPSIS
        Scans user temp, system temp, crash dumps, and update cache with contextual in-use file detection.
    #>
    [CmdletBinding()]
    [OutputType([RepairResult])]
    param(
        [Parameter()]
        [int]$AgeHoursThreshold = 24
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-RepairLog -Message "Starting Temporary Files scan..." -Level 'INFO' -Category 'SCAN' -ModuleName 'TempFiles'

    $result = [RepairResult]::new()
    $result.ModuleName = "TempFiles"
    $result.SupportsDryRun = $true
    $result.CanRepair = $true
    $result.StartedAt = [datetime]::UtcNow

    $cutoffTime = (Get-Date).AddHours(-$AgeHoursThreshold)

    # Category 1: User Temp ($env:TEMP)
    $userTempPath = [System.IO.Path]::GetTempPath()
    if (Test-Path -LiteralPath $userTempPath) {
        $userTempFiles = @()
        $userTempInUse = 0
        $userTempEligibleSize = 0
        $userTempEligibleCount = 0

        try {
            $items = Get-ChildItem -LiteralPath $userTempPath -Recurse -Force -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                if ($item.PSIsContainer) { continue }

                # Check age
                if ($item.LastWriteTime -lt $cutoffTime) {
                    # Test if file is locked / in use
                    $isLocked = $false
                    try {
                        $stream = [System.IO.File]::Open($item.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
                        if ($stream) { $stream.Close() }
                    }
                    catch {
                        $isLocked = $true
                        $userTempInUse++
                    }

                    if (-not $isLocked) {
                        $userTempEligibleCount++
                        $userTempEligibleSize += $item.Length
                    }
                }
            }

            if ($userTempEligibleCount -gt 0) {
                $finding = [Finding]::new()
                $finding.Id = "TMP-001"
                $finding.Severity = [SeverityLevel]::Info
                $finding.Title = "User Temp buildup: $userTempEligibleCount file(s) older than $AgeHoursThreshold hrs ($(Format-FileSize $userTempEligibleSize))"
                $finding.Detail = "Safe temporary application cache in $userTempPath."
                $finding.Path = $userTempPath
                $finding.FileCount = $userTempEligibleCount
                $finding.SizeBytes = $userTempEligibleSize
                $finding.ExtraData = @{
                    EligibleCount = $userTempEligibleCount
                    LockedCount   = $userTempInUse
                    AgeHours      = $AgeHoursThreshold
                }
                $result.Findings.Add($finding)
            }
        }
        catch {}
    }

    # Category 2: Windows System Temp (C:\Windows\Temp)
    $sysTempPath = Join-Path -Path $env:SystemRoot -ChildPath "Temp"
    if (Test-Path -LiteralPath $sysTempPath) {
        $sysTempEligibleSize = 0
        $sysTempEligibleCount = 0

        try {
            $items = Get-ChildItem -LiteralPath $sysTempPath -Recurse -Force -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                if ($item.PSIsContainer) { continue }
                if ($item.LastWriteTime -lt $cutoffTime) {
                    $isLocked = $false
                    try {
                        $stream = [System.IO.File]::Open($item.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
                        if ($stream) { $stream.Close() }
                    }
                    catch {
                        $isLocked = $true
                    }

                    if (-not $isLocked) {
                        $sysTempEligibleCount++
                        $sysTempEligibleSize += $item.Length
                    }
                }
            }

            if ($sysTempEligibleCount -gt 0) {
                $finding = [Finding]::new()
                $finding.Id = "TMP-002"
                $finding.Severity = [SeverityLevel]::Info
                $finding.Title = "System Temp buildup: $sysTempEligibleCount file(s) ($(Format-FileSize $sysTempEligibleSize))"
                $finding.Detail = "Windows system temporary files in $sysTempPath."
                $finding.Path = $sysTempPath
                $finding.FileCount = $sysTempEligibleCount
                $finding.SizeBytes = $sysTempEligibleSize
                $result.Findings.Add($finding)
            }
        }
        catch {}
    }

    # Category 3: Crash Dumps (%LOCALAPPDATA%\CrashDumps & C:\Windows\Minidump)
    $crashDumpPaths = @(
        (Join-Path -Path $env:LOCALAPPDATA -ChildPath "CrashDumps"),
        (Join-Path -Path $env:SystemRoot -ChildPath "Minidump")
    )

    foreach ($cdPath in $crashDumpPaths) {
        if (Test-Path -LiteralPath $cdPath) {
            try {
                $dumps = Get-ChildItem -LiteralPath $cdPath -Filter "*.dmp" -ErrorAction SilentlyContinue
                if ($dumps.Count -gt 0) {
                    $totalDmpSize = ($dumps | Measure-Object -Property Length -Sum).Sum
                    $finding = [Finding]::new()
                    $finding.Id = "TMP-003"
                    $finding.Severity = [SeverityLevel]::Info
                    $finding.Title = "Crash Dumps detected: $($dumps.Count) dump file(s) ($(Format-FileSize $totalDmpSize))"
                    $finding.Detail = "Application crash dumps in $cdPath."
                    $finding.Path = $cdPath
                    $finding.FileCount = $dumps.Count
                    $finding.SizeBytes = $totalDmpSize
                    $result.Findings.Add($finding)
                }
            }
            catch {}
        }
    }

    # Category 4: Windows Update Download Cache (C:\Windows\SoftwareDistribution\Download)
    $wuDownloadPath = Join-Path -Path $env:SystemRoot -ChildPath "SoftwareDistribution\Download"
    if (Test-Path -LiteralPath $wuDownloadPath) {
        try {
            $wuFiles = Get-ChildItem -LiteralPath $wuDownloadPath -Recurse -File -ErrorAction SilentlyContinue
            if ($wuFiles.Count -gt 0) {
                $wuSize = ($wuFiles | Measure-Object -Property Length -Sum).Sum
                # If cache is older than 7 days, consider eligible
                $oldWuFiles = $wuFiles | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) }
                if ($oldWuFiles.Count -gt 0) {
                    $oldWuSize = ($oldWuFiles | Measure-Object -Property Length -Sum).Sum
                    $finding = [Finding]::new()
                    $finding.Id = "TMP-004"
                    $finding.Severity = [SeverityLevel]::Info
                    $finding.Title = "Windows Update Download Cache: $($oldWuFiles.Count) staged file(s) ($(Format-FileSize $oldWuSize))"
                    $finding.Detail = "Completed Windows Update installation payloads in $wuDownloadPath."
                    $finding.Path = $wuDownloadPath
                    $finding.FileCount = $oldWuFiles.Count
                    $finding.SizeBytes = $oldWuSize
                    $result.Findings.Add($finding)
                }
            }
        }
        catch {}
    }

    $stopwatch.Stop()
    $result.DurationMs = $stopwatch.ElapsedMilliseconds
    $result.CompletedAt = [datetime]::UtcNow

    if ($result.Findings.Count -eq 0) {
        $result.Status = [RepairStatus]::Healthy
        $result.RiskLevel = [RiskLevel]::Safe
        $result.RequiresAdmin = $false
        Write-RepairLog -Message "Temporary Files scan completed: No significant temporary file buildup detected." -Level 'SUCCESS' -Category 'SCAN' -ModuleName 'TempFiles'
    }
    else {
        $result.Status = [RepairStatus]::ProblemFound

        $needsAdmin = ($result.Findings | Where-Object { $_.Id -in @('TMP-002', 'TMP-004') }).Count -gt 0
        $result.RequiresAdmin = $needsAdmin
        $result.RiskLevel = if ($needsAdmin) { [RiskLevel]::Elevated } else { [RiskLevel]::Safe }
        $result.Recommendations.Add("Perform safe cleanup of temporary files and obsolete cache older than $AgeHoursThreshold hrs.")

        Write-RepairLog -Message "Temporary Files scan completed: $($result.Findings.Count) category(ies) eligible for cleanup." -Level 'INFO' -Category 'SCAN' -ModuleName 'TempFiles'
    }

    return $result
}
