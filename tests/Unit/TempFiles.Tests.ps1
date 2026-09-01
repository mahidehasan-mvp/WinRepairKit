# WinRepairKit - Unit Tests: TempFiles Module
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$moduleRoot = Join-Path -Path (Split-Path -Path (Split-Path -Path $scriptDir -Parent) -Parent) -ChildPath "src\Engine"
Import-Module -Name (Join-Path -Path $moduleRoot -ChildPath "WinRepairKit.psd1") -Force -DisableNameChecking

Describe "TempFiles Module" {
    Context "Test-TempFiles" {
        It "returns a valid RepairResult object" {
            $scan = Test-TempFiles
            ($null -ne $scan) | Should Be $true
            $scan.ModuleName | Should Be "TempFiles"
            $scan.SupportsDryRun | Should Be $true
            $scan.DataDestructive | Should Be $false
        }
    }

    Context "Build-TempFilesPlan" {
        It "creates a categorized cleanup plan" {
            $plan = Build-TempFilesPlan
            ($null -ne $plan) | Should Be $true
            $plan.ModuleName | Should Be "TempFiles"
            $plan.SupportsDryRun | Should Be $true
        }
    }

    Context "Repair-TempFiles in DryRun" {
        It "strictly does not mutate files and sets MutationsPerformed to false" {
            $dryResult = Repair-TempFiles -DryRun
            ($null -ne $dryResult) | Should Be $true
            $dryResult.MutationsPerformed | Should Be $false
            ("$($dryResult.Status)" -in @("Healthy", "Skipped")) | Should Be $true
        }
    }
}
