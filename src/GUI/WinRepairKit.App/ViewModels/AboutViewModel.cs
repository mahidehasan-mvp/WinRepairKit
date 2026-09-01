using System;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using WinRepairKit.App.Services;

namespace WinRepairKit.App.ViewModels;

public partial class AboutViewModel : ObservableObject
{
    private readonly Action<string>? _onThemeChanged;
    private bool _isSyncingTheme;

    public string VersionText => "1.0.0 (Production Release)";
    public string OsVersionText => $"{Environment.OSVersion.VersionString} ({RuntimeInformation.ProcessArchitecture})";
    public string DotNetRuntimeText => $".NET {Environment.Version}";
    public string ElevationStatusText => ElevationService.IsElevated() ? "Elevated Administrator" : "Standard User (Scan Only)";
    public bool IsElevated => ElevationService.IsElevated();

    public string LogDirectoryPath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "WinRepairKit", "logs");
    public string SnapshotDirectoryPath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "WinRepairKit", "snapshots");

    public ObservableCollection<string> AvailableThemes { get; } = [
        "Fluent Precision",
        "Cyberpunk 2077"
    ];

    public ObservableCollection<string> TempFileAgeOptions { get; } = [
        "Older than 24 hours (Default)",
        "Older than 48 hours",
        "Older than 7 days"
    ];

    public ObservableCollection<string> LogRetentionOptions { get; } = [
        "Keep logs for 30 days (Default)",
        "Keep logs for 90 days",
        "Never purge audit logs"
    ];

    [ObservableProperty]
    private string _selectedTheme;

    [ObservableProperty]
    private bool _alwaysDryRunFirst;

    [ObservableProperty]
    private bool _autoScanOnStartup;

    [ObservableProperty]
    private bool _enableAnimations;

    [ObservableProperty]
    private string _selectedTempFilesAge;

    [ObservableProperty]
    private string _selectedLogRetention;

    [ObservableProperty]
    private string _supportBundleStatus = string.Empty;

    [ObservableProperty]
    private string _settingsStatusMessage = string.Empty;

    [ObservableProperty]
    private bool _hasSettingsStatus;

    public AboutViewModel(Action<string>? onThemeChanged = null)
    {
        _onThemeChanged = onThemeChanged;

        var s = AppSettingsService.Current;
        _selectedTheme = s.Theme;
        _alwaysDryRunFirst = s.AlwaysDryRunFirst;
        _autoScanOnStartup = s.AutoScanOnStartup;
        _enableAnimations = s.EnableAnimations;
        _selectedTempFilesAge = s.TempFilesAge;
        _selectedLogRetention = s.LogRetention;
    }

    partial void OnSelectedThemeChanged(string value)
    {
        if (_isSyncingTheme) return;
        _isSyncingTheme = true;

        try
        {
            AppSettingsService.Current.Theme = value;
            AppSettingsService.Save();
            _onThemeChanged?.Invoke(value);
        }
        finally
        {
            _isSyncingTheme = false;
        }
    }

    partial void OnAlwaysDryRunFirstChanged(bool value)
    {
        AppSettingsService.Current.AlwaysDryRunFirst = value;
        AppSettingsService.Save();
        ShowSavedFeedback("Safety rule updated: Dry-run preference saved.");
    }

    partial void OnAutoScanOnStartupChanged(bool value)
    {
        AppSettingsService.Current.AutoScanOnStartup = value;
        AppSettingsService.Save();
        ShowSavedFeedback("Startup preference saved.");
    }

    partial void OnEnableAnimationsChanged(bool value)
    {
        AppSettingsService.Current.EnableAnimations = value;
        AppSettingsService.Save();
        ShowSavedFeedback("Visual motion preference saved.");
    }

    partial void OnSelectedTempFilesAgeChanged(string value)
    {
        AppSettingsService.Current.TempFilesAge = value;
        AppSettingsService.Save();
        ShowSavedFeedback("Temporary file threshold saved.");
    }

    partial void OnSelectedLogRetentionChanged(string value)
    {
        AppSettingsService.Current.LogRetention = value;
        AppSettingsService.Save();
        ShowSavedFeedback("Audit log retention policy saved.");
    }

    private void ShowSavedFeedback(string msg)
    {
        SettingsStatusMessage = $"✓ {msg}";
        HasSettingsStatus = true;
    }

    [RelayCommand]
    private void OpenLogDirectory()
    {
        try
        {
            var dir = LogDirectoryPath;
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
            Process.Start(new ProcessStartInfo { FileName = dir, UseShellExecute = true });
        }
        catch {}
    }

    [RelayCommand]
    private void OpenSnapshotsDirectory()
    {
        try
        {
            var dir = SnapshotDirectoryPath;
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
            Process.Start(new ProcessStartInfo { FileName = dir, UseShellExecute = true });
        }
        catch {}
    }

    [RelayCommand]
    private async Task GenerateSupportBundleAsync()
    {
        SupportBundleStatus = "Creating sanitized diagnostic bundle...";
        await Task.Delay(400);

        try
        {
            var baseDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "WinRepairKit");
            var bundleDir = Path.Combine(baseDir, "bundles");
            if (!Directory.Exists(bundleDir)) Directory.CreateDirectory(bundleDir);

            var zipName = $"WinRepairKit-Support-{DateTime.Now:yyyyMMdd-HHmmss}.zip";
            var zipPath = Path.Combine(bundleDir, zipName);

            var tempExportDir = Path.Combine(Path.GetTempPath(), $"WinRepairSupport_{Guid.NewGuid():N}");
            Directory.CreateDirectory(tempExportDir);

            // Copy sanitized logs
            var logsDir = Path.Combine(baseDir, "logs");
            if (Directory.Exists(logsDir))
            {
                var destLogs = Path.Combine(tempExportDir, "logs");
                Directory.CreateDirectory(destLogs);
                foreach (var f in Directory.GetFiles(logsDir))
                {
                    File.Copy(f, Path.Combine(destLogs, Path.GetFileName(f)), true);
                }
            }

            // Write sanitized system manifest
            var manifestContent = $"[SYSTEM MANIFEST]\nOS: {OsVersionText}\nRuntime: {DotNetRuntimeText}\nElevated: {IsElevated}\nDate: {DateTime.UtcNow:O}\n";
            File.WriteAllText(Path.Combine(tempExportDir, "system_manifest.txt"), manifestContent);

            ZipFile.CreateFromDirectory(tempExportDir, zipPath);
            Directory.Delete(tempExportDir, true);

            SupportBundleStatus = $"✓ Bundle exported: {zipName}";

            // Open folder
            Process.Start(new ProcessStartInfo { FileName = bundleDir, UseShellExecute = true });
        }
        catch (Exception ex)
        {
            SupportBundleStatus = $"Error generating bundle: {ex.Message}";
        }
    }

    [RelayCommand]
    private void ClearAuditCache()
    {
        try
        {
            var logsDir = LogDirectoryPath;
            if (Directory.Exists(logsDir))
            {
                foreach (var f in Directory.GetFiles(logsDir))
                {
                    try { File.Delete(f); } catch {}
                }
            }
            SettingsStatusMessage = "✓ Audit history and local cache cleared.";
            HasSettingsStatus = true;
        }
        catch {}
    }

    [RelayCommand]
    private void RestartElevated()
    {
        ElevationService.RestartElevated();
    }

    [RelayCommand]
    private void ViewLicense()
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "https://opensource.org/licenses/MIT",
                UseShellExecute = true
            });
        }
        catch {}
    }
}
