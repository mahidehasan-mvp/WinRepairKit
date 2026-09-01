# WinRepairKit - Core Logger
# Dual-format structured logger (Human .log + Machine .jsonl)

function Get-RepairLogDirectory {
    [CmdletBinding()]
    param(
        [string]$CustomPath
    )

    if ($CustomPath -and (Test-Path -Path $CustomPath)) {
        return $CustomPath
    }

    $baseDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "WinRepairKit\logs"
    if (-not (Test-Path -Path $baseDir)) {
        New-Item -ItemType Directory -Path $baseDir -Force | Out-Null
    }
    return $baseDir
}

function Write-RepairLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',

        [Parameter(Position = 2)]
        [ValidateSet('SCAN', 'PLAN', 'REPAIR', 'SNAPSHOT', 'VERIFY', 'ELEVATION', 'CONSENT', 'SYSTEM', 'TEST')]
        [string]$Category = 'SYSTEM',

        [Parameter(Position = 3)]
        [string]$ModuleName = 'General',

        [Parameter()]
        [hashtable]$Data = @{},

        [Parameter()]
        [string]$LogDir,

        [Parameter()]
        [switch]$NoConsole,

        [Parameter()]
        [switch]$JsonConsole,

        [Parameter()]
        [switch]$PassThru
    )

    $utcNow = [datetime]::UtcNow
    $timestampIso = $utcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $timestampHuman = $utcNow.ToString("yyyy-MM-dd HH:mm:ss.fff")
    $dateStamp = $utcNow.ToString("yyyy-MM-dd")

    $resolvedLogDir = Get-RepairLogDirectory -CustomPath $LogDir
    $humanLogPath = Join-Path -Path $resolvedLogDir -ChildPath "winrepair-$dateStamp.log"
    $jsonLogPath = Join-Path -Path $resolvedLogDir -ChildPath "winrepair-$dateStamp.jsonl"

    $levelPadded = $Level.PadRight(7)
    $categoryPadded = $Category.PadRight(10)
    $modulePadded = $ModuleName.PadRight(14)
    $humanLine = "$timestampHuman  $levelPadded $categoryPadded $modulePadded $Message"

    # Append to human log file with safe retry
    try {
        [System.IO.File]::AppendAllText($humanLogPath, $humanLine + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
    }
    catch {
        # Fallback without failing operation
    }

    # Format JSON Line
    $jsonObj = [ordered]@{
        ts       = $timestampIso
        level    = $Level
        category = $Category
        module   = $ModuleName
        msg      = $Message
        data     = $Data
    }
    $jsonLine = $jsonObj | ConvertTo-Json -Compress -Depth 5

    try {
        [System.IO.File]::AppendAllText($jsonLogPath, $jsonLine + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
    }
    catch {
        # Fallback without failing operation
    }

    $shouldSuppressConsole = $NoConsole -or $global:WinRepairNoConsole -or ($env:WINREPAIR_NO_CONSOLE -eq '1')

    # Console output if not suppressed
    if (-not $shouldSuppressConsole) {
        if ($JsonConsole) {
            Write-Output $jsonLine
        }
        else {
            $color = switch ($Level) {
                'DEBUG'   { 'DarkGray' }
                'INFO'    { 'Gray' }
                'WARN'    { 'Yellow' }
                'ERROR'   { 'Red' }
                'SUCCESS' { 'Green' }
                Default   { 'White' }
            }
            Write-Host -ForegroundColor $color "[$Category] $Message"
        }
    }

    if ($PassThru) {
        return [PSCustomObject]@{
            Timestamp = $timestampIso
            Level     = $Level
            Category  = $Category
            Module    = $ModuleName
            Message   = $Message
            Data      = $Data
            HumanLine = $humanLine
            JsonLine  = $jsonLine
        }
    }
}
