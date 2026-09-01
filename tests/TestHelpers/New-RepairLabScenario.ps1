# WinRepairKit - Lab Fixture Scenario Builder
# Creates isolated temporary directory trees to simulate repair states without harming host system.

function New-RepairLabScenario {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Clean', 'LockedFiles', 'StalePlan', 'InterruptedTx', 'TempBuildup', 'PathTraversal', 'JunctionMock')]
        [string]$ScenarioType,

        [Parameter()]
        [string]$BaseTestDir
    )

    if (-not $BaseTestDir) {
        $BaseTestDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("WinRepairLab_" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
    }

    if (-not (Test-Path -LiteralPath $BaseTestDir)) {
        New-Item -ItemType Directory -Path $BaseTestDir -Force | Out-Null
    }

    $scenarioInfo = [ordered]@{
        ScenarioType = $ScenarioType
        BasePath     = $BaseTestDir
        Resources    = @()
        CleanupItems = [System.Collections.Generic.List[string]]::new()
    }
    $scenarioInfo.CleanupItems.Add($BaseTestDir)

    switch ($ScenarioType) {
        'TempBuildup' {
            $oldDate = (Get-Date).AddDays(-3)
            for ($i = 1; $i -le 10; $i++) {
                $filePath = Join-Path -Path $BaseTestDir -ChildPath "test_stale_$i.tmp"
                [System.IO.File]::WriteAllText($filePath, "Test data payload $i")
                (Get-Item -LiteralPath $filePath).LastWriteTime = $oldDate
                $scenarioInfo.Resources += $filePath
            }
        }

        'LockedFiles' {
            $lockedPath = Join-Path -Path $BaseTestDir -ChildPath "active_installer.tmp"
            [System.IO.File]::WriteAllText($lockedPath, "Active installer in progress")
            # Open handle and keep open
            $stream = [System.IO.File]::Open($lockedPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
            $scenarioInfo.Resources += @{ Path = $lockedPath; Stream = $stream }
        }

        'InterruptedTx' {
            $txDir = Join-Path -Path $BaseTestDir -ChildPath "transactions"
            New-Item -ItemType Directory -Path $txDir -Force | Out-Null
            $txId = "TX-MOCK-INTERRUPTED"
            $mockTxState = [ordered]@{
                TransactionId     = $txId
                ModuleName        = "RecycleBin"
                PlanId            = "PLAN-MOCK-1234"
                Status            = "InProgress"
                StartedAtUtc      = [datetime]::UtcNow.AddMinutes(-30).ToString("o")
                CompletedSteps    = @("1 : ExportSnapshot", "2 : ResetPermissions")
                CurrentStepNumber = 3
                CurrentStepAction = "TakeOwnership"
            }
            $txFile = Join-Path -Path $txDir -ChildPath "$txId.json"
            $mockTxState | ConvertTo-Json | Set-Content -LiteralPath $txFile
            $scenarioInfo.Resources += $txFile
        }

        'PathTraversal' {
            $subFolder = Join-Path -Path $BaseTestDir -ChildPath "safe_folder"
            New-Item -ItemType Directory -Path $subFolder -Force | Out-Null
            $scenarioInfo.Resources += $subFolder
        }
    }

    return [PSCustomObject]$scenarioInfo
}

function Remove-RepairLabScenario {
    [CmdletBinding()]
    param([PSCustomObject]$Scenario)

    if (-not $Scenario) { return }

    if ($Scenario.Resources) {
        foreach ($r in $Scenario.Resources) {
            if ($r -is [hashtable] -and $r.ContainsKey('Stream') -and $r.Stream) {
                try { $r.Stream.Close() } catch {}
            }
        }
    }

    if ($Scenario.BasePath -and (Test-Path -LiteralPath $Scenario.BasePath)) {
        try {
            Remove-Item -LiteralPath $Scenario.BasePath -Recurse -Force -ErrorAction SilentlyContinue
        }
        catch {}
    }
}
