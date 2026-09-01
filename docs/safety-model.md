# WinRepairKit Safety Model

## 1. Risk Levels

Every diagnostic finding, plan step, and repair operation must declare its risk level:

| Risk Level | Meaning | Auto-Scan? | Repair Requirement |
|---|---|---|---|
| **Safe** | Read-only; inspects system status or exports metadata | Automatic | Permitted without prompt |
| **Elevated** | Changes system configuration without deleting user files (e.g. resetting permissions, restarting service) | Automatic | User consent required |
| **Destructive** | Permanently deletes files or resets containers | Automatic detection | Explicit user confirmation (`-ConfirmFix`) required |

---

## 2. Dry-Run Simulation

Every module supporting repair must implement `-DryRun`.

When invoked with `-DryRun`:
- **Zero** filesystem or registry mutations occur.
- Every planned step is logged as `Would execute [Step X]: ...`.
- Returns `RepairStatus::Skipped` or `Healthy` for clear automation handling.

---

## 3. State Snapshot vs. Data Backup

- **State Snapshot**: Preserves access control lists (ACLs), ownership records, path hierarchies, file sizes, creation timestamps, and attributes in a timestamped `manifest.json` + `acls.txt`.
- **Data Backup**: Stores full file byte contents.

WinRepairKit explicitly informs users:
> *"This operation permanently removes these items. A metadata/state snapshot will be created, but deleted file contents cannot be restored."*

---

## 4. Post-Repair Verification

No repair is declared successful based on command exit codes alone. 

1. Pre-repair findings are captured.
2. Repair sequence executes.
3. Diagnostic scan re-runs automatically.
4. If 0 issues remain: `RepairSucceeded`.
5. If partial issues remain: `RepairPartial` ("X issues remain. No further destructive action was performed.").
6. If all issues remain: `RepairFailed`.
