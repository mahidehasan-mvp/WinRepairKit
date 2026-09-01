# WinRepairKit - Unit Tests: SafetyManager
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$moduleRoot = Join-Path -Path (Split-Path -Path (Split-Path -Path $scriptDir -Parent) -Parent) -ChildPath "src\Engine"
Import-Module -Name (Join-Path -Path $moduleRoot -ChildPath "WinRepairKit.psd1") -Force -DisableNameChecking

Describe "SafetyManager" {
    Context "Test-PlanSafety" {
        It "allows Safe plan execution without confirmation" {
            $plan = [RepairPlan]::new()
            $plan.ModuleName = "RecycleBin"
            $step = [PlanStep]::new()
            $step.RiskLevel = [RiskLevel]::Safe
            $plan.AddStep($step)

            $safety = Test-PlanSafety -Plan $plan
            $safety.CanExecute | Should Be $true
        }

        It "blocks Destructive plan without -Confirmed and without -DryRun" {
            $plan = [RepairPlan]::new()
            $plan.ModuleName = "RecycleBin"
            $step = [PlanStep]::new()
            $step.RiskLevel = [RiskLevel]::Destructive
            $plan.AddStep($step)

            $safety = Test-PlanSafety -Plan $plan
            $safety.CanExecute | Should Be $false
            ($safety.BlockReasons.Count -gt 0) | Should Be $true
        }

        It "allows Destructive plan in DryRun mode" {
            $plan = [RepairPlan]::new()
            $plan.ModuleName = "RecycleBin"
            $step = [PlanStep]::new()
            $step.RiskLevel = [RiskLevel]::Destructive
            $plan.AddStep($step)

            $safety = Test-PlanSafety -Plan $plan -DryRun
            $safety.CanExecute | Should Be $true
            $safety.IsDryRun | Should Be $true
        }

        It "allows Destructive plan when Confirmed" {
            $plan = [RepairPlan]::new()
            $plan.ModuleName = "RecycleBin"
            $step = [PlanStep]::new()
            $step.RiskLevel = [RiskLevel]::Destructive
            $step.RequiresAdmin = $false
            $plan.AddStep($step)

            $safety = Test-PlanSafety -Plan $plan -Confirmed
            $safety.CanExecute | Should Be $true
        }
    }
}
