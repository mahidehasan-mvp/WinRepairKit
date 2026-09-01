using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace WinRepairKit.App.Models;

public class ConsequenceModel
{
    [JsonPropertyName("DataLossPossible")]
    public bool DataLossPossible { get; set; }

    [JsonPropertyName("Reversible")]
    public bool Reversible { get; set; }

    [JsonPropertyName("BackupCreated")]
    public bool BackupCreated { get; set; }

    [JsonPropertyName("SnapshotCreated")]
    public bool SnapshotCreated { get; set; }
}

public class RepairPlanModel
{
    [JsonPropertyName("PlanId")]
    public string PlanId { get; set; } = string.Empty;

    [JsonPropertyName("ModuleName")]
    public string ModuleName { get; set; } = string.Empty;

    [JsonPropertyName("Title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("Description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("Steps")]
    public List<PlanStepModel> Steps { get; set; } = [];

    [JsonPropertyName("MaxRiskLevel")]
    public int MaxRiskLevel { get; set; }

    [JsonPropertyName("RequiresAdmin")]
    public bool RequiresAdmin { get; set; }

    [JsonPropertyName("DataDestructive")]
    public bool DataDestructive { get; set; }

    [JsonPropertyName("SupportsDryRun")]
    public bool SupportsDryRun { get; set; }

    [JsonPropertyName("Disclaimer")]
    public string Disclaimer { get; set; } = string.Empty;

    [JsonPropertyName("ExplicitDisclaimer")]
    public string ExplicitDisclaimer { get; set; } = string.Empty;

    [JsonPropertyName("Consequence")]
    public ConsequenceModel? Consequence { get; set; }

    [JsonPropertyName("WhatWillNotHappen")]
    public List<string> WhatWillNotHappen { get; set; } = [];

    [JsonPropertyName("SystemFingerprint")]
    public string SystemFingerprint { get; set; } = string.Empty;

    [JsonPropertyName("GeneratedAtUtc")]
    public DateTime? GeneratedAtUtc { get; set; }

    public string MaxRiskLevelName => MaxRiskLevel switch
    {
        0 => "Safe",
        1 => "Elevated Risk",
        2 => "Destructive Risk",
        _ => "Unknown"
    };

    public string RiskBadgeColor => MaxRiskLevel switch
    {
        0 => "#006E06",
        1 => "#DA3C03",
        2 => "#BA1A1A",
        _ => "#717783"
    };

    public string RiskBadgeBackground => MaxRiskLevel switch
    {
        0 => "#E8F5E9",
        1 => "#FFF3E0",
        2 => "#FFEBEE",
        _ => "#F3F3F3"
    };
}
