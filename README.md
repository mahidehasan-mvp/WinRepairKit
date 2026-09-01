# WinRepairKit 🛠️

A modern, transparent, and trustworthy Windows 10 & 11 Repair and Maintenance Toolkit.

> **Diagnose → Explain → Plan → Repair → Verify**

Unlike traditional "cleaners" that run blind destructive commands, WinRepairKit detects problems first, explains them clearly with risk ratings, generates a reviewable repair plan, creates pre-repair state snapshots, executes fixes safely with user consent, and verifies the resolution.

---

## 🌟 Key Features

- 🔍 **Transparent Diagnostics**: Thorough scans that report exact file paths, counts, sizes, and permission anomalies.
- 📋 **Step-by-step Repair Plans**: Generates an actionable, reviewable plan with explicit risk levels (🟢 Safe, 🟡 Elevated, 🔴 Destructive).
- 🛡️ **Safety-First Contracts**:
  - **Dry-run simulation** to preview exactly what would change before executing.
  - **Pre-repair state snapshots** (metadata, ACLs, manifests).
  - **Post-repair verification** to confirm problems are resolved.
  - **"If unsure, do nothing"** design principle.
- 📊 **Dual-Format Logging**: Human-readable `.log` files alongside machine-readable `.jsonl` streams.
- 💻 **CLI & Future GUI Ready**: Standalone CLI with JSON output mode for GUI automation and sysadmin scripts.

---

## 🚀 Getting Started

### Prerequisites
- Windows 10 (Build 1809+) or Windows 11
- PowerShell 5.1 or PowerShell 7+ (pwsh)

### CLI Usage

Import the module or run the standalone CLI:

```powershell
# Scan all modules
.\src\CLI\winrepair.ps1 scan

# Scan specific module (e.g. RecycleBin)
.\src\CLI\winrepair.ps1 scan -Module RecycleBin

# Generate a repair plan
.\src\CLI\winrepair.ps1 plan -Module RecycleBin

# Preview what repair would do without making any changes (Dry Run)
.\src\CLI\winrepair.ps1 repair -Module RecycleBin -DryRun

# Execute repair with confirmation
.\src\CLI\winrepair.ps1 repair -Module RecycleBin -ConfirmFix

# Verify state after repair
.\src\CLI\winrepair.ps1 verify -Module RecycleBin

# Output structured JSON for automation or GUI
.\src\CLI\winrepair.ps1 scan -Json
```

---

## 📁 Repository Structure

```
├── src/
│   ├── Engine/                   # PowerShell Core Engine & Modules
│   │   ├── Core/                 # Types, Safety, Elevation, Logging, Snapshots, Plans
│   │   ├── Modules/              # Pluggable repair modules (e.g. RecycleBin)
│   │   ├── Public/               # Exported cmdlets (Invoke-WinRepairScan, etc.)
│   │   └── Private/              # Internal utility helpers
│   ├── CLI/                      # CLI wrapper (winrepair.ps1)
│   └── GUI/                      # Future WPF/WPF-UI .NET 10 desktop application
├── tests/
│   ├── Unit/                     # Pester unit tests
│   └── TestHelpers/              # Test fixture creators
└── docs/                         # Architecture, safety, and module development guides
```

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).
