# WinRepairKit - Strongly Typed Data Contracts & Schema v1.0
# Reference: docs/architecture.md and docs/safety-model.md

enum RiskLevel {
    Safe        = 0
    Elevated    = 1
    Destructive = 2
}

enum RepairStatus {
    Healthy         = 0
    ProblemFound    = 1
    RepairSucceeded = 2
    RepairPartial   = 3
    RepairFailed    = 4
    Skipped         = 5
    Error           = 6
    PlanInvalidated = 7
}

enum SeverityLevel {
    Info     = 0
    Warning  = 1
    Error    = 2
    Critical = 3
}

enum LogLevel {
    DEBUG   = 0
    INFO    = 1
    WARN    = 2
    ERROR   = 3
    SUCCESS = 4
}

class ConsequenceInfo {
    [bool]$DataLossPossible = $false
    [bool]$Reversible       = $true
    [bool]$BackupCreated    = $false
    [bool]$SnapshotCreated  = $true
}

class Finding {
    [string]$Id                 = ""
    [SeverityLevel]$Severity    = [SeverityLevel]::Warning
    [string]$Title              = ""
    [string]$Detail             = ""
    [string]$Path               = ""
    [int64]$SizeBytes           = 0
    [int64]$FileCount           = 0
    [string]$Fingerprint        = ""
    [hashtable]$ExtraData       = @{}
}

class PlanStep {
    [int]$StepNumber            = 1
    [string]$Action             = ""
    [string]$Description        = ""
    [RiskLevel]$RiskLevel       = [RiskLevel]::Safe
    [bool]$RequiresAdmin        = $false
    [bool]$DataDestructive      = $false
    [bool]$CanRollback          = $false
    [hashtable]$Parameters      = @{}
}

class RepairPlan {
    [string]$PlanId                          = ""
    [string]$ModuleName                      = ""
    [string]$Title                           = ""
    [string]$Description                     = ""
    [System.Collections.Generic.List[PlanStep]]$Steps = [System.Collections.Generic.List[PlanStep]]::new()
    [RiskLevel]$MaxRiskLevel                 = [RiskLevel]::Safe
    [bool]$RequiresAdmin                     = $false
    [bool]$DataDestructive                   = $false
    [bool]$SupportsDryRun                    = $true
    [string]$Disclaimer                      = ""
    [string]$ExplicitDisclaimer              = ""
    [ConsequenceInfo]$Consequence            = [ConsequenceInfo]::new()
    [System.Collections.Generic.List[string]]$WhatWillNotHappen = [System.Collections.Generic.List[string]]::new()
    [string]$SystemFingerprint               = ""
    [datetime]$GeneratedAtUtc                = [datetime]::UtcNow

    RepairPlan() {
        $this.PlanId = "PLAN-" + [Guid]::NewGuid().ToString("N").Substring(0, 12).ToUpper()
    }

    [void] AddStep([PlanStep]$step) {
        $this.Steps.Add($step)
        if ($step.RiskLevel -gt $this.MaxRiskLevel) {
            $this.MaxRiskLevel = $step.RiskLevel
        }
        if ($step.RequiresAdmin) {
            $this.RequiresAdmin = $true
        }
        if ($step.DataDestructive) {
            $this.DataDestructive = $true
        }
    }
}

class SnapshotInfo {
    [string]$SnapshotId         = ""
    [string]$ModuleName         = ""
    [datetime]$TimestampUtc     = [datetime]::UtcNow
    [string]$Path               = ""
    [int64]$ItemCount           = 0
    [hashtable]$Metadata        = @{}

    SnapshotInfo() {
        $this.SnapshotId = "SNAP-" + [Guid]::NewGuid().ToString("N").Substring(0, 12).ToUpper()
    }
}

class VerificationResult {
    [bool]$Passed                            = $false
    [int]$RemainingProblemsCount             = 0
    [string]$Message                         = ""
    [System.Collections.Generic.List[Finding]]$RemainingFindings = [System.Collections.Generic.List[Finding]]::new()
}

class RepairResult {
    # Schema Metadata
    [string]$SchemaVersion                   = "1.0"
    [string]$TransactionId                   = ""
    [string]$PlanId                          = ""
    [string]$ModuleName                      = ""

    # Execution State
    [RepairStatus]$Status                    = [RepairStatus]::Healthy
    [RiskLevel]$RiskLevel                    = [RiskLevel]::Safe
    [bool]$RequiresAdmin                     = $false
    [bool]$CanRepair                         = $false
    [bool]$SupportsDryRun                    = $true
    [bool]$DataDestructive                   = $false
    [bool]$MutationsPerformed                = $false
    [bool]$RollbackAvailable                 = $false
    [bool]$RequiresReboot                    = $false

    # Detailed Collections
    [System.Collections.Generic.List[Finding]]$Findings         = [System.Collections.Generic.List[Finding]]::new()
    [RepairPlan]$Plan                                           = $null
    [System.Collections.Generic.List[string]]$Recommendations   = [System.Collections.Generic.List[string]]::new()
    [SnapshotInfo]$Snapshot                                     = $null
    [VerificationResult]$Verification                           = $null

    # Diagnostics Timing
    [datetime]$StartedAt                     = [datetime]::UtcNow
    [datetime]$CompletedAt                   = [datetime]::UtcNow
    [int64]$DurationMs                       = 0

    RepairResult() {
        $this.TransactionId = "TX-" + [Guid]::NewGuid().ToString("N").Substring(0, 12).ToUpper()
    }
}
