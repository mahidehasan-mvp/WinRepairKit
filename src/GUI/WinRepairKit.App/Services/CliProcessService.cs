using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using WinRepairKit.App.Models;

namespace WinRepairKit.App.Services;

public class CliProcessService
{
    private readonly string _cliScriptPath;

    public CliProcessService()
    {
        _cliScriptPath = FindCliScript();
    }

    private static string FindCliScript()
    {
        var baseDir = AppDomain.CurrentDomain.BaseDirectory;

        // Relative candidates for local debugging, published dist, and repo root
        string[] candidates = [
            Path.Combine(baseDir, "CLI", "winrepair.ps1"),
            Path.Combine(baseDir, "src", "CLI", "winrepair.ps1"),
            Path.Combine(baseDir, "..", "src", "CLI", "winrepair.ps1"),
            Path.Combine(baseDir, "..", "..", "src", "CLI", "winrepair.ps1"),
            Path.Combine(baseDir, "..", "..", "..", "src", "CLI", "winrepair.ps1"),
            Path.Combine(baseDir, "..", "..", "..", "..", "src", "CLI", "winrepair.ps1"),
            Path.Combine(baseDir, "..", "..", "..", "..", "..", "src", "CLI", "winrepair.ps1"),
            Path.Combine(Environment.CurrentDirectory, "src", "CLI", "winrepair.ps1"),
            Path.Combine(Environment.CurrentDirectory, "CLI", "winrepair.ps1"),
            "winrepair.ps1"
        ];

        foreach (var candidate in candidates)
        {
            try
            {
                var full = Path.GetFullPath(candidate);
                if (File.Exists(full))
                {
                    return full;
                }
            }
            catch {}
        }

        return Path.Combine(baseDir, "winrepair.ps1");
    }

    public async Task<List<RepairResultModel>> ScanAllAsync(CancellationToken ct = default)
    {
        var json = await ExecuteCliAsync("scan -Json", ct);
        if (string.IsNullOrWhiteSpace(json)) return [];

        try
        {
            if (json.TrimStart().StartsWith('['))
            {
                return JsonSerializer.Deserialize<List<RepairResultModel>>(json) ?? [];
            }
            else
            {
                var single = JsonSerializer.Deserialize<RepairResultModel>(json);
                return single != null ? [single] : [];
            }
        }
        catch
        {
            return [];
        }
    }

    public async Task<RepairResultModel?> ScanModuleAsync(string moduleName, CancellationToken ct = default)
    {
        var json = await ExecuteCliAsync($"scan -Module {moduleName} -Json", ct);
        if (string.IsNullOrWhiteSpace(json)) return null;

        try
        {
            if (json.TrimStart().StartsWith('['))
            {
                var list = JsonSerializer.Deserialize<List<RepairResultModel>>(json);
                return list?.Count > 0 ? list[0] : null;
            }
            return JsonSerializer.Deserialize<RepairResultModel>(json);
        }
        catch
        {
            return null;
        }
    }

    public async Task<RepairPlanModel?> GetPlanAsync(string moduleName, CancellationToken ct = default)
    {
        var json = await ExecuteCliAsync($"plan -Module {moduleName} -Json", ct);
        if (string.IsNullOrWhiteSpace(json)) return null;

        try
        {
            if (json.TrimStart().StartsWith('['))
            {
                var list = JsonSerializer.Deserialize<List<RepairPlanModel>>(json);
                return list?.Count > 0 ? list[0] : null;
            }
            return JsonSerializer.Deserialize<RepairPlanModel>(json);
        }
        catch
        {
            return null;
        }
    }

    public async Task<RepairResultModel?> ExecuteRepairAsync(string moduleName, bool dryRun, bool confirmFix, Action<string>? logCallback = null, CancellationToken ct = default)
    {
        var args = $"repair -Module {moduleName} -Json";
        if (dryRun) args += " -DryRun";
        if (confirmFix) args += " -ConfirmFix";

        var json = await ExecuteCliAsync(args, ct, logCallback);
        if (string.IsNullOrWhiteSpace(json)) return null;

        try
        {
            if (json.TrimStart().StartsWith('['))
            {
                var list = JsonSerializer.Deserialize<List<RepairResultModel>>(json);
                return list?.Count > 0 ? list[0] : null;
            }
            return JsonSerializer.Deserialize<RepairResultModel>(json);
        }
        catch
        {
            return null;
        }
    }

    private async Task<string> ExecuteCliAsync(string arguments, CancellationToken ct = default, Action<string>? logCallback = null)
    {
        var outputSb = new StringBuilder();
        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{_cliScriptPath}\" {arguments}",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8
        };

        using var process = new Process { StartInfo = psi };
        process.OutputDataReceived += (_, e) =>
        {
            if (e.Data != null)
            {
                outputSb.AppendLine(e.Data);
                logCallback?.Invoke(e.Data);
            }
        };

        process.Start();
        process.BeginOutputReadLine();

        await process.WaitForExitAsync(ct);
        return outputSb.ToString();
    }
}
