# WinRepairKit - Unit Tests: RecycleBin Module
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$moduleRoot = Join-Path -Path (Split-Path -Path (Split-Path -Path $scriptDir -Parent) -Parent) -ChildPath "src\Engine"
Import-Module -Name (Join-Path -Path $moduleRoot -ChildPath "WinRepairKit.psd1") -Force -DisableNameChecking

Describe "RecycleBin Module" {
    Context "Test-RecycleBin" {
        It "returns a valid RepairResult object" {
            $scan = Test-RecycleBin
            ($null -ne $scan) | Should Be $true
            $scan.ModuleName | Should Be "RecycleBin"
            $scan.SupportsDryRun | Should Be $true
        }
    }

    Context "Build-RecycleBinPlan" {
        It "creates a structured plan" {
            $plan = Build-RecycleBinPlan
            ($null -ne $plan) | Should Be $true
            $plan.ModuleName | Should Be "RecycleBin"
        }

        It "generates multi-step plan when problems are found" {
            $mockResult = [RepairResult]::new()
            $mockResult.ModuleName = "RecycleBin"
            $mockResult.Status = [RepairStatus]::ProblemFound

            $finding = [Finding]::new()
            $finding.Id = "RB-001"
            $finding.Title = "100 inaccessible items"
            $finding.Path = "C:\`$Recycle.Bin\S-1-5-21-test"
            $mockResult.Findings.Add($finding)

            $plan = Build-RecycleBinPlan -ScanResult $mockResult
            ($plan.Steps.Count -gt 0) | Should Be $true
            $plan.MaxRiskLevel | Should Be ([RiskLevel]::Destructive)
            $plan.RequiresAdmin | Should Be $true
            $plan.DataDestructive | Should Be $true
            $plan.ExplicitDisclaimer | Should Match "state snapshot does not contain the original file contents"
            ($plan.WhatWillNotHappen.Count -gt 0) | Should Be $true
        }
    }

    Context "Repair-RecycleBin in DryRun" {
        It "returns Skipped status in DryRun without making changes" {
            $dryResult = Repair-RecycleBin -DryRun
            ($null -ne $dryResult) | Should Be $true
            ("$($dryResult.Status)" -in @("Healthy", "Skipped")) | Should Be $true
        }
    }
}
