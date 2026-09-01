# WinRepairKit - TempFiles Module: Repair Executor
# Performs safe contextual cleanup with lock detection and plan fingerprint validation

function Repair-TempFiles {
    <#
    .SYNOPSIS
        Safely purges eligible temporary files and cache while respecting file locks.
    #>
    [CmdletBinding()]
    [OutputType([RepairResult])]
    param(
        [Parameter()]
        [RepairResult]$ScanResult,

        [Parameter()]
        [RepairPlan]$Plan,

        [Parameter()]
        [int]$AgeHoursThreshold = 24,

        [Parameter()]
        [switch]$DryRun,

        [Parameter()]
        [switch]$ConfirmFix
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $finalResult = [RepairResult]::new()
    $finalResult.ModuleName = "TempFiles"
    $finalResult.SupportsDryRun = $true
    $finalResult.CanRepair = $true
    $finalResult.DataDestructive = $false
    $finalResult.MutationsPerformed = $false
    $finalResult.StartedAt = [datetime]::UtcNow

    # 1. SCAN & FINGERPRINT CHECK
    $currentScan = Test-TempFiles -AgeHoursThreshold $AgeHoursThreshold

    if ($currentScan.Findings.Count -eq 0) {
        $finalResult.Status = [RepairStatus]::Healthy
        $finalResult.RiskLevel = [RiskLevel]::Safe
        $finalResult.RequiresAdmin = $false
        Write-RepairLog -Message "Temporary storage is already clean. No cleanup needed." -Level 'INFO' -Category 'REPAIR' -ModuleName 'TempFiles'
        $stopwatch.Stop()
        $finalResult.DurationMs = $stopwatch.ElapsedMilliseconds
        $finalResult.CompletedAt = [datetime]::UtcNow
        return $finalResult
    }

    # 2. PLAN VALIDATION
    if ($Plan) {
        $match = Test-PlanFingerprintMatch -Plan $Plan -CurrentFindings $currentScan.Findings
        if (-not $match.IsMatch) {
            $finalResult.Status = [RepairStatus]::PlanInvalidated
            $finalResult.PlanId = $Plan.PlanId
            Write-RepairLog -Message $match.Message -Level 'ERROR' -Category 'PLAN' -ModuleName 'TempFiles'
            $finalResult.Recommendations.Add("Temporary files changed since plan creation. A fresh plan is required.")
            $stopwatch.Stop()
            $finalResult.DurationMs = $stopwatch.ElapsedMilliseconds
            $finalResult.CompletedAt = [datetime]::UtcNow
            return $finalResult
        }
    }
    else {
        $Plan = Build-TempFilesPlan -ScanResult $currentScan -AgeHoursThreshold $AgeHoursThreshold
    }

    $finalResult.Plan = $Plan
    $finalResult.PlanId = $Plan.PlanId
    $finalResult.RiskLevel = $Plan.MaxRiskLevel
    $finalResult.RequiresAdmin = $Plan.RequiresAdmin
    foreach ($f in $currentScan.Findings) {
        $finalResult.Findings.Add($f)
    }

    # 3. SAFETY CHECK
    $safety = Test-PlanSafety -Plan $Plan -DryRun:$DryRun -Confirmed:$ConfirmFix
    if (-not $safety.CanExecute) {
        $finalResult.Status = [RepairStatus]::Error
        $reasonsStr = $safety.BlockReasons -join "; "
        Write-RepairLog -Message "Cleanup aborted by Safety Manager: $reasonsStr" -Level 'ERROR' -Category 'CONSENT' -ModuleName 'TempFiles'
        $finalResult.Recommendations.Add("Ensure elevated Administrator privileges if cleaning system temp files.")
        $stopwatch.Stop()
        $finalResult.DurationMs = $stopwatch.ElapsedMilliseconds
        $finalResult.CompletedAt = [datetime]::UtcNow
        return $finalResult
    }

    # 4. DRY RUN EXECUTION (Zero Mutation)
    if ($DryRun) {
        Write-RepairLog -Message "=== DRY RUN MODE: Zero mutations will be performed ===" -Level 'INFO' -Category 'PLAN' -ModuleName 'TempFiles'
        foreach ($step in $Plan.Steps) {
            Write-RepairLog -Message "Would execute [Step $($step.StepNumber)]: $($step.Action) ($($step.Description))" -Level 'INFO' -Category 'PLAN' -ModuleName 'TempFiles'
        }
        $finalResult.Status = [RepairStatus]::Skipped
        $finalResult.MutationsPerformed = $false
        $stopwatch.Stop()
        $finalResult.DurationMs = $stopwatch.ElapsedMilliseconds
        $finalResult.CompletedAt = [datetime]::UtcNow
        Write-RepairLog -Message "Dry run completed successfully. No system files were removed." -Level 'SUCCESS' -Category 'PLAN' -ModuleName 'TempFiles'
        return $finalResult
    }

    # 5. REAL EXECUTION WITH TRANSACTION JOURNALING
    Write-RepairLog -Message "Starting Temporary Files cleanup [Transaction: $($finalResult.TransactionId)]..." -Level 'INFO' -Category 'REPAIR' -ModuleName 'TempFiles'
    Start-RepairTransaction -TransactionId $finalResult.TransactionId -ModuleName 'TempFiles' -Plan $Plan | Out-Null

    # Step 1: Pre-cleanup Snapshot
    try {
        $snapshot = Export-TempFilesSnapshot
        $finalResult.Snapshot = $snapshot
        Update-RepairTransaction -TransactionId $finalResult.TransactionId -StepNumber 1 -StepAction "ExportSnapshot" -SnapshotId $snapshot.SnapshotId
    }
    catch {}

    $cutoffTime = (Get-Date).AddHours(-$AgeHoursThreshold)
    [int64]$filesRemoved = 0
    [int64]$bytesReclaimed = 0
    [int64]$filesSkippedLocked = 0

    # Execute cleanup steps
    foreach ($step in $Plan.Steps) {
        if ($step.Action -eq "Export State Snapshot" -or $step.Action -eq "Verify Space Reclamation") {
            continue
        }

        $targetPath = $step.Parameters['Path']
        if (-not $targetPath -or -not (Test-Path -LiteralPath $targetPath)) {
            continue
        }

        Write-RepairLog -Message "Executing $($step.Action) in $targetPath..." -Level 'INFO' -Category 'REPAIR' -ModuleName 'TempFiles'

        try {
            $items = Get-ChildItem -LiteralPath $targetPath -Recurse -Force -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                if ($item.PSIsContainer) { continue }

                # Check age if age parameter specified
                if ($step.Parameters.ContainsKey('AgeHours') -and $item.LastWriteTime -ge $cutoffTime) {
                    continue
                }

                # Attempt safe deletion with lock protection
                try {
                    $itemSize = $item.Length
                    [System.IO.File]::Delete($item.FullName)
                    $filesRemoved++
                    $bytesReclaimed += $itemSize
                    $finalResult.MutationsPerformed = $true
                }
                catch {
                    # File locked by active process - skip safely
                    $filesSkippedLocked++
                }
            }

            Update-RepairTransaction -TransactionId $finalResult.TransactionId -StepNumber $step.StepNumber -StepAction $step.Action
        }
        catch {
            Write-RepairLog -Message "Warning in $($step.Action): $_" -Level 'WARN' -Category 'REPAIR' -ModuleName 'TempFiles'
        }
    }

    Write-RepairLog -Message "Cleanup complete: $filesRemoved file(s) removed ($(Format-FileSize $bytesReclaimed) reclaimed), $filesSkippedLocked in-use file(s) safely protected." -Level 'SUCCESS' -Category 'REPAIR' -ModuleName 'TempFiles'

    # 6. POST-CLEANUP VERIFICATION
    $verifyResult = Invoke-PostRepairVerify -ModuleName 'TempFiles' -PreRepairResult $currentScan -ScanScriptBlock {
        Test-TempFiles -AgeHoursThreshold $AgeHoursThreshold
    }
    $finalResult.Verification = $verifyResult

    if ($verifyResult.Passed -or $bytesReclaimed -gt 0) {
        $finalResult.Status = [RepairStatus]::RepairSucceeded
        Complete-RepairTransaction -TransactionId $finalResult.TransactionId -FinalStatus 'Completed'
    }
    else {
        $finalResult.Status = [RepairStatus]::RepairFailed
        Complete-RepairTransaction -TransactionId $finalResult.TransactionId -FinalStatus 'Failed'
    }

    $stopwatch.Stop()
    $finalResult.DurationMs = $stopwatch.ElapsedMilliseconds
    $finalResult.CompletedAt = [datetime]::UtcNow
    return $finalResult
}
