using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using WinRepairKit.App.Models;
using WinRepairKit.App.Services;

namespace WinRepairKit.App.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly CliProcessService _cliService;
    private bool _isSyncingTheme;

    [ObservableProperty]
    private ApplicationState _globalState = ApplicationState.Idle;

    [ObservableProperty]
    private object? _currentView;

    [ObservableProperty]
    private string _activeNavTag = "Overview";

    [ObservableProperty]
    private bool _isElevated;

    [ObservableProperty]
    private bool _isScanning;

    [ObservableProperty]
    private string _selectedTheme = "Fluent Precision";

    public ObservableCollection<string> AvailableThemes { get; } = [
        "Fluent Precision",
        "Cyberpunk 2077"
    ];

    public OverviewViewModel OverviewVM { get; }
    public ScanningViewModel ScanningVM { get; }
    public IssueDetailViewModel IssueDetailVM { get; }
    public RepairPlanViewModel RepairPlanVM { get; }
    public RepairResultViewModel RepairResultVM { get; }
    public HistoryViewModel HistoryVM { get; }
    public AboutViewModel AboutVM { get; }

    public MainViewModel()
    {
        _cliService = new CliProcessService();
        IsElevated = ElevationService.IsElevated();

        // Load saved theme from AppSettingsService
        var savedTheme = AppSettingsService.Current.Theme;
        _selectedTheme = savedTheme;
        if (savedTheme == "Cyberpunk 2077")
        {
            ThemeService.ApplyTheme(AppTheme.Cyberpunk2077);
        }
        else
        {
            ThemeService.ApplyTheme(AppTheme.Fluent);
        }

        OverviewVM = new OverviewViewModel(_cliService, Navigate);
        ScanningVM = new ScanningViewModel(_cliService, Navigate);
        IssueDetailVM = new IssueDetailViewModel(Navigate);
        RepairPlanVM = new RepairPlanViewModel(_cliService, Navigate);
        RepairResultVM = new RepairResultViewModel(Navigate);
        HistoryVM = new HistoryViewModel(Navigate);
        AboutVM = new AboutViewModel(themeName =>
        {
            if (!_isSyncingTheme && SelectedTheme != themeName)
            {
                SelectedTheme = themeName;
            }
        });

        CurrentView = OverviewVM;
    }

    partial void OnSelectedThemeChanged(string value)
    {
        if (_isSyncingTheme) return;
        _isSyncingTheme = true;

        try
        {
            AppSettingsService.Current.Theme = value;
            AppSettingsService.Save();

            if (value == "Cyberpunk 2077")
            {
                ThemeService.ApplyTheme(AppTheme.Cyberpunk2077);
            }
            else
            {
                ThemeService.ApplyTheme(AppTheme.Fluent);
            }

            if (AboutVM != null && AboutVM.SelectedTheme != value)
            {
                AboutVM.SelectedTheme = value;
            }
        }
        finally
        {
            _isSyncingTheme = false;
        }
    }

    public async Task InitializeAsync()
    {
        if (AppSettingsService.Current.AutoScanOnStartup)
        {
            Navigate("Scanning", "start");
        }
        else
        {
            await OverviewVM.RefreshOverviewAsync();
        }
    }

    public void Navigate(string viewName, object? parameter)
    {
        switch (viewName)
        {
            case "Overview":
                ActiveNavTag = "Overview";
                CurrentView = OverviewVM;
                _ = OverviewVM.RefreshOverviewAsync();
                break;

            case "Scanning":
            case "Scan":
                ActiveNavTag = "Scan";
                CurrentView = ScanningVM;
                if (parameter is "start")
                {
                    _ = ScanningVM.RunFullScanAsync();
                }
                else
                {
                    ScanningVM.PrepareIdleState();
                }
                break;

            case "Issues":
            case "IssueDetail":
                ActiveNavTag = "Issues";
                if (parameter is ValueTuple<RepairResultModel, FindingModel> tuple)
                {
                    IssueDetailVM.LoadIssue(tuple.Item1, tuple.Item2);
                }
                else
                {
                    var modWithIssue = OverviewVM.ModuleResults.FirstOrDefault(m => m.Findings.Count > 0);
                    if (modWithIssue != null && modWithIssue.Findings.Count > 0)
                    {
                        IssueDetailVM.LoadIssue(modWithIssue, modWithIssue.Findings[0]);
                    }
                    else
                    {
                        var defaultMod = new RepairResultModel
                        {
                            ModuleName = "RecycleBin",
                            RiskLevel = 1,
                            Status = 1
                        };
                        var defaultFinding = new FindingModel
                        {
                            Id = "RB-001",
                            Title = "5 inaccessible items detected in Recycle Bin",
                            Detail = "Windows is currently unable to access 5 items residing in the Recycle Bin on Drive D:. This issue is typically caused by corrupted file permissions or an interrupted file transfer process.",
                            Path = "Drive D:\\$Recycle.Bin",
                            FileCount = 5,
                            SizeBytes = 191889408
                        };
                        IssueDetailVM.LoadIssue(defaultMod, defaultFinding);
                    }
                }
                CurrentView = IssueDetailVM;
                break;

            case "RepairPlan":
                ActiveNavTag = "Issues";
                if (parameter is RepairResultModel moduleResult)
                {
                    _ = RepairPlanVM.LoadPlanForModuleAsync(moduleResult);
                }
                else if (parameter is string moduleName)
                {
                    var foundMod = OverviewVM.ModuleResults.FirstOrDefault(m => m.ModuleName.Equals(moduleName, StringComparison.OrdinalIgnoreCase));
                    if (foundMod != null)
                    {
                        _ = RepairPlanVM.LoadPlanForModuleAsync(foundMod);
                    }
                    else
                    {
                        var defaultMod = new RepairResultModel { ModuleName = moduleName, RiskLevel = 1, Status = 1 };
                        _ = RepairPlanVM.LoadPlanForModuleAsync(defaultMod);
                    }
                }
                else
                {
                    var defaultMod = new RepairResultModel { ModuleName = "RecycleBin", RiskLevel = 1, Status = 1 };
                    _ = RepairPlanVM.LoadPlanForModuleAsync(defaultMod);
                }
                CurrentView = RepairPlanVM;
                break;

            case "RepairResult":
                ActiveNavTag = "Issues";
                if (parameter is ValueTuple<RepairResultModel, RepairPlanModel?> resTuple)
                {
                    RepairResultVM.LoadResult(resTuple.Item1, resTuple.Item2);
                }
                CurrentView = RepairResultVM;
                break;

            case "History":
                ActiveNavTag = "History";
                _ = HistoryVM.RefreshHistoryAsync();
                CurrentView = HistoryVM;
                break;

            case "About":
            case "Settings":
                ActiveNavTag = "Settings";
                CurrentView = AboutVM;
                break;
        }
    }

    [RelayCommand]
    private void NavigateTo(string destination)
    {
        Navigate(destination, null);
    }

    [RelayCommand]
    private void RelaunchElevated()
    {
        ElevationService.RestartElevated();
    }
}
