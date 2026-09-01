# WinRepairKit - RecycleBin Module: Plan Builder
# Constructs a fingerprinted 5-step repair plan with dynamic consequences and transparency guarantees

function Build-RecycleBinPlan {
    <#
    .SYNOPSIS
        Generates a reviewable, fingerprinted repair plan for corrupted Recycle Bin entries.
    #>
    [CmdletBinding()]
    [OutputType([RepairPlan])]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [RepairResult]$ScanResult,

        [Parameter()]
        [string]$DriveLetter
    )

    if (-not $ScanResult) {
        $ScanResult = Test-RecycleBin -DriveLetter $DriveLetter
    }

    $plan = [RepairPlan]::new()
    $plan.ModuleName = "RecycleBin"
    $plan.Title = "Recycle Bin Health & Permission Repair"
    $plan.Description = "Repairs corrupted directory permissions, takes ownership of inaccessible SID entries, and removes unreadable items."
    $plan.Disclaimer = "Only corrupted/inaccessible items are removed. Standard Recycle Bin items are untouched."
    $plan.ExplicitDisclaimer = "I understand that this repair may permanently remove the affected Recycle Bin entries and that WinRepairKit's state snapshot does not contain the original file contents."
    $plan.SupportsDryRun = $true
    $plan.SystemFingerprint = Get-FindingFingerprint -Findings $ScanResult.Findings

    # Set Dynamic Consequence
    $plan.Consequence.DataLossPossible = $true
    $plan.Consequence.Reversible = $false
    $plan.Consequence.BackupCreated = $false
    $plan.Consequence.SnapshotCreated = $true

    # What will NOT happen guarantees
    $plan.WhatWillNotHappen.Add("No healthy files outside affected Recycle Bin SID folders will be modified.")
    $plan.WhatWillNotHappen.Add("No registry cleaning or background system modifications will occur.")
    $plan.WhatWillNotHappen.Add("The repair will NOT escalate to destructive deletion if permission resets fail (No Blind Escalation).")
    $plan.WhatWillNotHappen.Add("Diagnostics and file records remain strictly local on this PC.")

    if ($ScanResult.Status -eq [RepairStatus]::Healthy -or $ScanResult.Findings.Count -eq 0) {
        $plan.Title = "Recycle Bin is Healthy"
        $plan.Description = "No problems detected. All Recycle Bin containers are functioning normally."
        return $plan
    }

    # Step 1: Pre-repair State Snapshot
    $step1 = [PlanStep]::new()
    $step1.StepNumber = 1
    $step1.Action = "Export State Snapshot"
    $step1.Description = "Export ACLs, ownership information, and file metadata to a timestamped snapshot."
    $step1.RiskLevel = [RiskLevel]::Safe
    $step1.RequiresAdmin = $false
    $step1.DataDestructive = $false
    $plan.AddStep($step1)

    # Step 2: Reset Permissions (Tier 1)
    $step2 = [PlanStep]::new()
    $step2.StepNumber = 2
    $step2.Action = "Reset ACL Permissions"
    $step2.Description = "Grant Administrators and SYSTEM full control inheritance on affected Recycle Bin folders."
    $step2.RiskLevel = [RiskLevel]::Elevated
    $step2.RequiresAdmin = $true
    $step2.DataDestructive = $false
    $plan.AddStep($step2)

    # Step 3: Take Ownership (Tier 2)
    $step3 = [PlanStep]::new()
    $step3.StepNumber = 3
    $step3.Action = "Take Ownership of Inaccessible Entries"
    $step3.Description = "Assign ownership of locked entries to Administrators group so they can be processed."
    $step3.RiskLevel = [RiskLevel]::Destructive
    $step3.RequiresAdmin = $true
    $step3.DataDestructive = $true
    $plan.AddStep($step3)

    # Step 4: Purge Inaccessible Entries (Tier 3)
    $step4 = [PlanStep]::new()
    $step4.StepNumber = 4
    $step4.Action = "Purge Inaccessible Entries"
    $step4.Description = "Permanently remove inaccessible items with permission locks."
    $step4.RiskLevel = [RiskLevel]::Destructive
    $step4.RequiresAdmin = $true
    $step4.DataDestructive = $true
    $plan.AddStep($step4)

    # Step 5: Verification
    $step5 = [PlanStep]::new()
    $step5.StepNumber = 5
    $step5.Action = "Verify Recycle Bin Health"
    $step5.Description = "Re-scan drives to confirm 0 permission errors and verify normal Recycle Bin operation."
    $step5.RiskLevel = [RiskLevel]::Safe
    $step5.RequiresAdmin = $false
    $step5.DataDestructive = $false
    $plan.AddStep($step5)

    return $plan
}
