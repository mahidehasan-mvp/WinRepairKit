# WinRepairKit Architecture

## Overview

WinRepairKit is structured around a decoupled, safety-first architecture separating the privileged execution engine, the command-line interface, and future GUI frontends.

```
┌──────────────────────────┐
│  GUI (C# / .NET 10 WPF)  │  (Phase 5)
└────────────┬─────────────┘
             │  JSON v1.0 / Process Stream (stdin/stdout)
             ▼
┌──────────────────────────┐
│ WinRepair CLI (PowerShell│  src/CLI/winrepair.ps1 (Strict Exit Codes)
└────────────┬─────────────┘
             │  Loads module & executes cmdlets
             ▼
┌──────────────────────────┐
│ WinRepairKit Engine      │  src/Engine/WinRepairKit.psd1
│  ├── Core Components     │  Types, Safety, Elevation, Logging, Snapshots, Plans, Transactions
│  └── Pluggable Modules   │  RecycleBin, TempFiles, SystemFiles (v0.3)...
└──────────────────────────┘
```

---

## 1. Core Principles

1. **Diagnose → Explain → Plan → Repair → Verify**
   - No hidden actions. Every fix is planned, risk-evaluated, and verified.
2. **Process Separation**
   - The GUI does not embed unmanaged runspaces directly into its UI thread; it invokes `winrepair.ps1` with the `-Json` flag. This isolates crashes, memory leaks, and privileged execution from the user interface.
3. **Plan Immutability & Deterministic Fingerprints**
   - Plans are fingerprinted with SHA-256 state hashes. Re-scan confirms state before executing mutations.
4. **Crash & Interrupted Repair Recovery**
   - On startup, the engine detects orphaned transactions without automatically resuming destructive repairs, prompting for fresh diagnostics.
5. **Strict Safety Contracts**
   - Operations must declare their `RiskLevel` (`Safe`, `Elevated`, `Destructive`).
   - Destructive operations require explicit authorization (`-ConfirmFix`) or simulation (`-DryRun`).

---

## 2. CLI Exit Code Contract

For sysadmin scripts, CI pipelines, and orchestrators:

| Code | Meaning |
|---|---|
| `0` | Success / Healthy |
| `1` | Problems detected (on scan / verify) |
| `2` | Repair failed |
| `3` | Repair partially succeeded |
| `4` | User cancelled / Confirmation missing |
| `5` | Elevation required / denied |
| `6` | Stale plan (fingerprint mismatch) |
| `7` | Invalid arguments |
| `8` | Internal engine error |

---

## 3. JSON Schema v1.0

The frozen JSON contract for CLI and GUI communication:

```json
{
  "SchemaVersion": "1.0",
  "TransactionId": "TX-6AE1031EEF2F",
  "PlanId": "PLAN-BD80CEDD736A",
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
  "Findings": [
    {
      "Id": "RB-001",
      "Severity": 1,
      "Title": "5 inaccessible item(s) detected on D:",
      "Detail": "Permission locks prevent standard Windows deletion in D:\\$Recycle.Bin.",
      "Path": "D:\\$Recycle.Bin",
      "SizeBytes": 0,
      "FileCount": 5,
      "Fingerprint": "...",
      "ExtraData": {}
    }
  ],
  "Plan": {
    "PlanId": "PLAN-BD80CEDD736A",
    "SystemFingerprint": "076cda93e07c2a65",
    "MaxRiskLevel": 2,
    "Steps": []
  },
  "Snapshot": null,
  "Verification": null,
  "StartedAt": "2026-08-23T14:24:09.287Z",
  "CompletedAt": "2026-08-23T14:24:09.650Z",
  "DurationMs": 402
}
```
