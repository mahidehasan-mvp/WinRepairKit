# WinRepairKit - Snapshot Manager
# Handles pre-repair state snapshots (ACLs, metadata, manifests)
# Note: State snapshot != Data backup. File contents are not restored.

function Get-SnapshotBaseDirectory {
    [CmdletBinding()]
    param(
        [string]$CustomPath
    )

    if ($CustomPath -and (Test-Path -Path $CustomPath)) {
        return $CustomPath
    }

    $baseDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "WinRepairKit\snapshots"
    if (-not (Test-Path -Path $baseDir)) {
        New-Item -ItemType Directory -Path $baseDir -Force | Out-Null
    }
    return $baseDir
}

function Export-PreRepairSnapshot {
    <#
    .SYNOPSIS
        Exports a pre-repair state snapshot including ACLs, file paths, counts, and metadata.
    #>
    [CmdletBinding()]
    [OutputType([SnapshotInfo])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter()]
        [string[]]$TargetPaths = @(),

        [Parameter()]
        [hashtable]$Metadata = @{},

        [Parameter()]
        [string]$CustomSnapshotDir
    )

    $timestamp = [datetime]::UtcNow
    $snapshotId = "$ModuleName-" + $timestamp.ToString("yyyyMMdd-HHmmss")
    $baseDir = Get-SnapshotBaseDirectory -CustomPath $CustomSnapshotDir
    $snapshotDir = Join-Path -Path $baseDir -ChildPath $snapshotId

    if (-not (Test-Path -Path $snapshotDir)) {
        New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
    }

    $manifestPath = Join-Path -Path $snapshotDir -ChildPath "manifest.json"
    $aclPath = Join-Path -Path $snapshotDir -ChildPath "acls.txt"

    Write-RepairLog -Message "Creating state snapshot '$snapshotId' in $snapshotDir" -Level 'INFO' -Category 'SNAPSHOT' -ModuleName $ModuleName

    $itemManifest = [System.Collections.Generic.List[PSCustomObject]]::new()
    $aclOutput = [System.Collections.Generic.List[string]]::new()
    [int64]$totalItemsCounted = 0

    foreach ($path in $TargetPaths) {
        if (-not (Test-Path -LiteralPath $path -ErrorAction SilentlyContinue)) {
            continue
        }

        # Attempt to capture ACL
        try {
            $acl = Get-Acl -LiteralPath $path -ErrorAction SilentlyContinue
            if ($acl) {
                $aclOutput.Add("=== PATH: $path ===")
                $aclOutput.Add("Owner: $($acl.Owner)")
                $aclOutput.Add("AccessToString: $($acl.AccessToString)")
                $aclOutput.Add("Sddl: $($acl.Sddl)")
                $aclOutput.Add("")
            }
        }
        catch {
            $aclOutput.Add("=== PATH: $path (Access Denied / Failed to read ACL) ===")
        }

        # Attempt icacls save if possible
        try {
            $icaclsBackupFile = Join-Path -Path $snapshotDir -ChildPath "icacls-$([System.IO.Path]::GetFileNameWithoutExtension($path)).acl"
            & icacls "$path" /save "$icaclsBackupFile" /t /c /q 2>$null
        }
        catch {}

        # Capture item metadata
        try {
            $items = Get-ChildItem -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
            if ($items) {
                foreach ($item in $items) {
                    $totalItemsCounted++
                    $itemManifest.Add([PSCustomObject]@{
                        FullName     = $item.FullName
                        Name         = $item.Name
                        Length       = if ($item.PSIsContainer) { 0 } else { $item.Length }
                        IsDirectory  = $item.PSIsContainer
                        CreationTime = $item.CreationTimeUtc.ToString("o")
                        LastWrite    = $item.LastWriteTimeUtc.ToString("o")
                        Attributes   = $item.Attributes.ToString()
                    })
                }
            }
        }
        catch {}
    }

    # Save ACLs
    if ($aclOutput.Count -gt 0) {
        [System.IO.File]::WriteAllLines($aclPath, $aclOutput, [System.Text.Encoding]::UTF8)
    }

    # Save Manifest JSON
    $manifestData = [ordered]@{
        SnapshotId   = $snapshotId
        ModuleName   = $ModuleName
        TimestampUtc = $timestamp.ToString("o")
        TargetPaths  = $TargetPaths
        ItemCount    = $totalItemsCounted
        Metadata     = $Metadata
        Disclaimer   = "This is a metadata/state snapshot. File contents are not backed up."
        Items        = $itemManifest
    }

    $manifestJson = $manifestData | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($manifestPath, $manifestJson, [System.Text.Encoding]::UTF8)

    $snapshotInfo = [SnapshotInfo]::new()
    $snapshotInfo.SnapshotId = $snapshotId
    $snapshotInfo.ModuleName = $ModuleName
    $snapshotInfo.Timestamp = $timestamp
    $snapshotInfo.Path = $snapshotDir
    $snapshotInfo.ManifestFile = $manifestPath
    $snapshotInfo.AclFile = $aclPath
    $snapshotInfo.ItemCount = $totalItemsCounted
    $snapshotInfo.Metadata = $Metadata

    Write-RepairLog -Message "State snapshot completed ($totalItemsCounted items recorded)" -Level 'SUCCESS' -Category 'SNAPSHOT' -ModuleName $ModuleName -Data @{
        SnapshotId = $snapshotId
        Path       = $snapshotDir
        ItemCount  = $totalItemsCounted
    }

    return $snapshotInfo
}

function Get-RepairSnapshots {
    <#
    .SYNOPSIS
        Lists existing state snapshots.
    #>
    [CmdletBinding()]
    param(
        [string]$ModuleName
    )

    $baseDir = Get-SnapshotBaseDirectory
    $dirs = Get-ChildItem -Path $baseDir -Directory -ErrorAction SilentlyContinue

    $results = @()
    foreach ($dir in $dirs) {
        $manifestPath = Join-Path -Path $dir.FullName -ChildPath "manifest.json"
        if (Test-Path -LiteralPath $manifestPath) {
            try {
                $content = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
                if (-not $ModuleName -or $content.ModuleName -eq $ModuleName) {
                    $results += [PSCustomObject]@{
                        SnapshotId   = $content.SnapshotId
                        ModuleName   = $content.ModuleName
                        TimestampUtc = $content.TimestampUtc
                        ItemCount    = $content.ItemCount
                        Path         = $dir.FullName
                    }
                }
            }
            catch {}
        }
    }

    return $results
}
