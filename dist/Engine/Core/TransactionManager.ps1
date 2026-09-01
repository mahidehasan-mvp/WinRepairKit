# WinRepairKit - Transaction Manager
# Tracks repair transaction lifecycle and handles crash/interruption detection safely.
# Invariant: Never automatically resume an interrupted destructive repair.

function Get-TransactionDirectory {
    [CmdletBinding()]
    param([string]$CustomPath)

    if ($CustomPath -and (Test-Path -Path $CustomPath)) {
        return $CustomPath
    }

    $baseDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "WinRepairKit\transactions"
    if (-not (Test-Path -Path $baseDir)) {
        New-Item -ItemType Directory -Path $baseDir -Force | Out-Null
    }
    return $baseDir
}

function Start-RepairTransaction {
    <#
    .SYNOPSIS
        Initializes an on-disk transaction journal before mutations begin.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TransactionId,

        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter(Mandatory = $true)]
        [RepairPlan]$Plan,

        [Parameter()]
        [string]$CustomDir
    )

    $txDir = Get-TransactionDirectory -CustomPath $CustomDir
    $txFile = Join-Path -Path $txDir -ChildPath "$TransactionId.json"

    $txState = [ordered]@{
        TransactionId       = $TransactionId
        ModuleName          = $ModuleName
        PlanId              = $Plan.PlanId
        SystemFingerprint   = $Plan.SystemFingerprint
        MaxRiskLevel        = "$($Plan.MaxRiskLevel)"
        Status              = "InProgress"
        StartedAtUtc        = [datetime]::UtcNow.ToString("o")
        CompletedAtUtc      = $null
        CurrentStepNumber   = 0
        CurrentStepAction   = "Initializing"
        CompletedSteps      = @()
        SnapshotId          = $null
        Interrupted         = $false
    }

    $json = $txState | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($txFile, $json, [System.Text.Encoding]::UTF8)

    Write-RepairLog -Message "Transaction $TransactionId journaled in $txFile" -Level 'DEBUG' -Category 'SYSTEM' -ModuleName $ModuleName
    return [PSCustomObject]$txState
}

function Update-RepairTransaction {
    <#
    .SYNOPSIS
        Updates active transaction progress (steps completed, snapshots attached).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TransactionId,

        [Parameter()]
        [int]$StepNumber,

        [Parameter()]
        [string]$StepAction,

        [Parameter()]
        [string]$SnapshotId,

        [Parameter()]
        [string]$Status,

        [Parameter()]
        [string]$CustomDir
    )

    $txDir = Get-TransactionDirectory -CustomPath $CustomDir
    $txFile = Join-Path -Path $txDir -ChildPath "$TransactionId.json"

    if (-not (Test-Path -LiteralPath $txFile)) {
        return
    }

    try {
        $txState = Get-Content -LiteralPath $txFile -Raw | ConvertFrom-Json
        if ($StepNumber -gt 0) {
            $txState.CurrentStepNumber = $StepNumber
            $txState.CurrentStepAction = $StepAction
            $txState.CompletedSteps += "$StepNumber : $StepAction"
        }
        if ($SnapshotId) {
            $txState.SnapshotId = $SnapshotId
        }
        if ($Status) {
            $txState.Status = $Status
            if ($Status -in @('Completed', 'Failed', 'PartialFailure')) {
                $txState.CompletedAtUtc = [datetime]::UtcNow.ToString("o")
            }
        }

        $json = $txState | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($txFile, $json, [System.Text.Encoding]::UTF8)
    }
    catch {
        Write-RepairLog -Message "Warning: Failed to update transaction journal: $_" -Level 'WARN' -Category 'SYSTEM'
    }
}

function Complete-RepairTransaction {
    <#
    .SYNOPSIS
        Marks a transaction as completed cleanly.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TransactionId,

        [Parameter()]
        [ValidateSet('Completed', 'PartialFailure', 'Failed')]
        [string]$FinalStatus = 'Completed',

        [Parameter()]
        [string]$CustomDir
    )

    Update-RepairTransaction -TransactionId $TransactionId -Status $FinalStatus -CustomDir $CustomDir
}

function Get-InterruptedTransactions {
    <#
    .SYNOPSIS
        Discovers any orphaned transactions that started but never cleanly completed.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param([string]$CustomDir)

    $txDir = Get-TransactionDirectory -CustomPath $CustomDir
    $files = Get-ChildItem -Path $txDir -Filter "*.json" -ErrorAction SilentlyContinue

    $interrupted = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($f in $files) {
        try {
            $state = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
            if ($state.Status -eq 'InProgress') {
                $obj = [PSCustomObject]@{
                    TransactionId     = $state.TransactionId
                    ModuleName        = $state.ModuleName
                    PlanId            = $state.PlanId
                    StartedAtUtc      = $state.StartedAtUtc
                    LastCompletedStep = if ($state.CompletedSteps.Count -gt 0) { $state.CompletedSteps[-1] } else { 'None' }
                    FilePath          = $f.FullName
                }
                $interrupted.Add($obj)
            }
        }
        catch {}
    }

    return $interrupted.ToArray()
}
