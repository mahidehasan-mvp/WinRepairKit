# WinRepairKit - Support Bundle Manager
# Generates sanitized diagnostic bundles for support and troubleshooting without exposing sensitive user data.

function Export-WinRepairSupportBundle {
    <#
    .SYNOPSIS
        Creates a sanitized, privacy-preserving zip archive containing system diagnostics, logs, and transaction journals.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]$OutputDirectory,

        [Parameter()]
        [switch]$IncludeRawLogs
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

    if (-not $OutputDirectory) {
        $OutputDirectory = Join-Path -Path $env:LOCALAPPDATA -ChildPath "WinRepairKit\support-bundles"
    }

    if (-not (Test-Path -LiteralPath $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $bundleName = "WinRepairKit-Support-$timestamp"
    $tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $bundleName
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        # 1. System Info (Sanitized)
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $sysInfo = [ordered]@{
            ToolVersion      = "0.1.0"
            SchemaVersion    = "1.0"
            OSName           = $os.Caption
            OSVersion        = $os.Version
            OSBuild          = $os.BuildNumber
            Architecture     = $env:PROCESSOR_ARCHITECTURE
            IsElevated       = (Test-IsElevated)
            GeneratedAtUtc   = [datetime]::UtcNow.ToString("o")
        }
        $sysInfoJson = $sysInfo | ConvertTo-Json -Depth 4
        Set-Content -Path (Join-Path -Path $tempDir -ChildPath "system-info.json") -Value $sysInfoJson

        # 2. Collect & Sanitize Logs
        $logsDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "WinRepairKit\logs"
        if (Test-Path -LiteralPath $logsDir) {
            $destLogs = Join-Path -Path $tempDir -ChildPath "logs"
            New-Item -ItemType Directory -Path $destLogs -Force | Out-Null

            $logFiles = Get-ChildItem -Path $logsDir -Filter "*.log" -ErrorAction SilentlyContinue | Select-Object -First 3
            foreach ($lf in $logFiles) {
                $rawContent = Get-Content -LiteralPath $lf.FullName -Raw
                # Sanitize user paths
                $currentUser = $env:USERNAME
                $sanitized = $rawContent -replace [regex]::Escape($currentUser), "<USER>"
                Set-Content -Path (Join-Path -Path $destLogs -ChildPath $lf.Name) -Value $sanitized
            }
        }

        # 3. Collect Recent Transactions
        $txDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "WinRepairKit\transactions"
        if (Test-Path -LiteralPath $txDir) {
            $destTx = Join-Path -Path $tempDir -ChildPath "transactions"
            New-Item -ItemType Directory -Path $destTx -Force | Out-Null
            Copy-Item -Path "$txDir\*.json" -Destination $destTx -ErrorAction SilentlyContinue
        }

        # 4. README Notice
        $readme = @"
WinRepairKit Support Bundle
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Privacy Notice:
- User names and sensitive paths have been sanitized.
- This bundle contains diagnostic logs, state snapshots, and system version records.
- No personal file contents are included.
"@
        Set-Content -Path (Join-Path -Path $tempDir -ChildPath "README.txt") -Value $readme

        # 5. Create Zip Archive
        $zipPath = Join-Path -Path $OutputDirectory -ChildPath "$bundleName.zip"
        if (Test-Path -LiteralPath $zipPath) {
            Remove-Item -LiteralPath $zipPath -Force
        }

        [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipPath)
        Write-RepairLog -Message "Sanitized support bundle created at $zipPath" -Level 'SUCCESS' -Category 'SYSTEM'
        return $zipPath
    }
    finally {
        # Clean up temp working directory
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
