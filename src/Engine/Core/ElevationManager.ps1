# WinRepairKit - Elevation Manager
# Handles UAC checks and elevation lifecycle cleanly

function Test-IsElevated {
    <#
    .SYNOPSIS
        Checks if the current PowerShell process has elevated Administrator privileges.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Assert-Elevation {
    <#
    .SYNOPSIS
        Throws a friendly error if administrator privileges are required but missing.
    #>
    [CmdletBinding()]
    param(
        [string]$OperationName = "This repair operation"
    )

    if (-not (Test-IsElevated)) {
        $msg = "$OperationName requires elevated Administrator privileges. Please re-run in an elevated PowerShell prompt or allow the elevation prompt."
        Write-RepairLog -Message $msg -Level 'ERROR' -Category 'ELEVATION'
        throw [System.UnauthorizedAccessException]::new($msg)
    }
}

function Invoke-ElevatedCli {
    <#
    .SYNOPSIS
        Re-launches the CLI with elevated administrator privileges (via UAC prompt).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CliScriptPath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [switch]$Wait
    )

    Write-RepairLog -Message "Requesting UAC elevation for: $CliScriptPath $($Arguments -join ' ')" -Level 'INFO' -Category 'ELEVATION'

    $powerShellExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' }

    $argList = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$CliScriptPath`""
    ) + $Arguments

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $powerShellExe
    $psi.Arguments = $argList -join " "
    $psi.Verb = "runas"
    $psi.UseShellExecute = $true

    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
        if ($Wait -and $proc) {
            $proc.WaitForExit()
            return $proc.ExitCode
        }
        return 0
    }
    catch {
        Write-RepairLog -Message "Elevation request cancelled or failed: $_" -Level 'WARN' -Category 'ELEVATION'
        return 1
    }
}
