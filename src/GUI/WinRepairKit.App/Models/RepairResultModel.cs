using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace WinRepairKit.App.Models;

public class RepairResultModel
{
    [JsonPropertyName("SchemaVersion")]
    public string SchemaVersion { get; set; } = "1.0";

    [JsonPropertyName("TransactionId")]
    public string TransactionId { get; set; } = string.Empty;

    [JsonPropertyName("PlanId")]
    public string PlanId { get; set; } = string.Empty;

    [JsonPropertyName("ModuleName")]
    public string ModuleName { get; set; } = string.Empty;

    [JsonPropertyName("Status")]
    public int Status { get; set; } // 0=Healthy, 1=ProblemFound, 2=RepairSucceeded, 3=RepairPartial, 4=RepairFailed, 5=Skipped, 6=Error, 7=PlanInvalidated

    [JsonPropertyName("RiskLevel")]
    public int RiskLevel { get; set; }

    [JsonPropertyName("RequiresAdmin")]
    public bool RequiresAdmin { get; set; }

    [JsonPropertyName("CanRepair")]
    public bool CanRepair { get; set; }

    [JsonPropertyName("SupportsDryRun")]
    public bool SupportsDryRun { get; set; }

    [JsonPropertyName("DataDestructive")]
    public bool DataDestructive { get; set; }

    [JsonPropertyName("MutationsPerformed")]
    public bool MutationsPerformed { get; set; }

    [JsonPropertyName("RollbackAvailable")]
    public bool RollbackAvailable { get; set; }

    [JsonPropertyName("RequiresReboot")]
    public bool RequiresReboot { get; set; }

    [JsonPropertyName("Findings")]
    public List<FindingModel> Findings { get; set; } = [];

    [JsonPropertyName("Plan")]
    public RepairPlanModel? Plan { get; set; }

    [JsonPropertyName("Recommendations")]
    public List<string> Recommendations { get; set; } = [];

    [JsonPropertyName("Snapshot")]
    public SnapshotModel? Snapshot { get; set; }

    [JsonPropertyName("Verification")]
    public VerificationModel? Verification { get; set; }

    [JsonPropertyName("DurationMs")]
    public long DurationMs { get; set; }

    public bool IsHealthy => Status == 0;

    public string StatusText => Status switch
    {
        0 => "Healthy",
        1 => "Needs repair",
        2 => "Repair Succeeded",
        3 => "Repair Partial",
        4 => "Repair Failed",
        5 => "Skipped (Dry Run)",
        6 => "Error",
        7 => "Plan Invalidated",
        _ => "Unknown"
    };

    public string StatusBadgeColor => Status switch
    {
        0 => "#006E06", // Green
        1 => "#DA3C03", // Amber
        2 => "#006E06",
        3 => "#DA3C03",
        4 => "#BA1A1A", // Red
        5 => "#005FAA", // Blue
        _ => "#717783"
    };

    public string DisplayIcon => ModuleName switch
    {
        "RecycleBin" => "DeleteSweep24",
        "TempFiles" => "FolderZip24",
        _ => "Wrench24"
    };

    public string ModuleDescription => ModuleName switch
    {
        "RecycleBin" => "Corrupted permissions and inaccessible items in trash container.",
        "TempFiles" => "Accumulated cache, crash dumps, and installer files.",
        _ => "Windows system maintenance component."
    };
}
