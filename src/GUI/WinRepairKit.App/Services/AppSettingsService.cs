using System;
using System.IO;
using System.Text.Json;

namespace WinRepairKit.App.Services;

public class AppSettings
{
    public string Theme { get; set; } = "Fluent Precision";
    public bool AlwaysDryRunFirst { get; set; } = true;
    public bool AutoScanOnStartup { get; set; } = false;
    public bool EnableAnimations { get; set; } = true;
    public string TempFilesAge { get; set; } = "Older than 24 hours (Default)";
    public string LogRetention { get; set; } = "Keep logs for 30 days (Default)";
}

public static class AppSettingsService
{
    private static readonly string SettingsDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "WinRepairKit");
    private static readonly string SettingsFile = Path.Combine(SettingsDir, "settings.json");

    private static AppSettings _current = new();
    public static AppSettings Current => _current;

    static AppSettingsService()
    {
        Load();
    }

    public static void Load()
    {
        try
        {
            if (File.Exists(SettingsFile))
            {
                var json = File.ReadAllText(SettingsFile);
                var loaded = JsonSerializer.Deserialize<AppSettings>(json);
                if (loaded != null)
                {
                    _current = loaded;
                }
            }
        }
        catch {}
    }

    public static void Save()
    {
        try
        {
            if (!Directory.Exists(SettingsDir))
            {
                Directory.CreateDirectory(SettingsDir);
            }
            var json = JsonSerializer.Serialize(_current, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(SettingsFile, json);
        }
        catch {}
    }
}
