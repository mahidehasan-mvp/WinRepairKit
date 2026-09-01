# WinRepairKit - Plan Manager
# Responsible for constructing, evaluating, fingerprinting, and formatting repair plans

function Get-FindingFingerprint {
    <#
    .SYNOPSIS
        Generates a deterministic SHA256 hash representing a set of findings.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [Finding[]]$Findings
    )

    if (-not $Findings -or $Findings.Count -eq 0) {
        return "EMPTY_HEALTHY"
    }

    # Sort findings deterministically by Id + Path
    $sorted = $Findings | Sort-Object -Property { "$($_.Id):$($_.Path)" }
    $rawTokens = [System.Collections.Generic.List[string]]::new()

    foreach ($f in $sorted) {
        $rawTokens.Add("$($f.Id)|$($f.Severity)|$($f.Path)|$($f.FileCount)|$($f.SizeBytes)")
    }

    $rawString = $rawTokens -join ";"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($rawString)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha256.ComputeHash($bytes)
    return [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLowerInvariant().Substring(0, 16)
}

function Test-PlanFingerprintMatch {
    <#
    .SYNOPSIS
        Validates if a pre-generated RepairPlan still accurately reflects the current system state.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [RepairPlan]$Plan,

        [Parameter(Mandatory = $true)]
        [Finding[]]$CurrentFindings
    )

    $currentFingerprint = Get-FindingFingerprint -Findings $CurrentFindings
    $isMatch = ($Plan.SystemFingerprint -eq $currentFingerprint)

    return [PSCustomObject]@{
        IsMatch            = $isMatch
        PlanFingerprint    = $Plan.SystemFingerprint
        CurrentFingerprint = $currentFingerprint
        PlanId             = $Plan.PlanId
        Message            = if ($isMatch) {
            "Plan fingerprint matches current system state."
        } else {
            "Plan fingerprint mismatch: System state changed after this plan was generated ($($Plan.SystemFingerprint) != $currentFingerprint). A new scan/plan is required."
        }
    }
}

function Format-RepairPlan {
    <#
    .SYNOPSIS
        Formats a RepairPlan object into a human-readable summary.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [RepairPlan]$Plan
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("================================================================")
    [void]$sb.AppendLine(" REPAIR PLAN: $($Plan.ModuleName) - $($Plan.Title)")
    [void]$sb.AppendLine("================================================================")
    [void]$sb.AppendLine("Plan ID     : $($Plan.PlanId)")
    [void]$sb.AppendLine("Fingerprint : $($Plan.SystemFingerprint)")
    [void]$sb.AppendLine("Description : $($Plan.Description)")

    $riskText = switch ($Plan.MaxRiskLevel) {
        ([RiskLevel]::Safe)        { "[Safe]" }
        ([RiskLevel]::Elevated)    { "[Elevated]" }
        ([RiskLevel]::Destructive) { "[Destructive]" }
        Default                    { "[Unknown]" }
    }
    [void]$sb.AppendLine("Max Risk    : $riskText")
    [void]$sb.AppendLine("Requires UAC: $(if ($Plan.RequiresAdmin) { 'Yes (Administrator)' } else { 'No' })")
    [void]$sb.AppendLine("Destructive : $(if ($Plan.DataDestructive) { 'Yes (Permanent file removal)' } else { 'No' })")
    [void]$sb.AppendLine("Supports Dry: $(if ($Plan.SupportsDryRun) { 'Yes' } else { 'No' })")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Proposed Actions:")
    [void]$sb.AppendLine("----------------------------------------------------------------")

    if ($Plan.Steps.Count -eq 0) {
        [void]$sb.AppendLine("  (No actions required - system is healthy)")
    }
    else {
        foreach ($step in $Plan.Steps) {
            $stepRisk = switch ($step.RiskLevel) {
                ([RiskLevel]::Safe)        { "[Safe]" }
                ([RiskLevel]::Elevated)    { "[Elevated]" }
                ([RiskLevel]::Destructive) { "[Destructive]" }
                Default                    { "[Unknown]" }
            }
            $adminFlag = if ($step.RequiresAdmin) { " [Admin]" } else { "" }
            [void]$sb.AppendLine("  [$($step.StepNumber)] $stepRisk$adminFlag $($step.Action)")
            [void]$sb.AppendLine("      $($step.Description)")
        }
    }

    if ($Plan.DataDestructive) {
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("IMPORTANT NOTICE:")
        [void]$sb.AppendLine("  $($Plan.Disclaimer)")
    }

    [void]$sb.AppendLine("================================================================")
    return $sb.ToString()
}
