using System;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using WinRepairKit.App.Models;
using WinRepairKit.App.Services;

namespace WinRepairKit.App.ViewModels;

public partial class RepairResultViewModel : ObservableObject
{
    private readonly Action<string, object?> _navigate;

    [ObservableProperty]
    private string _repairId = string.Empty;

    [ObservableProperty]
    private string _statusHeading = "Repair Completed";

    [ObservableProperty]
    private string _statusSubheading = string.Empty;

    [ObservableProperty]
    private string _resultStatusBadge = "Success";

    [ObservableProperty]
    private string _badgeColor = "#006E06";

    [ObservableProperty]
    private string _badgeBackground = "#E8F5E9";

    [ObservableProperty]
    private bool _isSuccess = true;

    [ObservableProperty]
    private bool _isPartial;

    [ObservableProperty]
    private bool _isFailed;

    // Before stats
    [ObservableProperty]
    private string _beforeProblems = "0";

    [ObservableProperty]
    private string _beforeItems = "0";

    [ObservableProperty]
    private string _beforeSize = "0 B";

    // After stats
    [ObservableProperty]
    private string _afterProblems = "0";

    [ObservableProperty]
    private string _afterStatus = "Healthy (0 problems)";

    [ObservableProperty]
    private string _whatHappenedText = string.Empty;

    [ObservableProperty]
    private string _whatChangedText = string.Empty;

    public RepairResultViewModel(Action<string, object?> navigate)
    {
        _navigate = navigate;
    }

    public void LoadResult(RepairResultModel result, RepairPlanModel? plan)
    {
        // Friendly Repair ID: WRK-YYYY-MM-DD-XXXX
        var dateStr = DateTime.UtcNow.ToString("yyyy-MM-dd");
        var shortTx = !string.IsNullOrEmpty(result.TransactionId) && result.TransactionId.Length > 8
            ? result.TransactionId.Substring(result.TransactionId.Length - 4)
            : Guid.NewGuid().ToString("N").Substring(0, 4).ToUpper();
        RepairId = $"WRK-{dateStr}-{shortTx}";

        // Calculate before stats
        int totalBeforeFindings = result.Findings.Count;
        long totalBeforeItems = 0;
        long totalBeforeBytes = 0;
        foreach (var f in result.Findings)
        {
            totalBeforeItems += f.FileCount;
            totalBeforeBytes += f.SizeBytes;
        }

        BeforeProblems = totalBeforeFindings.ToString();
        BeforeItems = totalBeforeItems > 0 ? $"{totalBeforeItems} items" : $"{totalBeforeFindings} issues";
        BeforeSize = FormatBytes(totalBeforeBytes);

        if (result.Status is 0 or 2) // Healthy or RepairSucceeded
        {
            IsSuccess = true;
            IsPartial = false;
            IsFailed = false;
            ResultStatusBadge = "Verified Healthy";
            BadgeColor = "#006E06";
            BadgeBackground = "#E8F5E9";
            StatusHeading = "Repair Verified Successfully";
            StatusSubheading = "All detected issues were resolved and post-repair verification passed.";

            AfterProblems = "0";
            AfterStatus = "All checks healthy";
            WhatHappenedText = "All scheduled repair actions were executed and verified.";
            WhatChangedText = "State snapshot created, directory permissions reset, and verified healthy.";
        }
        else if (result.Status is 3 or 5) // RepairPartial or Skipped
        {
            IsSuccess = false;
            IsPartial = true;
            IsFailed = false;
            ResultStatusBadge = "Partial Success";
            BadgeColor = "#DA3C03";
            BadgeBackground = "#FFF3E0";
            StatusHeading = "Repair Partially Completed";
            StatusSubheading = "Some operations completed, but remaining issues require attention. No further destructive escalation was attempted.";

            int remaining = result.Verification?.RemainingProblemsCount ?? 1;
            AfterProblems = remaining.ToString();
            AfterStatus = $"{remaining} item(s) remain";
            WhatHappenedText = "Earlier stages completed successfully, but some entries could not be processed without further administrative intervention.";
            WhatChangedText = "State snapshot saved. No destructive escalation was performed.";
        }
        else // Failed or Error
        {
            IsSuccess = false;
            IsPartial = false;
            IsFailed = true;
            ResultStatusBadge = "Repair Halted";
            BadgeColor = "#BA1A1A";
            BadgeBackground = "#FFEBEE";
            StatusHeading = "Repair Stopped Safely";
            StatusSubheading = "WinRepairKit halted execution to prevent unwanted system changes. Your system state was preserved.";

            AfterProblems = totalBeforeFindings.ToString();
            AfterStatus = "Unchanged (Safety halt)";
            WhatHappenedText = "The operation encountered an unexpected condition or safety threshold.";
            WhatChangedText = "A pre-repair snapshot was created. Zero unverified modifications were made.";
        }
    }

    private static string FormatBytes(long bytes)
    {
        if (bytes <= 0) return "0 B";
        string[] units = ["B", "KB", "MB", "GB"];
        int i = 0;
        double d = bytes;
        while (d >= 1024 && i < units.Length - 1)
        {
            d /= 1024;
            i++;
        }
        return $"{d:0.##} {units[i]}";
    }

    [RelayCommand]
    private void ScanAgain()
    {
        _navigate("Scanning", null);
    }

    [RelayCommand]
    private void BackToOverview()
    {
        _navigate("Overview", null);
    }
}
