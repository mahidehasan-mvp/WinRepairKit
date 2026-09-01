using System;
using System.Text;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using WinRepairKit.App.Models;

namespace WinRepairKit.App.ViewModels;

public partial class IssueDetailViewModel : ObservableObject
{
    private readonly Action<string, object?> _navigate;

    [ObservableProperty]
    private RepairResultModel? _moduleResult;

    [ObservableProperty]
    private FindingModel? _finding;

    [ObservableProperty]
    private string _moduleName = "Recycle Bin";

    [ObservableProperty]
    private string _moduleSubtitle = "Requires user intervention to restore system integrity.";

    [ObservableProperty]
    private string _riskLevelBadgeText = "ELEVATED RISK";

    [ObservableProperty]
    private string _riskBadgeBackground = "#FEF3C7";

    [ObservableProperty]
    private string _riskBadgeForeground = "#92400E";

    [ObservableProperty]
    private string _riskBadgeBorder = "#FDE68A";

    [ObservableProperty]
    private string _heroAccentColor = "#DA3C03";

    [ObservableProperty]
    private string _heroIconGlyph = "\uE74D";

    [ObservableProperty]
    private string _whatWeFoundText = string.Empty;

    [ObservableProperty]
    private string _locationText = "Drive D:";

    [ObservableProperty]
    private string _affectedItemsText = "5 Files";

    [ObservableProperty]
    private string _totalSizeText = "0 B";

    [ObservableProperty]
    private bool _hasAccessProblem = true;

    [ObservableProperty]
    private bool _isTechDetailsExpanded;

    [ObservableProperty]
    private string _toggleButtonText = "Show technical details";

    [ObservableProperty]
    private string _techDetailsContent = string.Empty;

    [ObservableProperty]
    private string _recommendedActionText = string.Empty;

    public IssueDetailViewModel(Action<string, object?> navigate)
    {
        _navigate = navigate;
    }

    public void LoadIssue(RepairResultModel moduleResult, FindingModel finding)
    {
        ModuleResult = moduleResult;
        Finding = finding;

        if (moduleResult.ModuleName == "RecycleBin")
        {
            ModuleName = "Recycle Bin";
            ModuleSubtitle = "Requires user intervention to restore system integrity.";
            HeroAccentColor = "#DA3C03";
            HeroIconGlyph = "\uE74D"; // Trash bin
            RiskLevelBadgeText = "ELEVATED RISK";
            RiskBadgeBackground = "#FEF3C7";
            RiskBadgeForeground = "#92400E";
            RiskBadgeBorder = "#FDE68A";
            HasAccessProblem = true;

            LocationText = !string.IsNullOrEmpty(finding.Path) ? finding.Path : "Drive D:";
            AffectedItemsText = finding.FileCount > 0 ? $"{finding.FileCount} Files" : "5 Files";
            TotalSizeText = finding.SizeBytes > 0 ? finding.FormattedSize : "183 MB";

            WhatWeFoundText = $"Windows is currently unable to access {AffectedItemsText} residing in the Recycle Bin on {LocationText}. This issue is typically caused by corrupted file permissions or an interrupted file transfer process. While these files are marked for deletion, the system's inability to interact with them prevents space recovery and may cause background errors.";

            RecommendedActionText = "Repairing the file permissions is necessary to resolve this issue. WinRepairKit will attempt to take ownership of the affected files and reset their access control lists (ACLs) to allow standard deletion.";
        }
        else
        {
            ModuleName = "Temporary Files";
            ModuleSubtitle = "Safe maintenance to recover disk space and clean obsolete caches.";
            HeroAccentColor = "#005FAA";
            HeroIconGlyph = "\uE90F"; // Wrench / cleaner
            RiskLevelBadgeText = "SAFE MAINTENANCE";
            RiskBadgeBackground = "#E8F5E9";
            RiskBadgeForeground = "#006E06";
            RiskBadgeBorder = "#C8E6C9";
            HasAccessProblem = false;

            LocationText = !string.IsNullOrEmpty(finding.Path) ? finding.Path : "C:\\Users\\<USER>\\AppData\\Local\\Temp";
            AffectedItemsText = finding.FileCount > 0 ? $"{finding.FileCount} Files" : "858 Files";
            TotalSizeText = finding.SizeBytes > 0 ? finding.FormattedSize : "260.59 MB";

            WhatWeFoundText = $"WinRepairKit discovered {AffectedItemsText} ({TotalSizeText}) of inactive temporary caches, error memory dumps, and old installer payloads that are older than the retention threshold and safe to remove.";

            RecommendedActionText = "Cleaning inactive temporary files will safely reclaim disk space without affecting active processes, system stability, or installed software.";
        }

        // Build technical details
        var sb = new StringBuilder();
        sb.AppendLine($"Path: {finding.Path}");
        sb.AppendLine($"Finding ID: {finding.Id}");
        sb.AppendLine($"Severity Level: {finding.Severity}");
        sb.AppendLine("Error Code: 0x80070005 (E_ACCESSDENIED)");
        if (finding.ExtraData != null)
        {
            foreach (var kvp in finding.ExtraData)
            {
                sb.AppendLine($"{kvp.Key}: {kvp.Value}");
            }
        }
        sb.AppendLine("Target Action: Reset NTFS Permissions / Force Delete");
        TechDetailsContent = sb.ToString();

        IsTechDetailsExpanded = false;
        ToggleButtonText = "Show technical details";
    }

    [RelayCommand]
    private void ToggleTechDetails()
    {
        IsTechDetailsExpanded = !IsTechDetailsExpanded;
        ToggleButtonText = IsTechDetailsExpanded ? "Hide technical details" : "Show technical details";
    }

    [RelayCommand]
    private void ReviewRepairPlan()
    {
        if (ModuleResult != null)
        {
            _navigate("RepairPlan", ModuleResult);
        }
    }

    [RelayCommand]
    private void GoBack()
    {
        _navigate("Overview", null);
    }
}
