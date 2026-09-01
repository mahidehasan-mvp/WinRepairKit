# WinRepairKit - Private Helper: Get-DriveRecycleBin
# Multi-signal inspection of $Recycle.Bin containers avoiding false positives on unresolvable SIDs

function Get-DriveRecycleBinInfo {
    [CmdletBinding()]
    param(
        [string]$DriveLetter
    )

    $drives = if ($DriveLetter) {
        Get-PSDrive -Name ($DriveLetter.TrimEnd(':\')) -ErrorAction SilentlyContinue
    }
    else {
        Get-PSDrive -PSProvider 'FileSystem' | Where-Object {
            $_.Root -match '^[A-Za-z]:\\$' -and (Test-Path $_.Root)
        }
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($drv in $drives) {
        $root = $drv.Root
        $rbPath = Join-Path -Path $root -ChildPath '$Recycle.Bin'
        $driveLetterClean = $drv.Name.ToUpper() + ":"

        $info = [ordered]@{
            DriveLetter       = $driveLetterClean
            VolumeName        = $drv.Description
            FreeSpaceBytes    = $drv.Free
            TotalSpaceBytes   = $drv.Used + $drv.Free
            RecycleBinPath    = $rbPath
            Exists            = $false
            IsAccessible      = $false
            IsReparsePoint    = $false
            TotalItemCount    = 0
            InaccessibleCount = 0
            CorruptedCount    = 0
            TotalSizeBytes    = 0
            InaccessibleBytes = 0
            SidFolders        = @()
            AccessErrors      = @()
        }

        if (Test-Path -LiteralPath $rbPath) {
            $info.Exists = $true

            # Signal 1: Root container readability & ACL check
            try {
                $rootItem = Get-Item -LiteralPath $rbPath -Force -ErrorAction Stop
                $info.IsReparsePoint = ($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
                $rootAcl = Get-Acl -LiteralPath $rbPath -ErrorAction Stop
                $info.IsAccessible = $true
            }
            catch {
                $info.IsAccessible = $false
                $info.AccessErrors += "Access Denied reading root ACL: $($_.Exception.Message)"
            }

            # Signal 2: Enumerate SID subfolders and hidden/system files
            try {
                $sidDirs = [System.IO.Directory]::GetDirectories($rbPath)
                $sidList = @()

                foreach ($sidDir in $sidDirs) {
                    $sidName = [System.IO.Path]::GetFileName($sidDir)
                    $sidInfo = [ordered]@{
                        Path              = $sidDir
                        Sid               = $sidName
                        IsAccessible      = $true
                        ItemCount         = 0
                        InaccessibleCount = 0
                        SizeBytes         = 0
                        HasPermissionLock = $false
                        Error             = $null
                    }

                    # Multi-signal check on this SID folder
                    try {
                        $dirInfo = [System.IO.DirectoryInfo]::new($sidDir)
                        $files = $dirInfo.GetFiles("*", [System.IO.SearchOption]::AllDirectories)
                        foreach ($f in $files) {
                            $sidInfo.ItemCount++
                            $sidInfo.SizeBytes += $f.Length
                            $info.TotalItemCount++
                            $info.TotalSizeBytes += $f.Length
                        }
                    }
                    catch [System.UnauthorizedAccessException] {
                        # Multi-signal confirmation: Directory is locked and cannot be enumerated normally
                        $sidInfo.IsAccessible = $false
                        $sidInfo.HasPermissionLock = $true
                        $sidInfo.Error = "UnauthorizedAccessException"
                        $info.AccessErrors += "Access denied inside SID directory '$sidName'"

                        # Deep inspection via cmd dir /a /s for hidden/system entries
                        try {
                            $dirEntries = cmd.exe /c "dir `"$sidDir`" /a /s 2>&1"
                            $inaccessibleCount = 0
                            $inaccessibleBytes = 0
                            foreach ($line in $dirEntries) {
                                if ($line -match "Access is denied" -or $line -match "File Not Found") {
                                    $inaccessibleCount++
                                }
                                elseif ($line -match "Total Files Listed:\s+(\d+)\s+File\(s\)\s+([\d,]+)\s+bytes") {
                                    $inaccessibleCount = [int64]$Matches[1]
                                    $inaccessibleBytes = [int64]($Matches[2] -replace ',','')
                                }
                            }
                            if ($inaccessibleCount -eq 0) {
                                $inaccessibleCount = 1
                            }
                            $sidInfo.InaccessibleCount = $inaccessibleCount
                            $info.InaccessibleCount += $inaccessibleCount
                            $info.InaccessibleBytes += $inaccessibleBytes
                        }
                        catch {
                            $sidInfo.InaccessibleCount = 1
                            $info.InaccessibleCount += 1
                        }
                    }
                    catch {
                        $sidInfo.IsAccessible = $false
                        $sidInfo.Error = $_.Exception.Message
                        $info.InaccessibleCount++
                    }

                    $sidList += [PSCustomObject]$sidInfo
                }
                $info.SidFolders = $sidList
            }
            catch {
                $info.AccessErrors += "Cannot enumerate SID subdirectories: $($_.Exception.Message)"
            }
        }

        $results.Add([PSCustomObject]$info)
    }

    return $results
}
