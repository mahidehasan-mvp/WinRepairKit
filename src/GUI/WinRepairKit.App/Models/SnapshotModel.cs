using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace WinRepairKit.App.Models;

public class SnapshotModel
{
    [JsonPropertyName("SnapshotId")]
    public string SnapshotId { get; set; } = string.Empty;

    [JsonPropertyName("ModuleName")]
    public string ModuleName { get; set; } = string.Empty;

    [JsonPropertyName("Timestamp")]
    public DateTime? Timestamp { get; set; }

    [JsonPropertyName("Path")]
    public string Path { get; set; } = string.Empty;

    [JsonPropertyName("ItemCount")]
    public long ItemCount { get; set; }
}

public class VerificationModel
{
    [JsonPropertyName("Passed")]
    public bool Passed { get; set; }

    [JsonPropertyName("RemainingProblemsCount")]
    public int RemainingProblemsCount { get; set; }

    [JsonPropertyName("Message")]
    public string Message { get; set; } = string.Empty;

    [JsonPropertyName("RemainingFindings")]
    public List<FindingModel> RemainingFindings { get; set; } = [];
}
