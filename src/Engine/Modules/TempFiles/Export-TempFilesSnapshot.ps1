# WinRepairKit - TempFiles Module: Snapshot Exporter
# Captures metadata of temporary storage state prior to cleanup

function Export-TempFilesSnapshot {
    [CmdletBinding()]
    [OutputType([SnapshotInfo])]
    param(
        [Parameter()]
        [string[]]$Paths = @(),

        [Parameter()]
        [string]$CustomSnapshotDir
    )

    if ($Paths.Count -eq 0) {
        $Paths = @([System.IO.Path]::GetTempPath())
    }

    $metadata = @{
        TargetModule = 'TempFiles'
        HostOS       = [System.Environment]::OSVersion.VersionString
        IsElevated   = (Test-IsElevated)
        PathCount    = $Paths.Count
    }

    return Export-PreRepairSnapshot -ModuleName 'TempFiles' -TargetPaths $Paths -Metadata $metadata -CustomSnapshotDir $CustomSnapshotDir
}
