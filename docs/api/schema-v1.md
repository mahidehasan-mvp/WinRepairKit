# WinRepairKit JSON API Schema v1.0

This document defines the frozen **Schema Version 1.0** contract between the WinRepairKit Engine (`PowerShell 5.1+`), the Command-Line Interface (`winrepair.ps1`), and client applications (such as the WPF Desktop App).

---

## 1. Top-Level Objects

### 1.1 `RepairResult` (Scan & Repair Output)

```json
{
  "SchemaVersion": "1.0",
  "TransactionId": "TX-A1B2C3D4E5F6",
  "PlanId": "PLAN-9876543210AB",
  "ModuleName": "RecycleBin",
  "Status": 1,
  "RiskLevel": 2,
  "RequiresAdmin": true,
  "CanRepair": true,
  "SupportsDryRun": true,
  "DataDestructive": true,
  "MutationsPerformed": false,
  "RollbackAvailable": false,
  "RequiresReboot": false,
  "Findings": [],
  "Plan": null,
  "Recommendations": [],
  "Snapshot": null,
  "Verification": null,
  "StartedAt": "2026-08-23T15:00:00.000Z",
  "CompletedAt": "2026-08-23T15:00:00.350Z",
  "DurationMs": 350
}
```

### 1.2 `RepairStatus` Enum Values

| Integer | Status Name | Meaning |
|:---:|---|---|
| `0` | `Healthy` | Component is healthy, no action required. |
| `1` | `ProblemFound` | Diagnostic issues detected. |
| `2` | `RepairSucceeded` | All repair operations succeeded and verified. |
| `3` | `RepairPartial` | Some issues fixed, but remaining problems exist. |
| `4` | `RepairFailed` | Repair failed to resolve detected problems. |
| `5` | `Skipped` | Dry-run simulation completed with 0 mutations. |
| `6` | `Error` | Execution error or abort by safety manager. |
| `7` | `PlanInvalidated` | System state changed after plan generation (stale plan). |

### 1.3 `RiskLevel` Enum Values

| Integer | Risk Name | Meaning |
|:---:|---|---|
| `0` | `Safe` | Read-only or completely reversible maintenance. |
| `1` | `Elevated` | Requires Administrator privileges (e.g. permission resets). |
| `2` | `Destructive` | Permanent deletion or state reset requiring explicit user consent. |

---

## 2. RepairPlan & Consequence Model

```json
{
  "PlanId": "PLAN-BD80CEDD736A",
  "ModuleName": "RecycleBin",
  "Title": "Recycle Bin Health & Permission Repair",
  "Description": "Repairs corrupted directory permissions...",
  "MaxRiskLevel": 2,
  "RequiresAdmin": true,
  "DataDestructive": true,
  "SupportsDryRun": true,
  "ExplicitDisclaimer": "I understand that this repair may permanently remove the affected Recycle Bin entries and that WinRepairKit's state snapshot does not contain the original file contents.",
  "Consequence": {
    "DataLossPossible": true,
    "Reversible": false,
    "BackupCreated": false,
    "SnapshotCreated": true
  },
  "WhatWillNotHappen": [
    "No healthy files outside affected Recycle Bin SID folders will be modified.",
    "No registry cleaning or background system modifications will occur.",
    "The repair will NOT escalate to destructive deletion if permission resets fail (No Blind Escalation).",
    "Diagnostics and file records remain strictly local on this PC."
  ],
  "SystemFingerprint": "076cda93e07c2a65",
  "GeneratedAtUtc": "2026-08-23T15:00:00Z",
  "Steps": [
    {
      "StepNumber": 1,
      "Action": "Export State Snapshot",
      "Description": "Export ACLs and metadata...",
      "RiskLevel": 0,
      "RequiresAdmin": false,
      "DataDestructive": false,
      "CanRollback": false,
      "Parameters": {}
    }
  ]
}
```
