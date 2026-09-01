# WinRepairKit Versioning & Changelog

## Current Release: v0.1.0 (Pre-Beta — Phase 5.6)

- **Product Name**: WinRepairKit (Windows 10 & 11 Repair & Maintenance Toolkit)
- **Schema Version**: `1.0` (Frozen JSON Contract)
- **Engine Version**: `0.1.0`
- **CLI Version**: `0.1.0`
- **GUI Application Version**: `0.1.0`
- **Installer Version**: `0.1.0` (`WinRepairKit.Setup.exe`)
- **License**: MIT License
- **Supported OS**: Windows 10 (Build 1809+ / 10.0.17763) and Windows 11 (22H2 / 23H2 / 24H2)

---

## 🏛️ Component Version Matrix

| Component | Target Framework / Runtime | Status | Current Version |
|---|---|---|---|
| **Core Engine** | PowerShell 5.1 & Core 7+ | Stable / Frozen | `0.1.0` |
| **JSON API Contract** | JSON Schema v1.0 | Stable / Frozen | `1.0` |
| **CLI Wrapper (`winrepair.ps1`)** | PowerShell 5.1+ | Feature Complete | `0.1.0` |
| **RecycleBin Module** | Native Windows CLI (`icacls`, `takeown`) | Hardened | `0.1.0` |
| **TempFiles Module** | Native Windows File APIs | Hardened | `0.1.0` |
| **WPF GUI Client** | .NET 8 WPF + CommunityToolkit.Mvvm | Pre-Beta | `0.1.0` |
| **WPF Setup Installer** | .NET 8 WPF (`WinRepairKit.Setup.exe`) | Ready | `0.1.0` |

---

## 📋 Full Lifecycle Pipeline

```text
Install (WinRepairKit.Setup.exe / Install-WinRepairKit.ps1)
   ↓
Scan (Test-RecycleBin / Test-TempFiles / winrepair scan)
   ↓
Plan (Deterministic SHA-256 Fingerprinted Execution Plans)
   ↓
Dry Run (Zero-Mutation Simulation Mode)
   ↓
Repair (Transaction Journaled Safe Execution with Path Traversal Protection)
   ↓
Verify (Post-Repair Verification Diffing)
   ↓
Reboot (Preserves Transaction Logs across Boot Sessions)
   ↓
Scan Again (Post-Reboot Health Confirmation)
```

---

## 📋 Version History & Changelog

### v0.1.0 (2026-08-23) — *Pre-Beta Foundation & Hardening*
- **Phase 1: Core Engine**:
  - Strongly-typed class models (`Finding`, `PlanStep`, `RepairPlan`, `SnapshotInfo`, `VerificationResult`, `RepairResult`).
  - Structured dual-format logger (`.log` + `.jsonl`).
  - Safety manager & dry-run gating invariants.
  - Snapshot manager (state snapshots vs data backups).
  - Elevation manager (self-elevation & UAC relaunch).
- **Phase 2: RecycleBin Module**:
  - Multi-signal detection (`RB-001` AccessDenied, `RB-002` Corrupted Container, `RB-003` Orphaned SIDs).
  - 5-step fingerprinted repair plan with independent repair strategies.
  - Zero-mutation dry-run guarantee.
- **Phase 3: CLI Interface**:
  - Commands: `scan`, `plan`, `repair`, `verify`, `modules`, `snapshots`, `transactions`, `report`.
  - Machine-readable `-Json` stream mode for GUI process separation.
  - Frozen CLI exit code contract (`0` to `8`).
- **Phase 3.5 & 3.6: Security Hardening & Crash Recovery**:
  - Deterministic SHA-256 state fingerprinting & live stale-plan rejection.
  - On-disk transaction journaling in `$LOCALAPPDATA\WinRepairKit\transactions\`.
  - Orphaned / interrupted repair detection on startup without automatic resumption.
- **Phase 4: TempFiles Module**:
  - Contextual scanning of User Temp, Windows System Temp, Crash Dumps, and Windows Update cache.
  - Active file-lock protection: installer `.tmp` files and in-use handles are automatically preserved.
- **Phase 5: Native WPF Desktop App**:
  - Fluent Precision design system implementation (`reference/ui ux/`).
  - 5 Views: Overview Dashboard, Scanning Progress, Issue Details, Repair Plan, Repair Result.
  - Process separation client invoking `winrepair.ps1 -Json`.
- **Phase 5.5 & 5.6: Release Hardening & Verification UX**:
  - Explicit GUI State Machine (`AppState.cs`) managing state lifecycle.
  - Dedicated Before vs. After comparison verification view (`RepairResultView.xaml`).
  - Friendly Repair ID generation (`WRK-YYYY-MM-DD-XXXX`).
  - Reparse point (junction/symlink) and path traversal security guards (`Test-IsSafeTargetPath.ps1`).
  - Privacy-preserving sanitized support bundle exporter (`Export-WinRepairSupportBundle`).
  - Native WPF Setup Installer (`WinRepairKit.Setup.exe`) and clean PowerShell uninstaller (`Uninstall-WinRepairKit.ps1`).
