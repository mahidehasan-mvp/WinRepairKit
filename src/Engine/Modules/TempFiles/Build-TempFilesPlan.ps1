# WinRepairKit - TempFiles Module: Plan Builder
# Generates contextual, multi-risk cleanup plan with dynamic consequences and transparency guarantees

function Build-TempFilesPlan {
    <#
    .SYNOPSIS
        Constructs a safe, categorized cleanup plan for temporary files.
    #>
    [CmdletBinding()]
    [OutputType([RepairPlan])]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [RepairResult]$ScanResult,

        [Parameter()]
        [int]$AgeHoursThreshold = 24
    )

    if (-not $ScanResult) {
        $ScanResult = Test-TempFiles -AgeHoursThreshold $AgeHoursThreshold
    }

    $plan = [RepairPlan]::new()
    $plan.ModuleName = "TempFiles"
    $plan.Title = "Temporary Files & Cache Safe Cleanup"
    $plan.Description = "Removes stale user temp files, system temp files, crash dumps, and obsolete update cache older than $AgeHoursThreshold hrs while protecting active/in-use files."
    $plan.Disclaimer = "Only inactive, unlocked temporary files are removed. Active installer files and in-use locks are skipped automatically."
    $plan.ExplicitDisclaimer = "I understand that inactive temporary files older than $AgeHoursThreshold hours will be deleted, while in-use files and active installers are preserved."
    $plan.SupportsDryRun = $true
    $plan.DataDestructive = $false
    $plan.SystemFingerprint = Get-FindingFingerprint -Findings $ScanResult.Findings

    # Dynamic Consequence
    $plan.Consequence.DataLossPossible = $false
    $plan.Consequence.Reversible = $false
    $plan.Consequence.BackupCreated = $false
    $plan.Consequence.SnapshotCreated = $true

    # What will NOT happen guarantees
    $plan.WhatWillNotHappen.Add("In-use, locked, or active installer files will NOT be deleted.")
    $plan.WhatWillNotHappen.Add("Personal documents, Desktop files, Downloads, and app data will NOT be touched.")
    $plan.WhatWillNotHappen.Add("No background services, registry keys, or startup entries will be modified.")
    $plan.WhatWillNotHappen.Add("Diagnostics and file manifests remain strictly local on this PC.")

    if ($ScanResult.Status -eq [RepairStatus]::Healthy -or $ScanResult.Findings.Count -eq 0) {
        $plan.Title = "Temporary Storage is Healthy"
        $plan.Description = "No significant temporary file buildup detected."
        return $plan
    }

    [int]$stepNum = 1

    # Step 1: Pre-cleanup Snapshot (Safe)
    $targetPaths = @($ScanResult.Findings | ForEach-Object { $_.Path })
    $step1 = [PlanStep]::new()
    $step1.StepNumber = $stepNum++
    $step1.Action = "Export State Snapshot"
    $step1.Description = "Export manifest of temporary file categories and estimated reclamation space."
    $step1.RiskLevel = [RiskLevel]::Safe
    $step1.RequiresAdmin = $false
    $step1.DataDestructive = $false
    $step1.Parameters = @{ Paths = $targetPaths }
    $plan.AddStep($step1)

    # Step 2: User Temp Cleanup (Safe)
    $userTempFinding = $ScanResult.Findings | Where-Object { $_.Id -eq 'TMP-001' }
    if ($userTempFinding) {
        $step2 = [PlanStep]::new()
        $step2.StepNumber = $stepNum++
        $step2.Action = "Clean Inactive User Temp Files"
        $step2.Description = "Purge unlocked user temporary files older than $AgeHoursThreshold hrs ($($userTempFinding.FileCount) files, $(Format-FileSize $userTempFinding.SizeBytes))."
        $step2.RiskLevel = [RiskLevel]::Safe
        $step2.RequiresAdmin = $false
        $step2.DataDestructive = $false
        $step2.Parameters = @{ Path = $userTempFinding.Path; AgeHours = $AgeHoursThreshold }
        $plan.AddStep($step2)
    }

    # Step 3: Crash Dumps Cleanup (Safe)
    $dmpFinding = $ScanResult.Findings | Where-Object { $_.Id -eq 'TMP-003' }
    if ($dmpFinding) {
        $step3 = [PlanStep]::new()
        $step3.StepNumber = $stepNum++
        $step3.Action = "Clean Application Crash Dumps"
        $step3.Description = "Remove old application error memory dumps ($($dmpFinding.FileCount) dumps, $(Format-FileSize $dmpFinding.SizeBytes))."
        $step3.RiskLevel = [RiskLevel]::Safe
        $step3.RequiresAdmin = $false
        $step3.DataDestructive = $false
        $step3.Parameters = @{ Path = $dmpFinding.Path }
        $plan.AddStep($step3)
    }

    # Step 4: System Temp Cleanup (Elevated)
    $sysTempFinding = $ScanResult.Findings | Where-Object { $_.Id -eq 'TMP-002' }
    if ($sysTempFinding) {
        $step4 = [PlanStep]::new()
        $step4.StepNumber = $stepNum++
        $step4.Action = "Clean Windows System Temp Files"
        $step4.Description = "Purge inactive system-wide temporary files ($($sysTempFinding.FileCount) files, $(Format-FileSize $sysTempFinding.SizeBytes))."
        $step4.RiskLevel = [RiskLevel]::Elevated
        $step4.RequiresAdmin = $true
        $step4.DataDestructive = $false
        $step4.Parameters = @{ Path = $sysTempFinding.Path; AgeHours = $AgeHoursThreshold }
        $plan.AddStep($step4)
    }

    # Step 5: Windows Update Download Cache (Elevated)
    $wuFinding = $ScanResult.Findings | Where-Object { $_.Id -eq 'TMP-004' }
    if ($wuFinding) {
        $step5 = [PlanStep]::new()
        $step5.StepNumber = $stepNum++
        $step5.Action = "Clean Windows Update Download Cache"
        $step5.Description = "Remove completed update download packages ($($wuFinding.FileCount) files, $(Format-FileSize $wuFinding.SizeBytes))."
        $step5.RiskLevel = [RiskLevel]::Elevated
        $step5.RequiresAdmin = $true
        $step5.DataDestructive = $false
        $step5.Parameters = @{ Path = $wuFinding.Path }
        $plan.AddStep($step5)
    }

    # Step 6: Post-cleanup Verification (Safe)
    $stepVerify = [PlanStep]::new()
    $stepVerify.StepNumber = $stepNum++
    $stepVerify.Action = "Verify Space Reclamation"
    $stepVerify.Description = "Re-scan temporary directories to verify space reclaimed and confirm zero locked-file errors."
    $stepVerify.RiskLevel = [RiskLevel]::Safe
    $stepVerify.RequiresAdmin = $false
    $plan.AddStep($stepVerify)

    return $plan
}
