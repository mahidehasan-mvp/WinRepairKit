# WinRepairKit 🛠️

A modern, transparent, and trustworthy Windows 10 & 11 Repair and Maintenance Toolkit.

> **Diagnose → Explain → Plan → Repair → Verify**

Unlike traditional "cleaner" utilities that execute opaque, destructive scripts behind a single button, **WinRepairKit** is built on transparency, safety contracts, and consent-first engineering. It detects filesystem and permission anomalies first, explains them with exact metrics, generates a reviewable step-by-step repair plan, simulates fixes in dry-run mode, and verifies the outcome.

---

## ⚡ Why WinRepairKit is Different from Other Cleaners

Traditional Windows "cleaners" and optimizer utilities often run blind `rmdir` or registry sweeps that can corrupt user permissions, delete needed cache, or leave orphaned containers behind.

| Feature / Behavior | Traditional "PC Cleaners" | **WinRepairKit** |
|---|---|---|
| **Execution Model** | ❌ Blind, one-click destruction | ✅ **5-Stage Contract** (*Diagnose → Explain → Plan → Repair → Verify*) |
| **Inspection Depth** | ❌ Surface-level directory deletion | ✅ **Deep Win32 / Filesystem Inspection** (Raw SIDs, ACLs, Reparse Points) |
| **Transparency** | ❌ Vague "Issues Found: 1,420" | ✅ **Exact Paths, Sizes, File Counts & Technical Details** |
| **Simulation** | ❌ None (Deletes immediately) | ✅ **Dry-Run Mode** (Strict zero-mutation guarantee) |
| **Safety Backups** | ❌ None or proprietary snapshot | ✅ **Pre-Repair State Snapshots & Audit Logs** |
| **Post-Repair Check** | ❌ Assumes success | ✅ **Automated Re-scan & Verification Diffing** |
| **Open Source** | ❌ Proprietary / Adware / Bundlers | ✅ **100% Free & Open Source (MIT License)** |

---

## 🔍 Deep Diagnostic Capabilities

WinRepairKit does not rely on high-level Explorer APIs that hide system files or fail silently on permission locks. It executes deep low-level diagnostics:

### 1. Raw `$Recycle.Bin` Multi-Drive Container Inspection
- **Multi-Volume Traversal**: Automatically scans all mounted volumes (`C:\`, `D:\`, `E:\`, etc.) rather than just the primary drive.
- **Hidden & System Files Enumeration**: Inspects hidden and system attributes (`/a /s`) that Windows Explorer cannot display normally.
- **User SID & Orphan Folder Detection**: Drills into individual Security Identifier subfolders (`S-1-5-21-...`) to detect orphaned user profiles, deleted account remnants, and corrupted subcontainers.
- **ACL & Permission Lock Analysis**: Detects access denials, broken permission inheritances, and ownership locks that cause standard deletions to fail.
- **Reparse Point & Junction Validation**: Inspects volume reparse points and mount links to ensure structural filesystem integrity.

### 2. Temporary Storage & Cache Analysis
- **Inactive File Age Filtering**: Only targets files older than 24h/48h/7d to avoid deleting active locks or in-flight installer payloads.
- **Crash Dump Diagnostics**: Identifies Windows Minidump and memory crash dump build-up (`*.dmp`).
- **Windows Update Download Cache**: Inspects pending or completed `SoftwareDistribution\Download` packages safely.

### 3. Safety & Audit Invariants
- **Deterministic SHA-256 Plan Fingerprinting**: Prevents executing stale plans if underlying filesystem state changes.
- **Crash-Safe Transaction Journaling**: Prevents accidental blind resumption if an interrupted state is detected.
- **Sanitized Support Bundle Generator**: Exports redacted diagnostic `.zip` bundles containing logs and system manifests for easy troubleshooting.

---

## 🌟 Key Features

- 🖥️ **Modern Desktop GUI**: High-performance .NET 8 WPF application with **Fluent Precision** and **Cyberpunk 2077 Night City HUD** themes.
- 💻 **Scriptable CLI**: Standalone PowerShell CLI with machine-readable `-Json` output for sysadmins and automated pipelines.
- 🛡️ **Consent Gate**: Destructive actions are permanently disabled until explicit user risk acknowledgment.
- 📋 **Step-by-Step Plans**: Review exact operations and risk levels (🟢 Safe, 🟡 Elevated, 🔴 Destructive) before applying fixes.
- 🔒 **Zero Telemetry**: All diagnostics, logs, and snapshots remain strictly local on your PC.

---

## 🚀 Getting Started

### Prerequisites
- **OS**: Windows 10 (Build 1809+) or Windows 11
- **Runtime**: .NET 8.0 Windows Desktop Runtime (or use standalone executable)
- **PowerShell**: PowerShell 5.1 or PowerShell 7+

---

### 🖥️ Desktop GUI Application

1. Download or locate `WinRepairKit.exe` in the [`dist/`](dist/) folder.
2. Launch `WinRepairKit.exe`.
3. Click **Scan Now** on the **Scan** tab to run deep system diagnostics.
4. Review findings, preview execution with **Dry Run**, and apply repairs with verified safety gates.

---

### 💻 Command-Line Interface (CLI) Usage

```powershell
# Scan all modules across all drives
.\src\CLI\winrepair.ps1 scan

# Deep scan a specific module (e.g. RecycleBin)
.\src\CLI\winrepair.ps1 scan -Module RecycleBin

# Generate a reviewable step-by-step repair plan
.\src\CLI\winrepair.ps1 plan -Module RecycleBin

# Preview what repair would do with ZERO system mutations (Dry Run)
.\src\CLI\winrepair.ps1 repair -Module RecycleBin -DryRun

# Execute repair with explicit confirmation
.\src\CLI\winrepair.ps1 repair -Module RecycleBin -ConfirmFix

# Verify state after repair
.\src\CLI\winrepair.ps1 verify -Module RecycleBin

# Output structured JSON for automation or sysadmin scripts
.\src\CLI\winrepair.ps1 scan -Json
```

---

## 📁 Repository Structure

```
├── src/
│   ├── Engine/                   # PowerShell Core Diagnostic & Repair Engine
│   │   ├── Core/                 # Types, Safety, Elevation, Logging, Snapshots, Plans
│   │   ├── Modules/              # Pluggable modules (RecycleBin, TempFiles)
│   │   ├── Public/               # Exported cmdlets (Invoke-WinRepairScan, etc.)
│   │   └── Private/              # Low-level helpers (Get-DriveRecycleBin, etc.)
│   ├── CLI/                      # Standalone CLI wrapper (winrepair.ps1)
│   ├── GUI/                      # Modern .NET 8 WPF Desktop Application
│   │   ├── Views/                # Overview, Scan, Issues, RepairPlan, History, Settings
│   │   ├── ViewModels/           # MVVM ViewModels with CommunityToolkit
│   │   ├── Styles/Themes/        # Fluent & Cyberpunk 2077 HUD themes
│   │   └── Services/             # Process, Theme, Elevation, and Settings services
│   └── Installer/                # Desktop Setup & Installer project
├── tests/                        # 22/22 Passing Pester automated tests
└── dist/                         # Ready-to-run compiled release binaries
```

---

## 📜 License

This project is licensed under the [MIT License](LICENSE) — free to use, modify, and distribute.
