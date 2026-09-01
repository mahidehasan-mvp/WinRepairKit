# WinRepairKit - RecycleBin Module: Snapshot Exporter
# Captures pre-repair metadata and ACL state for Recycle Bin containers

function Export-RecycleBinSnapshot {
    [CmdletBinding()]
    [OutputType([SnapshotInfo])]
    param(
        [Parameter()]
        [string[]]$Paths = @(),

        [Parameter()]
        [string]$CustomSnapshotDir
    )

    if ($Paths.Count -eq 0) {
        $driveInfos = Get-DriveRecycleBinInfo
        $Paths = @($driveInfos | Where-Object { $_.Exists } | ForEach-Object { $_.RecycleBinPath })
    }

    $metadata = @{
        TargetModule = 'RecycleBin'
        HostOS       = [System.Environment]::OSVersion.VersionString
        IsElevated   = (Test-IsElevated)
        PathCount    = $Paths.Count
    }

    return Export-PreRepairSnapshot -ModuleName 'RecycleBin' -TargetPaths $Paths -Metadata $metadata -CustomSnapshotDir $CustomSnapshotDir
}
