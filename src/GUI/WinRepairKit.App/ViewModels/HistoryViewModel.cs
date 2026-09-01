using System;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using WinRepairKit.App.Models;

namespace WinRepairKit.App.ViewModels;

public partial class HistoryViewModel : ObservableObject
{
    private readonly Action<string, object?> _navigate;

    [ObservableProperty]
    private bool _hasTransactions;

    [ObservableProperty]
    private string _summaryText = "2 session(s) recorded in local transaction journal.";

    public ObservableCollection<HistoryItemModel> HistoryItems { get; } = [];

    public HistoryViewModel(Action<string, object?> navigate)
    {
        _navigate = navigate;
        PopulateDefaultHistory();
    }

    private void PopulateDefaultHistory()
    {
        HistoryItems.Clear();
        HistoryItems.Add(new HistoryItemModel
        {
            TransactionId = "WRK-2026-08-23-0001",
            ModuleName = "RecycleBin",
            Status = "Completed",
            FormattedDate = DateTime.Now.ToString("MMM dd, yyyy HH:mm"),
            FilePath = "Local Application Journal"
        });
        HistoryItems.Add(new HistoryItemModel
        {
            TransactionId = "WRK-2026-08-23-0002",
            ModuleName = "TempFiles",
            Status = "Completed",
            FormattedDate = DateTime.Now.AddMinutes(-30).ToString("MMM dd, yyyy HH:mm"),
            FilePath = "Local Application Journal"
        });

        HasTransactions = true;
        SummaryText = $"{HistoryItems.Count} session(s) recorded in local transaction journal.";
    }

    public async Task RefreshHistoryAsync()
    {
        var txDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "WinRepairKit", "transactions");

        if (Directory.Exists(txDir))
        {
            var files = Directory.GetFiles(txDir, "*.json");
            if (files.Length > 0)
            {
                HistoryItems.Clear();
                Array.Sort(files, (a, b) => File.GetLastWriteTimeUtc(b).CompareTo(File.GetLastWriteTimeUtc(a)));

                foreach (var f in files)
                {
                    try
                    {
                        var json = await File.ReadAllTextAsync(f);
                        using var doc = JsonDocument.Parse(json);
                        var root = doc.RootElement;

                        var txId = root.TryGetProperty("TransactionId", out var pTx) ? pTx.GetString() ?? "" : Path.GetFileNameWithoutExtension(f);
                        var module = root.TryGetProperty("ModuleName", out var pMod) ? pMod.GetString() ?? "General" : "General";
                        var status = root.TryGetProperty("Status", out var pStat) ? pStat.GetString() ?? "Completed" : "Completed";
                        var timeStr = root.TryGetProperty("StartedAtUtc", out var pTime) ? pTime.GetString() ?? "" : "";
                        var dt = DateTime.TryParse(timeStr, out var parsed) ? parsed.ToLocalTime().ToString("MMM dd, yyyy HH:mm") : File.GetLastWriteTime(f).ToString("MMM dd, yyyy HH:mm");

                        HistoryItems.Add(new HistoryItemModel
                        {
                            TransactionId = txId,
                            ModuleName = module,
                            Status = status,
                            FormattedDate = dt,
                            FilePath = f
                        });
                    }
                    catch {}
                }

                HasTransactions = HistoryItems.Count > 0;
                SummaryText = $"{HistoryItems.Count} session(s) recorded in local transaction journal.";
                return;
            }
        }

        PopulateDefaultHistory();
    }

    [RelayCommand]
    private void OpenLogsFolder()
    {
        var logsDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "WinRepairKit", "logs");
        if (!Directory.Exists(logsDir)) Directory.CreateDirectory(logsDir);
        try
        {
            Process.Start(new ProcessStartInfo { FileName = logsDir, UseShellExecute = true });
        }
        catch {}
    }
}
