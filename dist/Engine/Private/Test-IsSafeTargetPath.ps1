# WinRepairKit - Security Validation Helper
# Prevents path traversal and unsafe symlink/junction following during cleanup/repair.

function Test-IsSafeTargetPath {
    <#
    .SYNOPSIS
        Verifies that a target path is strictly within an allowed root, contains no path traversal (..),
        and does not cross unsafe reparse points (symlinks/junctions) outside the target scope.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,

        [Parameter(Mandatory = $true)]
        [string]$AllowedRootPath,

        [Parameter()]
        [switch]$DisallowReparsePoints
    )

    try {
        # Normalize and get absolute paths
        $canonicalTarget = [System.IO.Path]::GetFullPath($TargetPath).TrimEnd('\', '/')
        $canonicalRoot = [System.IO.Path]::GetFullPath($AllowedRootPath).TrimEnd('\', '/')

        # Path traversal check: Target must start with allowed root
        if (-not $canonicalTarget.StartsWith($canonicalRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-RepairLog -Message "Security Block: Target '$canonicalTarget' traverses outside allowed root '$canonicalRoot'" -Level 'ERROR' -Category 'CONSENT'
            return $false
        }

        # Check if item itself is a reparse point (symlink / junction)
        if ($DisallowReparsePoints -and (Test-Path -LiteralPath $canonicalTarget)) {
            $item = Get-Item -LiteralPath $canonicalTarget -Force -ErrorAction SilentlyContinue
            if ($item -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                Write-RepairLog -Message "Security Block: Target '$canonicalTarget' is a reparse point (symlink/junction)" -Level 'WARN' -Category 'CONSENT'
                return $false
            }
        }

        return $true
    }
    catch {
        Write-RepairLog -Message "Security check failed on path '$TargetPath': $_" -Level 'ERROR' -Category 'CONSENT'
        return $false
    }
}
