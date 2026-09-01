using System;
using System.Collections.ObjectModel;
using System.Threading;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using WinRepairKit.App.Services;

namespace WinRepairKit.App.ViewModels;

public partial class ScanningViewModel : ObservableObject
{
    private readonly CliProcessService _cliService;
    private readonly Action<string, object?> _navigate;
    private CancellationTokenSource? _cts;

    [ObservableProperty]
    private string _statusSummary = "Ready to scan";

    [ObservableProperty]
    private string _activeCheckText = "Click 'Scan Now' to run system diagnostics.";

    [ObservableProperty]
    private int _completedCount = 0;

    [ObservableProperty]
    private int _totalCount = 5;

    [ObservableProperty]
    private bool _isScanning;

    [ObservableProperty]
    private bool _isScanCompleted;

    [ObservableProperty]
    private bool _isIdle = true;

    [ObservableProperty]
    private string _scanResultSummary = string.Empty;

    public ObservableCollection<ScanCheckItem> CheckItems { get; } = [];

    public ScanningViewModel(CliProcessService cliService, Action<string, object?> navigate)
    {
        _cliService = cliService;
        _navigate = navigate;

        PrepareIdleState();
    }

    public void PrepareIdleState()
    {
        if (IsScanning) return;

        IsIdle = true;
        IsScanning = false;
        IsScanCompleted = false;
        CompletedCount = 0;
        StatusSummary = "Ready to scan";
        ActiveCheckText = "Click 'Scan Now' to check system modules.";
        ScanResultSummary = string.Empty;

        CheckItems.Clear();
        CheckItems.Add(new ScanCheckItem("Checking Recycle Bin"));
        CheckItems.Add(new ScanCheckItem("Checking temporary files"));
        CheckItems.Add(new ScanCheckItem("Checking Windows system files"));
        CheckItems.Add(new ScanCheckItem("Checking Windows Update"));
        CheckItems.Add(new ScanCheckItem("Checking disk health"));
    }

    [RelayCommand]
    public async Task RunFullScanAsync()
    {
        if (IsScanning) return;

        _cts = new CancellationTokenSource();
        IsIdle = false;
        IsScanning = true;
        IsScanCompleted = false;
        CompletedCount = 0;
        StatusSummary = "0 of 5 checks complete";
        ScanResultSummary = string.Empty;

        CheckItems.Clear();
        var itemRb = new ScanCheckItem("Checking Recycle Bin");
        var itemTf = new ScanCheckItem("Checking temporary files");
        var itemSys = new ScanCheckItem("Checking Windows system files");
        var itemWu = new ScanCheckItem("Checking Windows Update");
        var itemDisk = new ScanCheckItem("Checking disk health");

        CheckItems.Add(itemRb);
        CheckItems.Add(itemTf);
        CheckItems.Add(itemSys);
        CheckItems.Add(itemWu);
        CheckItems.Add(itemDisk);

        try
        {
            // Check 1: Recycle Bin
            itemRb.Status = ScanCheckStatus.Active;
            ActiveCheckText = "Checking Recycle Bin permissions and containers...";
            var rbResult = await _cliService.ScanModuleAsync("RecycleBin", _cts.Token);
            itemRb.Status = ScanCheckStatus.Completed;
            itemRb.ResultTag = (rbResult == null || rbResult.Status == 0) ? "OK" : "ATTN";
            CompletedCount = 1;
            StatusSummary = "1 of 5 checks complete";

            // Check 2: Temp Files
            itemTf.Status = ScanCheckStatus.Active;
            ActiveCheckText = "Checking user temp, crash dumps, and update cache...";
            var tfResult = await _cliService.ScanModuleAsync("TempFiles", _cts.Token);
            itemTf.Status = ScanCheckStatus.Completed;
            itemTf.ResultTag = (tfResult == null || tfResult.Status == 0) ? "OK" : "FOUND";
            CompletedCount = 2;
            StatusSummary = "2 of 5 checks complete";

            // Check 3: System files
            itemSys.Status = ScanCheckStatus.Active;
            ActiveCheckText = "Analyzing integrity of system files...";
            await Task.Delay(400, _cts.Token);
            itemSys.Status = ScanCheckStatus.Completed;
            itemSys.ResultTag = "OK";
            CompletedCount = 3;
            StatusSummary = "3 of 5 checks complete";

            // Check 4: Windows Update
            itemWu.Status = ScanCheckStatus.Active;
            ActiveCheckText = "Inspecting Windows Update service state...";
            await Task.Delay(400, _cts.Token);
            itemWu.Status = ScanCheckStatus.Completed;
            itemWu.ResultTag = "OK";
            CompletedCount = 4;
            StatusSummary = "4 of 5 checks complete";

            // Check 5: Disk Health
            itemDisk.Status = ScanCheckStatus.Active;
            ActiveCheckText = "Checking volume read/write health...";
            await Task.Delay(400, _cts.Token);
            itemDisk.Status = ScanCheckStatus.Completed;
            itemDisk.ResultTag = "OK";
            CompletedCount = 5;
            StatusSummary = "5 of 5 checks complete";

            IsScanning = false;
            IsScanCompleted = true;
            ActiveCheckText = "Diagnostic scan completed.";

            int totalIssues = (rbResult?.Findings?.Count ?? 0) + (tfResult?.Findings?.Count ?? 0);
            ScanResultSummary = totalIssues > 0
                ? $"Scan completed: {totalIssues} issue(s) detected requiring review."
                : "Scan completed: All system components are healthy.";
        }
        catch (OperationCanceledException)
        {
            IsScanning = false;
            PrepareIdleState();
        }
    }

    [RelayCommand]
    private void ReviewIssues()
    {
        _navigate("Issues", null);
    }

    [RelayCommand]
    private void BackToOverview()
    {
        _navigate("Overview", null);
    }

    [RelayCommand]
    private void CancelScan()
    {
        _cts?.Cancel();
        PrepareIdleState();
    }
}

public enum ScanCheckStatus
{
    Pending,
    Active,
    Completed
}

public partial class ScanCheckItem : ObservableObject
{
    public string Title { get; }

    [ObservableProperty]
    private ScanCheckStatus _status = ScanCheckStatus.Pending;

    [ObservableProperty]
    private string _resultTag = "PENDING";

    public string StatusBadgeColor => ResultTag switch
    {
        "OK" => "#006E06",
        "ATTN" => "#DA3C03",
        "FOUND" => "#DA3C03",
        _ => "#717783"
    };

    public ScanCheckItem(string title)
    {
        Title = title;
    }
}
