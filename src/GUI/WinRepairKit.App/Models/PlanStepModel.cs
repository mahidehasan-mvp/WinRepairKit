using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace WinRepairKit.App.Models;

public class PlanStepModel
{
    [JsonPropertyName("StepNumber")]
    public int StepNumber { get; set; }

    [JsonPropertyName("Action")]
    public string Action { get; set; } = string.Empty;

    [JsonPropertyName("Description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("RiskLevel")]
    public int RiskLevel { get; set; }

    [JsonPropertyName("RequiresAdmin")]
    public bool RequiresAdmin { get; set; }

    [JsonPropertyName("DataDestructive")]
    public bool DataDestructive { get; set; }

    [JsonPropertyName("CanRollback")]
    public bool CanRollback { get; set; }

    [JsonPropertyName("Parameters")]
    public Dictionary<string, object>? Parameters { get; set; }

    public string StepDisplayTitle => $"{StepNumber}. {Action}";

    public string RiskLevelName => RiskLevel switch
    {
        0 => "SAFE",
        1 => "ELEVATED",
        2 => "DESTRUCTIVE",
        _ => "SAFE"
    };

    public string RiskBadgeBackground => RiskLevel switch
    {
        0 => "#D4EDDA",
        1 => "#FFECE0",
        2 => "#BA1A1A",
        _ => "#E2E2E2"
    };

    public string RiskBadgeForeground => RiskLevel switch
    {
        0 => "#006E06",
        1 => "#C2410C",
        2 => "#FFFFFF",
        _ => "#404752"
    };

    public string StepTitleForeground => RiskLevel == 2 ? "#BA1A1A" : "#1A1C1C";

    public string StepIconGlyph => StepNumber switch
    {
        1 => "\uE73E", // Check
        2 => "\uEA18", // Shield / admin settings
        3 => "\uE8D7", // Key
        4 => "\uE7BA", // Warning / delete
        5 => "\uE73E", // Verified check
        _ => "\uE73E"
    };

    public string StepIconBackground => RiskLevel switch
    {
        0 => "#E8F5E9",
        1 => "#FFECE0",
        2 => "#FFDAD6",
        _ => "#F3F3F3"
    };

    public string StepIconForeground => RiskLevel switch
    {
        0 => "#006E06",
        1 => "#C2410C",
        2 => "#BA1A1A",
        _ => "#404752"
    };
}
