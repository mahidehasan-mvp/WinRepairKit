# WinRepairKit - Unit Tests: Types
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$moduleRoot = Join-Path -Path (Split-Path -Path (Split-Path -Path $scriptDir -Parent) -Parent) -ChildPath "src\Engine"
Import-Module -Name (Join-Path -Path $moduleRoot -ChildPath "WinRepairKit.psd1") -Force -DisableNameChecking

Describe "Types and Contracts" {
    Context "Finding class" {
        It "creates Finding with default values" {
            $f = [Finding]::new()
            $f.Id = "RB-001"
            $f.Title = "Access Denied"
            $f.Severity = [SeverityLevel]::Warning

            $f.Id | Should Be "RB-001"
            $f.SizeBytes | Should Be 0
            $f.FileCount | Should Be 0
        }
    }

    Context "PlanStep and RepairPlan classes" {
        It "adds steps and updates MaxRiskLevel properly" {
            $plan = [RepairPlan]::new()
            $plan.ModuleName = "RecycleBin"
            $plan.Title = "Test Plan"

            $plan.MaxRiskLevel | Should Be ([RiskLevel]::Safe)

            $step1 = [PlanStep]::new()
            $step1.StepNumber = 1
            $step1.Action = "Snapshot"
            $step1.RiskLevel = [RiskLevel]::Safe
            $plan.AddStep($step1)

            $plan.MaxRiskLevel | Should Be ([RiskLevel]::Safe)

            $step2 = [PlanStep]::new()
            $step2.StepNumber = 2
            $step2.Action = "Delete"
            $step2.RiskLevel = [RiskLevel]::Destructive
            $step2.RequiresAdmin = $true
            $step2.DataDestructive = $true
            $plan.AddStep($step2)

            $plan.MaxRiskLevel | Should Be ([RiskLevel]::Destructive)
            $plan.RequiresAdmin | Should Be $true
            $plan.DataDestructive | Should Be $true
            $plan.Steps.Count | Should Be 2
        }
    }

    Context "RepairResult class" {
        It "serializes cleanly to JSON" {
            $result = [RepairResult]::new()
            $result.ModuleName = "RecycleBin"
            $result.Status = [RepairStatus]::Healthy

            $json = $result | ConvertTo-Json -Depth 4
            ($null -ne $json) | Should Be $true

            $parsed = $json | ConvertFrom-Json
            $parsed.ModuleName | Should Be "RecycleBin"
        }
    }
}
