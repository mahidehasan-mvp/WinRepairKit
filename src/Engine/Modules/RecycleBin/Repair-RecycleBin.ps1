# WinRepairKit - RecycleBin Module: Repair Executor
# Performs hardened multi-tier repair with plan fingerprint validation, path security checks, and transaction journaling

function Repair-RecycleBin {
    <#
    .SYNOPSIS
        Safely repairs corrupted Recycle Bin permissions and removes inaccessible entries.
    #>
    [CmdletBinding()]
    [OutputType([RepairResult])]
    param(
        [Parameter()]
        [RepairResult]$ScanResult,

        [Parameter()]
        [RepairPlan]$Plan,

        [Parameter()]
        [string]$DriveLetter,

        [Parameter()]
        [switch]$DryRun,

        [Parameter()]
        [switch]$ConfirmFix
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $finalResult = [RepairResult]::new()
    $finalResult.ModuleName = "RecycleBin"
    $finalResult.SupportsDryRun = $true
    $finalResult.CanRepair = $true
    $finalResult.DataDestructive = $true
    $finalResult.RequiresAdmin = $true
    $finalResult.MutationsPerformed = $false
    $finalResult.StartedAt = [datetime]::UtcNow

    # 1. SCAN & FINGERPRINT CHECK
    $currentScan = Test-RecycleBin -DriveLetter $DriveLetter

    if ($currentScan.Findings.Count -eq 0) {
        $finalResult.Status = [RepairStatus]::Healthy
        $finalResult.RiskLevel = [RiskLevel]::Safe
        $finalResult.RequiresAdmin = $false
        $finalResult.DataDestructive = $false
        Write-RepairLog -Message "Recycle Bin is already healthy. No repair needed." -Level 'INFO' -Category 'REPAIR' -ModuleName 'RecycleBin'
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
            Write-RepairLog -Message $match.Message -Level 'ERROR' -Category 'PLAN' -ModuleName 'RecycleBin'
            $finalResult.Recommendations.Add("The Recycle Bin state changed since the plan was created. Please generate a new plan.")
            $stopwatch.Stop()
            $finalResult.DurationMs = $stopwatch.ElapsedMilliseconds
            $finalResult.CompletedAt = [datetime]::UtcNow
            return $finalResult
        }
    }
    else {
        $Plan = Build-RecycleBinPlan -ScanResult $currentScan -DriveLetter $DriveLetter
    }

    $finalResult.Plan = $Plan
    $finalResult.PlanId = $Plan.PlanId
    foreach ($f in $currentScan.Findings) {
        $finalResult.Findings.Add($f)
    }

    # 3. SAFETY CHECK
    $safety = Test-PlanSafety -Plan $Plan -DryRun:$DryRun -Confirmed:$ConfirmFix
    if (-not $safety.CanExecute) {
        $finalResult.Status = [RepairStatus]::Error
        $reasonsStr = $safety.BlockReasons -join "; "
        Write-RepairLog -Message "Repair aborted by Safety Manager: $reasonsStr" -Level 'ERROR' -Category 'CONSENT' -ModuleName 'RecycleBin'
        $finalResult.Recommendations.Add("Ensure elevated Administrator privileges and provide explicit confirmation (-ConfirmFix).")
        $stopwatch.Stop()
        $finalResult.DurationMs = $stopwatch.ElapsedMilliseconds
        $finalResult.CompletedAt = [datetime]::UtcNow
        return $finalResult
    }

    # 4. DRY RUN EXECUTION (Strict Zero-Mutation Guarantee)
    if ($DryRun) {
        Write-RepairLog -Message "=== DRY RUN MODE: Zero mutations will be performed ===" -Level 'INFO' -Category 'PLAN' -ModuleName 'RecycleBin'
        foreach ($step in $Plan.Steps) {
            Write-RepairLog -Message "Would execute [Step $($step.StepNumber)]: $($step.Action) ($($step.Description))" -Level 'INFO' -Category 'PLAN' -ModuleName 'RecycleBin'
        }
        $finalResult.Status = [RepairStatus]::Skipped
        $finalResult.RiskLevel = $Plan.MaxRiskLevel
        $finalResult.MutationsPerformed = $false
        $stopwatch.Stop()
        $finalResult.DurationMs = $stopwatch.ElapsedMilliseconds
        $finalResult.CompletedAt = [datetime]::UtcNow
        Write-RepairLog -Message "Dry run completed successfully. No system changes made." -Level 'SUCCESS' -Category 'PLAN' -ModuleName 'RecycleBin'
        return $finalResult
    }

    # 5. REAL EXECUTION WITH TRANSACTION JOURNALING
    Write-RepairLog -Message "Starting active Recycle Bin repair [Transaction: $($finalResult.TransactionId)]..." -Level 'INFO' -Category 'REPAIR' -ModuleName 'RecycleBin'
    Start-RepairTransaction -TransactionId $finalResult.TransactionId -ModuleName 'RecycleBin' -Plan $Plan | Out-Null

    # Step 1: Pre-repair Snapshot
    try {
        $snapshot = Export-RecycleBinSnapshot
        $finalResult.Snapshot = $snapshot
        Update-RepairTransaction -TransactionId $finalResult.TransactionId -StepNumber 1 -StepAction "ExportSnapshot" -SnapshotId $snapshot.SnapshotId
    }
    catch {
        Write-RepairLog -Message "Warning: State snapshot capture encountered error: $_" -Level 'WARN' -Category 'SNAPSHOT' -ModuleName 'RecycleBin'
    }

    $targetDrives = Get-DriveRecycleBinInfo -DriveLetter $DriveLetter | Where-Object { $_.Exists }
    $encounteredError = $false

    foreach ($drv in $targetDrives) {
        $rbPath = $drv.RecycleBinPath
        $drvLetter = $drv.DriveLetter

        # Security check on root container
        $expectedRoot = "$($drvLetter)\`$Recycle.Bin"
        if (-not (Test-IsSafeTargetPath -TargetPath $rbPath -AllowedRootPath $expectedRoot)) {
            Write-RepairLog -Message "Security block on $rbPath. Skipping drive $drvLetter." -Level 'ERROR' -Category 'SAFETY' -ModuleName 'RecycleBin'
            continue
        }

        Write-RepairLog -Message "Processing Recycle Bin on $drvLetter ($rbPath)..." -Level 'INFO' -Category 'REPAIR' -ModuleName 'RecycleBin'

        # Tier 1: Reset ACL Permissions
        try {
            Write-RepairLog -Message "Tier 1: Granting Administrator & SYSTEM full control permissions on $rbPath" -Level 'INFO' -Category 'REPAIR' -ModuleName 'RecycleBin'
            & icacls "$rbPath" /grant:r "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" /t /c /q 2>$null
            $finalResult.MutationsPerformed = $true
            Update-RepairTransaction -TransactionId $finalResult.TransactionId -StepNumber 2 -StepAction "ResetPermissions-$drvLetter"
        }
        catch {
            $encounteredError = $true
            Write-RepairLog -Message "Tier 1 permission grant error: $_. Halting destructive escalation." -Level 'ERROR' -Category 'REPAIR' -ModuleName 'RecycleBin'
            break
        }

        # Tier 2: Take Ownership of locked entries (only if inaccessible items detected and Tier 1 succeeded)
        if ($drv.InaccessibleCount -gt 0 -or -not $drv.IsAccessible) {
            try {
                Write-RepairLog -Message "Tier 2: Taking ownership of locked files in $rbPath" -Level 'INFO' -Category 'REPAIR' -ModuleName 'RecycleBin'
                & takeown /f "$rbPath" /r /d y 2>$null
                & icacls "$rbPath" /grant:r "*S-1-5-32-544:(OI)(CI)F" /t /c /q 2>$null
                $finalResult.MutationsPerformed = $true
                Update-RepairTransaction -TransactionId $finalResult.TransactionId -StepNumber 3 -StepAction "TakeOwnership-$drvLetter"
            }
            catch {
                $encounteredError = $true
                Write-RepairLog -Message "Tier 2 ownership change error: $_. Halting destructive escalation." -Level 'ERROR' -Category 'REPAIR' -ModuleName 'RecycleBin'
                break
            }
        }

        # Tier 3: Clean Inaccessible Entries (only if planned and earlier tiers succeeded)
        if (-not $encounteredError -and ($drv.InaccessibleCount -gt 0 -or -not $drv.IsAccessible)) {
            try {
                Write-RepairLog -Message "Tier 3: Purging inaccessible entries in $rbPath" -Level 'INFO' -Category 'REPAIR' -ModuleName 'RecycleBin'
                
                foreach ($sid in $drv.SidFolders) {
                    if ($sid.InaccessibleCount -gt 0 -or -not $sid.IsAccessible) {
                        $sidPath = $sid.Path
                        
                        # Security Check: Ensure SID path is strictly child of Recycle Bin and not a symlink/junction
                        if (Test-IsSafeTargetPath -TargetPath $sidPath -AllowedRootPath $rbPath -DisallowReparsePoints) {
                            cmd.exe /c "rd /s /q `"$sidPath`"" 2>$null
                            $finalResult.MutationsPerformed = $true
                        }
                        else {
                            Write-RepairLog -Message "Security block: SID path '$sidPath' is not a valid target. Skipping." -Level 'WARN' -Category 'SAFETY' -ModuleName 'RecycleBin'
                        }
                    }
                }

                if (-not $drv.IsAccessible) {
                    if (Test-IsSafeTargetPath -TargetPath $rbPath -AllowedRootPath $expectedRoot -DisallowReparsePoints) {
                        $removeCmd = "rd /s /q `"$rbPath`""
                        cmd.exe /c $removeCmd 2>$null
                        $finalResult.MutationsPerformed = $true

                        if (-not (Test-Path -LiteralPath $rbPath)) {
                            New-Item -ItemType Directory -Path $rbPath -Force | Out-Null
                            attrib +h +s "$rbPath" 2>$null
                        }
                    }
                }
                Update-RepairTransaction -TransactionId $finalResult.TransactionId -StepNumber 4 -StepAction "PurgeEntries-$drvLetter"
            }
            catch {
                $encounteredError = $true
                Write-RepairLog -Message "Tier 3 purge error: $_" -Level 'ERROR' -Category 'REPAIR' -ModuleName 'RecycleBin'
            }
        }
    }

    # 6. POST-REPAIR VERIFICATION
    $verifyResult = Invoke-PostRepairVerify -ModuleName 'RecycleBin' -PreRepairResult $currentScan -ScanScriptBlock {
        Test-RecycleBin -DriveLetter $DriveLetter
    }
    $finalResult.Verification = $verifyResult

    if ($verifyResult.Passed) {
        $finalResult.Status = [RepairStatus]::RepairSucceeded
        Complete-RepairTransaction -TransactionId $finalResult.TransactionId -FinalStatus 'Completed'
        Write-RepairLog -Message "Recycle Bin repair completed and verified successfully." -Level 'SUCCESS' -Category 'REPAIR' -ModuleName 'RecycleBin'
    }
    elseif ($verifyResult.RemainingProblemsCount -lt $currentScan.Findings.Count) {
        $finalResult.Status = [RepairStatus]::RepairPartial
        Complete-RepairTransaction -TransactionId $finalResult.TransactionId -FinalStatus 'PartialFailure'
        Write-RepairLog -Message "Recycle Bin repair partially completed ($($verifyResult.RemainingProblemsCount) problem(s) remaining)." -Level 'WARN' -Category 'REPAIR' -ModuleName 'RecycleBin'
    }
    else {
        $finalResult.Status = [RepairStatus]::RepairFailed
        Complete-RepairTransaction -TransactionId $finalResult.TransactionId -FinalStatus 'Failed'
        Write-RepairLog -Message "Recycle Bin repair failed to resolve all issues." -Level 'ERROR' -Category 'REPAIR' -ModuleName 'RecycleBin'
    }

    $stopwatch.Stop()
    $finalResult.DurationMs = $stopwatch.ElapsedMilliseconds
    $finalResult.CompletedAt = [datetime]::UtcNow
    return $finalResult
}
