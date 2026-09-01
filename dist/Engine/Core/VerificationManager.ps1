# WinRepairKit - Verification Manager
# Handles post-repair state re-evaluation and before/after diffing

function Invoke-PostRepairVerify {
    <#
    .SYNOPSIS
        Re-scans a module after a repair operation and compares before/after states.
    #>
    [CmdletBinding()]
    [OutputType([VerificationResult])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter(Mandatory = $true)]
        [RepairResult]$PreRepairResult,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScanScriptBlock
    )

    Write-RepairLog -Message "Starting post-repair verification for module '$ModuleName'..." -Level 'INFO' -Category 'VERIFY' -ModuleName $ModuleName

    $postScanResult = & $ScanScriptBlock

    $verification = [VerificationResult]::new()
    $beforeFindingCount = if ($PreRepairResult.Findings) { $PreRepairResult.Findings.Count } else { 0 }
    $afterFindingCount = if ($postScanResult.Findings) { $postScanResult.Findings.Count } else { 0 }

    $verification.RemainingProblemsCount = $afterFindingCount
    if ($postScanResult.Findings) {
        foreach ($f in $postScanResult.Findings) {
            $verification.RemainingFindings.Add($f)
        }
    }

    if ($afterFindingCount -eq 0) {
        $verification.Passed = $true
        $verification.Message = "Verification passed: All detected problems in '$ModuleName' have been successfully resolved."
        Write-RepairLog -Message $verification.Message -Level 'SUCCESS' -Category 'VERIFY' -ModuleName $ModuleName
    }
    elseif ($afterFindingCount -lt $beforeFindingCount) {
        $verification.Passed = $false
        $resolvedCount = $beforeFindingCount - $afterFindingCount
        $verification.Message = "Partial repair: $resolvedCount problem(s) resolved, but $afterFindingCount issue(s) remain. No further destructive action was performed."
        Write-RepairLog -Message $verification.Message -Level 'WARN' -Category 'VERIFY' -ModuleName $ModuleName
    }
    else {
        $verification.Passed = $false
        $verification.Message = "Verification failed: $afterFindingCount problem(s) still detected in '$ModuleName'. No further destructive action was performed."
        Write-RepairLog -Message $verification.Message -Level 'ERROR' -Category 'VERIFY' -ModuleName $ModuleName
    }

    return $verification
}
