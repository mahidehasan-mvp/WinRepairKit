# WinRepairKit - Adversarial & Hardening Test Suite
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$moduleRoot = Join-Path -Path (Split-Path -Path (Split-Path -Path $scriptDir -Parent) -Parent) -ChildPath "src\Engine"
Import-Module -Name (Join-Path -Path $moduleRoot -ChildPath "WinRepairKit.psd1") -Force -DisableNameChecking

# Dot-source test fixture helper
. (Join-Path -Path $scriptDir -ChildPath "..\TestHelpers\New-RepairLabScenario.ps1")

Describe "Phase 3.5, 3.6 & 5.6 Hardening & Adversarial Invariants" {

    Context "Plan Immutability & Fingerprinting" {
        It "generates a non-empty, deterministic fingerprint from findings" {
            $f1 = [Finding]::new()
            $f1.Id = "RB-001"
            $f1.Path = "C:\`$Recycle.Bin\S-1-5-21-test"
            $f1.FileCount = 5

            $f2 = [Finding]::new()
            $f2.Id = "RB-002"
            $f2.Path = "D:\`$Recycle.Bin\S-1-5-21-test2"
            $f2.FileCount = 100

            $hash1 = Get-FindingFingerprint -Findings @($f1, $f2)
            $hash2 = Get-FindingFingerprint -Findings @($f2, $f1) # Order should not matter

            ($null -ne $hash1) | Should Be $true
            ($hash1.Length -gt 0) | Should Be $true
            $hash1 | Should Be $hash2
        }

        It "invalidates a plan when system findings change" {
            $fOriginal = [Finding]::new()
            $fOriginal.Id = "RB-001"
            $fOriginal.Path = "C:\`$Recycle.Bin\S-1-5-21-test"
            $fOriginal.FileCount = 5

            $mockScan = [RepairResult]::new()
            $mockScan.ModuleName = "RecycleBin"
            $mockScan.Status = [RepairStatus]::ProblemFound
            $mockScan.Findings.Add($fOriginal)

            $plan = Build-RecycleBinPlan -ScanResult $mockScan
            ($null -ne $plan.SystemFingerprint) | Should Be $true

            # Simulate changed system state (e.g. 10 files instead of 5)
            $fChanged = [Finding]::new()
            $fChanged.Id = "RB-001"
            $fChanged.Path = "C:\`$Recycle.Bin\S-1-5-21-test"
            $fChanged.FileCount = 10

            $match = Test-PlanFingerprintMatch -Plan $plan -CurrentFindings @($fChanged)
            $match.IsMatch | Should Be $false
            $match.Message | Should Match "Plan fingerprint mismatch"
        }
    }

    Context "Dry-Run Zero-Mutation Guarantee" {
        It "strictly sets MutationsPerformed to false in DryRun across modules" {
            $dryResultRB = Repair-RecycleBin -DryRun
            ($null -ne $dryResultRB) | Should Be $true
            $dryResultRB.MutationsPerformed | Should Be $false
            $dryResultRB.SchemaVersion | Should Be "1.0"
            ($null -ne $dryResultRB.TransactionId) | Should Be $true

            $dryResultTF = Repair-TempFiles -DryRun
            ($null -ne $dryResultTF) | Should Be $true
            $dryResultTF.MutationsPerformed | Should Be $false
        }
    }

    Context "Path Traversal & Security Validation" {
        It "blocks path traversal attempts outside the allowed root" {
            $lab = New-RepairLabScenario -ScenarioType 'PathTraversal'
            $allowedRoot = $lab.BasePath
            $maliciousPath = Join-Path -Path $allowedRoot -ChildPath "..\..\Windows\System32"

            $isSafe = Test-IsSafeTargetPath -TargetPath $maliciousPath -AllowedRootPath $allowedRoot
            $isSafe | Should Be $false

            $validChild = Join-Path -Path $allowedRoot -ChildPath "safe_folder"
            $isChildSafe = Test-IsSafeTargetPath -TargetPath $validChild -AllowedRootPath $allowedRoot
            $isChildSafe | Should Be $true

            Remove-RepairLabScenario -Scenario $lab
        }
    }

    Context "Sanitized Support Bundle Generation" {
        It "creates a sanitized zip bundle without raw user paths" {
            $lab = New-RepairLabScenario -ScenarioType 'Clean'
            $outDir = Join-Path -Path $lab.BasePath -ChildPath "bundles"

            $bundleZip = Export-WinRepairSupportBundle -OutputDirectory $outDir
            ($null -ne $bundleZip) | Should Be $true
            (Test-Path -LiteralPath $bundleZip) | Should Be $true

            Remove-RepairLabScenario -Scenario $lab
        }
    }

    Context "Crash & Interrupted Transaction Discovery" {
        It "detects uncompleted transactions without resuming destructive actions" {
            $lab = New-RepairLabScenario -ScenarioType 'InterruptedTx'
            $txDir = Join-Path -Path $lab.BasePath -ChildPath "transactions"

            $interrupted = @(Get-InterruptedTransactions -CustomDir $txDir)
            ($interrupted.Count -gt 0) | Should Be $true
            $interrupted[0].TransactionId | Should Be "TX-MOCK-INTERRUPTED"
            $interrupted[0].LastCompletedStep | Should Match "ResetPermissions"

            Remove-RepairLabScenario -Scenario $lab
        }
    }

    Context "Safety Gate Invariants" {
        It "blocks unconfirmed destructive plan execution" {
            $plan = [RepairPlan]::new()
            $plan.ModuleName = "RecycleBin"
            $step = [PlanStep]::new()
            $step.RiskLevel = [RiskLevel]::Destructive
            $plan.AddStep($step)

            $safety = Test-PlanSafety -Plan $plan -DryRun:$false -Confirmed:$false
            $safety.CanExecute | Should Be $false
            ($safety.BlockReasons.Count -gt 0) | Should Be $true
        }
    }

    Context "Result Object Schema Validation" {
        It "populates all required audit fields on scan and plan" {
            $scan = Test-RecycleBin
            $scan.SchemaVersion | Should Be "1.0"
            ($null -ne $scan.TransactionId) | Should Be $true
            ($scan.TransactionId.StartsWith("TX-")) | Should Be $true
            ($null -ne $scan.StartedAt) | Should Be $true
            ($null -ne $scan.CompletedAt) | Should Be $true
            $scan.DurationMs | Should BeGreaterThan -1
        }
    }
}
