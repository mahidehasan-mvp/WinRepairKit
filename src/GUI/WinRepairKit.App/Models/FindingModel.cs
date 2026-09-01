using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace WinRepairKit.App.Models;

public class FindingModel
{
    [JsonPropertyName("Id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("Severity")]
    public int Severity { get; set; }

    [JsonPropertyName("Title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("Detail")]
    public string Detail { get; set; } = string.Empty;

    [JsonPropertyName("Path")]
    public string Path { get; set; } = string.Empty;

    [JsonPropertyName("SizeBytes")]
    public long SizeBytes { get; set; }

    [JsonPropertyName("FileCount")]
    public long FileCount { get; set; }

    [JsonPropertyName("Fingerprint")]
    public string Fingerprint { get; set; } = string.Empty;

    [JsonPropertyName("ExtraData")]
    public Dictionary<string, object>? ExtraData { get; set; }

    public string FormattedSize => FormatBytes(SizeBytes);

    private static string FormatBytes(long bytes)
    {
        if (bytes <= 0) return "0 B";
        string[] units = ["B", "KB", "MB", "GB", "TB"];
        int i = 0;
        double d = bytes;
        while (d >= 1024 && i < units.Length - 1)
        {
            d /= 1024;
            i++;
        }
        return $"{d:0.##} {units[i]}";
    }
}
