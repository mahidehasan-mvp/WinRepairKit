# WinRepairKit - Private Helper: Format-FileSize

function Format-FileSize {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [int64]$Bytes
    )

    if ($Bytes -lt 0) { return "0 B" }
    if ($Bytes -eq 0) { return "0 B" }

    $units = @("B", "KB", "MB", "GB", "TB", "PB")
    $i = 0
    $dBytes = [double]$Bytes

    while ($dBytes -ge 1024 -and $i -lt ($units.Count - 1)) {
        $dBytes /= 1024
        $i++
    }

    if ($i -eq 0) {
        return "$([int]$dBytes) $($units[$i])"
    }
    return "$([Math]::Round($dBytes, 2)) $($units[$i])"
}
