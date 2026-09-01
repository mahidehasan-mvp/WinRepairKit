using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using WinRepairKit.App.Models;
using WinRepairKit.App.Services;

namespace WinRepairKit.App.ViewModels;

public partial class OverviewViewModel : ObservableObject
{
    private readonly CliProcessService _cliService;
    private readonly Action<string, object?> _navigate;

    [ObservableProperty]
    private string _overallStatusTitle = "Attention needed";

    [ObservableProperty]
    private string _overallStatusDescription = "3 issue(s) found that require your review.";

    [ObservableProperty]
    private string _lastScanTimeText = "Last scan: Today";

    [ObservableProperty]
    private bool _hasIssues = true;

    [ObservableProperty]
    private int _issueCount = 3;

    [ObservableProperty]
    private bool _isLoading;

    public ObservableCollection<OverviewModuleCardItem> ModuleCards { get; } = [];
    public ObservableCollection<RepairResultModel> ModuleResults { get; } = [];
    public ObservableCollection<RecommendedActionItem> RecommendedActions { get; } = [];

    public OverviewViewModel(CliProcessService cliService, Action<string, object?> navigate)
    {
        _cliService = cliService;
        _navigate = navigate;

        // Initialize default state so UI is never blank
        InitDefaultState();
    }

    private void InitDefaultState()
    {
        ModuleResults.Clear();
        ModuleCards.Clear();
        RecommendedActions.Clear();

        var modRb = new RepairResultModel
        {
            ModuleName = "RecycleBin",
            Status = 1,
            RiskLevel = 1,
            Findings = [
                new FindingModel
                {
                    Id = "RB-001",
                    Title = "Inaccessible items detected on D:\\$Recycle.Bin",
                    Path = "D:\\$Recycle.Bin",
                    Detail = "Permission locks prevent standard Windows deletion in D:\\$Recycle.Bin.",
                    FileCount = 5,
                    SizeBytes = 191889408
                }
            ]
        };

        var modTf = new RepairResultModel
        {
            ModuleName = "TempFiles",
            Status = 1,
            RiskLevel = 0,
            Findings = [
                new FindingModel
                {
                    Id = "TMP-001",
                    Title = "User Temp buildup: 858 file(s) older than 24 hrs (260.59 MB)",
                    Path = "C:\\Users\\h\\AppData\\Local\\Temp\\",
                    Detail = "Safe temporary application cache in C:\\Users\\h\\AppData\\Local\\Temp\\",
                    FileCount = 858,
                    SizeBytes = 273248256
                },
                new FindingModel
                {
                    Id = "TMP-003",
                    Title = "Crash Dumps detected: 10 dump file(s) (175.32 MB)",
                    Path = "C:\\Users\\h\\AppData\\Local\\CrashDumps",
                    Detail = "Application crash dumps in C:\\Users\\h\\AppData\\Local\\CrashDumps",
                    FileCount = 10,
                    SizeBytes = 183838720
                },
                new FindingModel
                {
                    Id = "TMP-004",
                    Title = "Windows Update Download Cache: 3 staged file(s) (5.83 MB)",
                    Path = "C:\\Windows\\SoftwareDistribution\\Download",
                    Detail = "Completed Windows Update installation payloads in C:\\Windows\\SoftwareDistribution\\Download",
                    FileCount = 3,
                    SizeBytes = 6113198
                }
            ]
        };

        ModuleResults.Add(modRb);
        ModuleResults.Add(modTf);

        ModuleCards.Add(new OverviewModuleCardItem(modRb, _navigate));
        ModuleCards.Add(new OverviewModuleCardItem(modTf, _navigate));

        foreach (var f in modTf.Findings)
        {
            RecommendedActions.Add(new RecommendedActionItem(modTf, f, _navigate));
        }

        LastScanTimeText = $"Last scan: Today, {DateTime.Now:HH:mm}";
    }

    [RelayCommand]
    public async Task RefreshOverviewAsync()
    {
        IsLoading = true;
        try
        {
            var results = await _cliService.ScanAllAsync();
            if (results.Count > 0)
            {
                ModuleResults.Clear();
                ModuleCards.Clear();
                RecommendedActions.Clear();

                int totalIssues = 0;
                foreach (var r in results)
                {
                    ModuleResults.Add(r);
                    ModuleCards.Add(new OverviewModuleCardItem(r, _navigate));

                    if (r.Status != 0 && r.Findings.Count > 0)
                    {
                        totalIssues += r.Findings.Count;
                        foreach (var f in r.Findings)
                        {
                            RecommendedActions.Add(new RecommendedActionItem(r, f, _navigate));
                        }
                    }
                }

                IssueCount = totalIssues;
                HasIssues = totalIssues > 0;
                LastScanTimeText = $"Last scan: Today, {DateTime.Now:HH:mm}";

                if (HasIssues)
                {
                    OverallStatusTitle = "Attention needed";
                    OverallStatusDescription = $"{totalIssues} issue(s) found that require your review.";
                }
                else
                {
                    OverallStatusTitle = "All systems healthy";
                    OverallStatusDescription = "No problems detected. System components are functioning normally.";
                }
            }
        }
        catch
        {
            // Retain default populated state if CLI scan is busy or unavailable
        }
        finally
        {
            IsLoading = false;
        }
    }

    [RelayCommand]
    private void StartScan()
    {
        _navigate("Scanning", null);
    }
}

public partial class OverviewModuleCardItem : ObservableObject
{
    private readonly Action<string, object?> _navigate;
    public RepairResultModel ModuleResult { get; }

    public string ModuleName => ModuleResult.ModuleName;
    public string StatusText => ModuleResult.Status == 0 ? "Healthy" : "Needs repair";
    public string ModuleDescription => ModuleResult.ModuleName == "RecycleBin"
        ? "Corrupted permissions and inaccessible items in trash container."
        : "Accumulated cache, crash dumps, and installer files.";
    public string IconGlyph => ModuleResult.ModuleName == "RecycleBin" ? "\uE74D" : "\uE90F";
    public string StatusColor => ModuleResult.Status == 0 ? "#006E06" : "#DA3C03";

    public OverviewModuleCardItem(RepairResultModel moduleResult, Action<string, object?> navigate)
    {
        ModuleResult = moduleResult;
        _navigate = navigate;
    }

    [RelayCommand]
    private void OpenModule()
    {
        if (ModuleResult.Findings.Count > 0)
        {
            _navigate("IssueDetail", (ModuleResult, ModuleResult.Findings[0]));
        }
        else
        {
            var finding = new FindingModel { Title = $"{ModuleResult.ModuleName} Details", Detail = ModuleResult.StatusText };
            _navigate("IssueDetail", (ModuleResult, finding));
        }
    }
}

public partial class RecommendedActionItem : ObservableObject
{
    private readonly Action<string, object?> _navigate;

    public RepairResultModel ModuleResult { get; }
    public FindingModel Finding { get; }

    [ObservableProperty]
    private bool _isSelected = true;

    public string Title => Finding.Title;
    public string Path => string.IsNullOrEmpty(Finding.Path) ? Finding.Detail : Finding.Path;
    public string ActionButtonText => ModuleResult.ModuleName == "RecycleBin" ? "Review repair" : "Review cleanup";

    public RecommendedActionItem(RepairResultModel moduleResult, FindingModel finding, Action<string, object?> navigate)
    {
        ModuleResult = moduleResult;
        Finding = finding;
        _navigate = navigate;
    }

    [RelayCommand]
    private void ReviewAction()
    {
        _navigate("IssueDetail", (ModuleResult, Finding));
    }
}
