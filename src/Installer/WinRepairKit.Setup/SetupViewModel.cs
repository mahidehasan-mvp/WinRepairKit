using System;
using System.Diagnostics;
using System.IO;
using System.Security.Principal;
using System.Threading.Tasks;
using System.Windows;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Win32;

namespace WinRepairKit.Setup;

public partial class SetupViewModel : ObservableObject
{
    [ObservableProperty]
    private int _currentStep = 1;

    [ObservableProperty]
    private string _installPath = string.Empty;

    [ObservableProperty]
    private bool _addToPath = true;

    [ObservableProperty]
    private bool _createDesktopShortcut = true;

    [ObservableProperty]
    private bool _createStartMenuShortcut = true;

    [ObservableProperty]
    private bool _launchOnFinish = true;

    [ObservableProperty]
    private string _progressStatusText = "Preparing installation...";

    [ObservableProperty]
    private string _errorMessage = string.Empty;

    [ObservableProperty]
    private bool _hasError;

    [ObservableProperty]
    private string _nextButtonText = "Next >";

    public Visibility Step1Visibility => CurrentStep == 1 ? Visibility.Visible : Visibility.Collapsed;
    public Visibility Step2Visibility => CurrentStep == 2 ? Visibility.Visible : Visibility.Collapsed;
    public Visibility Step3Visibility => CurrentStep == 3 ? Visibility.Visible : Visibility.Collapsed;
    public Visibility Step4Visibility => CurrentStep == 4 ? Visibility.Visible : Visibility.Collapsed;

    public Visibility BackButtonVisibility => (CurrentStep == 2 && !HasError) ? Visibility.Visible : Visibility.Collapsed;

    public SetupViewModel()
    {
        // Default to Program Files (elevated installer)
        InstallPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "WinRepairKit");
    }

    [RelayCommand]
    private async Task NextAsync()
    {
        if (CurrentStep == 1)
        {
            CurrentStep = 2;
            NextButtonText = "Install";
            UpdateVisibilities();
        }
        else if (CurrentStep == 2)
        {
            CurrentStep = 3;
            NextButtonText = "Installing...";
            HasError = false;
            ErrorMessage = string.Empty;
            UpdateVisibilities();
            await PerformNativeInstallAsync();
        }
        else if (CurrentStep == 4)
        {
            if (LaunchOnFinish)
            {
                var exe = Path.Combine(InstallPath, "WinRepairKit.exe");
                if (File.Exists(exe))
                {
                    try
                    {
                        Process.Start(new ProcessStartInfo
                        {
                            FileName = exe,
                            WorkingDirectory = InstallPath,
                            UseShellExecute = true
                        });
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Could not launch WinRepairKit: {ex.Message}", "Launch Error", MessageBoxButton.OK, MessageBoxImage.Warning);
                    }
                }
            }
            Application.Current.Shutdown();
        }
    }

    [RelayCommand]
    private void Back()
    {
        if (CurrentStep == 2)
        {
            CurrentStep = 1;
            NextButtonText = "Next >";
            UpdateVisibilities();
        }
    }

    private void UpdateVisibilities()
    {
        OnPropertyChanged(nameof(Step1Visibility));
        OnPropertyChanged(nameof(Step2Visibility));
        OnPropertyChanged(nameof(Step3Visibility));
        OnPropertyChanged(nameof(Step4Visibility));
        OnPropertyChanged(nameof(BackButtonVisibility));
    }

    private async Task PerformNativeInstallAsync()
    {
        try
        {
            ProgressStatusText = "Locating installation package files...";
            await Task.Delay(200);

            var (payloadDir, engineDir, cliDir) = FindPayloadSources();
            if (string.IsNullOrEmpty(payloadDir) || !Directory.Exists(payloadDir))
            {
                throw new DirectoryNotFoundException($"Could not locate payload binaries directory (searched in {AppDomain.CurrentDomain.BaseDirectory})");
            }

            // 1. Create target directory
            ProgressStatusText = $"Creating destination directory: {InstallPath}...";
            if (!Directory.Exists(InstallPath))
            {
                Directory.CreateDirectory(InstallPath);
            }

            // 2. Copy binaries
            ProgressStatusText = "Copying core application binaries...";
            await Task.Delay(200);

            string[] mainFiles = [
                "WinRepairKit.exe",
                "WinRepairKit.dll",
                "WinRepairKit.runtimeconfig.json",
                "WinRepairKit.deps.json",
                "CommunityToolkit.Mvvm.dll"
            ];

            foreach (var fileName in mainFiles)
            {
                var srcFile = Path.Combine(payloadDir, fileName);
                if (File.Exists(srcFile))
                {
                    var destFile = Path.Combine(InstallPath, fileName);
                    File.Copy(srcFile, destFile, overwrite: true);
                }
            }

            // Also copy all dlls and json files from payloadDir
            foreach (var f in Directory.GetFiles(payloadDir, "*.*"))
            {
                var fname = Path.GetFileName(f);
                if (!fname.Equals("WinRepairKit.Setup.exe", StringComparison.OrdinalIgnoreCase) &&
                    !fname.Equals("WinRepairKit.Setup.dll", StringComparison.OrdinalIgnoreCase))
                {
                    var dest = Path.Combine(InstallPath, fname);
                    File.Copy(f, dest, overwrite: true);
                }
            }

            // 3. Copy Engine directory
            ProgressStatusText = "Installing diagnostic and repair engine...";
            await Task.Delay(200);
            var targetEngine = Path.Combine(InstallPath, "Engine");
            if (!string.IsNullOrEmpty(engineDir) && Directory.Exists(engineDir))
            {
                CopyDirectoryRecursive(engineDir, targetEngine);
            }

            // 4. Copy CLI directory
            ProgressStatusText = "Installing command-line tools...";
            var targetCli = Path.Combine(InstallPath, "CLI");
            if (!string.IsNullOrEmpty(cliDir) && Directory.Exists(cliDir))
            {
                CopyDirectoryRecursive(cliDir, targetCli);
            }

            // 5. Create winrepair.cmd shim
            var shimPath = Path.Combine(InstallPath, "winrepair.cmd");
            var shimContent = "@echo off\r\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%~dp0CLI\\winrepair.ps1\" %*\r\n";
            File.WriteAllText(shimPath, shimContent);

            // 6. Write uninstaller script
            var uninstallScriptPath = Path.Combine(InstallPath, "Uninstall-WinRepairKit.ps1");
            var uninstallerContent = @"# WinRepairKit - Clean Uninstaller
[CmdletBinding()]
param([switch]$Quiet)

$installDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

# Remove Start Menu
$sm = Join-Path -Path ([Environment]::GetFolderPath('CommonStartMenu')) -ChildPath 'Programs\WinRepairKit'
if (Test-Path $sm) { Remove-Item -Path $sm -Recurse -Force }

# Remove Desktop
$dt = Join-Path -Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) -ChildPath 'WinRepairKit.lnk'
if (Test-Path $dt) { Remove-Item -Path $dt -Force }

# Remove PATH
$curPath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
if ($curPath) {
    $parts = $curPath -split ';' | Where-Object { $_ -and $_ -ne $installDir }
    [Environment]::SetEnvironmentVariable('PATH', ($parts -join ';'), 'Machine')
}

# Remove Registry
$reg = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\WinRepairKit'
if (Test-Path $reg) { Remove-Item -Path $reg -Recurse -Force }

# Remove Directory
Start-Process -FilePath 'cmd.exe' -ArgumentList ""/c timeout /t 2 & rmdir /s /q `""$installDir`"""" -WindowStyle Hidden
";
            File.WriteAllText(uninstallScriptPath, uninstallerContent);

            // 7. Update PATH if requested
            if (AddToPath)
            {
                ProgressStatusText = "Updating system environment PATH...";
                try
                {
                    var curPath = Environment.GetEnvironmentVariable("PATH", EnvironmentVariableTarget.Machine) ?? string.Empty;
                    var paths = curPath.Split(';', StringSplitOptions.RemoveEmptyEntries);
                    bool exists = false;
                    foreach (var p in paths)
                    {
                        if (p.TrimEnd('\\', '/').Equals(InstallPath.TrimEnd('\\', '/'), StringComparison.OrdinalIgnoreCase))
                        {
                            exists = true;
                            break;
                        }
                    }
                    if (!exists)
                    {
                        var newPath = string.IsNullOrEmpty(curPath) ? InstallPath : $"{curPath};{InstallPath}";
                        Environment.SetEnvironmentVariable("PATH", newPath, EnvironmentVariableTarget.Machine);
                    }
                }
                catch {}
            }

            // 8. Create Shortcuts
            ProgressStatusText = "Creating application shortcuts...";
            var targetExe = Path.Combine(InstallPath, "WinRepairKit.exe");

            if (CreateStartMenuShortcut)
            {
                try
                {
                    var startMenuDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonPrograms), "WinRepairKit");
                    if (!Directory.Exists(startMenuDir)) Directory.CreateDirectory(startMenuDir);
                    CreateShortcut(Path.Combine(startMenuDir, "WinRepairKit.lnk"), targetExe, InstallPath, "Windows Repair & Maintenance Toolkit");
                }
                catch {}
            }

            if (CreateDesktopShortcut)
            {
                try
                {
                    var desktopDir = Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory);
                    CreateShortcut(Path.Combine(desktopDir, "WinRepairKit.lnk"), targetExe, InstallPath, "Windows Repair & Maintenance Toolkit");
                }
                catch {}
            }

            // 9. Register in Add/Remove Programs (Registry)
            ProgressStatusText = "Registering in Windows Programs and Features...";
            try
            {
                using var key = Registry.LocalMachine.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\WinRepairKit");
                if (key != null)
                {
                    key.SetValue("DisplayName", "WinRepairKit");
                    key.SetValue("DisplayVersion", "0.1.0");
                    key.SetValue("Publisher", "WinRepairKit Contributors");
                    key.SetValue("InstallLocation", InstallPath);
                    key.SetValue("DisplayIcon", $"{targetExe},0");
                    key.SetValue("UninstallString", $"powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"{uninstallScriptPath}\"");
                    key.SetValue("NoModify", 1, RegistryValueKind.DWord);
                    key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
                }
            }
            catch {}

            // 10. Final Verification
            if (!File.Exists(targetExe))
            {
                throw new FileNotFoundException($"Verification failed: {targetExe} was not found after installation.");
            }

            ProgressStatusText = "Installation completed successfully!";
            await Task.Delay(300);

            CurrentStep = 4;
            NextButtonText = "Finish";
            UpdateVisibilities();
        }
        catch (Exception ex)
        {
            HasError = true;
            ErrorMessage = $"Installation Failed: {ex.Message}";
            ProgressStatusText = "Installation failed.";
            NextButtonText = "Close";
            UpdateVisibilities();
        }
    }

    private static (string payloadDir, string engineDir, string cliDir) FindPayloadSources()
    {
        var baseDir = AppDomain.CurrentDomain.BaseDirectory;

        // Search candidates for payload binaries
        string[] binaryCandidates = [
            baseDir,
            Path.Combine(baseDir, ".."),
            Path.Combine(baseDir, "..", "..", "dist"),
            Path.Combine(baseDir, "..", "..", "..", "dist"),
            Path.Combine(baseDir, "..", "..", "..", "..", "dist"),
            @"E:\code\windows\tool\Windows Repair & Maintenance Toolkit\dist",
            @"E:\code\windows\tool\Windows Repair & Maintenance Toolkit\src\GUI\WinRepairKit.App\bin\Release\net8.0-windows"
        ];

        string payloadDir = string.Empty;
        foreach (var c in binaryCandidates)
        {
            try
            {
                var full = Path.GetFullPath(c);
                if (File.Exists(Path.Combine(full, "WinRepairKit.exe")) || File.Exists(Path.Combine(full, "WinRepairKit.dll")))
                {
                    payloadDir = full;
                    break;
                }
            }
            catch {}
        }

        // Search candidates for Engine directory
        string[] engineCandidates = [
            Path.Combine(payloadDir, "Engine"),
            Path.Combine(baseDir, "Engine"),
            Path.Combine(baseDir, "..", "Engine"),
            Path.Combine(baseDir, "..", "..", "src", "Engine"),
            Path.Combine(baseDir, "..", "..", "..", "src", "Engine"),
            Path.Combine(baseDir, "..", "..", "..", "..", "src", "Engine"),
            @"E:\code\windows\tool\Windows Repair & Maintenance Toolkit\src\Engine"
        ];

        string engineDir = string.Empty;
        foreach (var c in engineCandidates)
        {
            try
            {
                var full = Path.GetFullPath(c);
                if (Directory.Exists(full) && File.Exists(Path.Combine(full, "WinRepairKit.psd1")))
                {
                    engineDir = full;
                    break;
                }
            }
            catch {}
        }

        // Search candidates for CLI directory
        string[] cliCandidates = [
            Path.Combine(payloadDir, "CLI"),
            Path.Combine(baseDir, "CLI"),
            Path.Combine(baseDir, "..", "CLI"),
            Path.Combine(baseDir, "..", "..", "src", "CLI"),
            Path.Combine(baseDir, "..", "..", "..", "src", "CLI"),
            Path.Combine(baseDir, "..", "..", "..", "..", "src", "CLI"),
            @"E:\code\windows\tool\Windows Repair & Maintenance Toolkit\src\CLI"
        ];

        string cliDir = string.Empty;
        foreach (var c in cliCandidates)
        {
            try
            {
                var full = Path.GetFullPath(c);
                if (Directory.Exists(full) && File.Exists(Path.Combine(full, "winrepair.ps1")))
                {
                    cliDir = full;
                    break;
                }
            }
            catch {}
        }

        return (payloadDir, engineDir, cliDir);
    }

    private static void CopyDirectoryRecursive(string sourceDir, string targetDir)
    {
        if (!Directory.Exists(targetDir))
        {
            Directory.CreateDirectory(targetDir);
        }

        foreach (var file in Directory.GetFiles(sourceDir))
        {
            var dest = Path.Combine(targetDir, Path.GetFileName(file));
            File.Copy(file, dest, overwrite: true);
        }

        foreach (var dir in Directory.GetDirectories(sourceDir))
        {
            var dest = Path.Combine(targetDir, Path.GetFileName(dir));
            CopyDirectoryRecursive(dir, dest);
        }
    }

    private static void CreateShortcut(string shortcutPath, string targetPath, string workingDir, string description)
    {
        try
        {
            var shellType = Type.GetTypeFromProgID("WScript.Shell");
            if (shellType != null)
            {
                dynamic shell = Activator.CreateInstance(shellType)!;
                dynamic shortcut = shell.CreateShortcut(shortcutPath);
                shortcut.TargetPath = targetPath;
                shortcut.WorkingDirectory = workingDir;
                shortcut.Description = description;
                shortcut.Save();
            }
        }
        catch {}
    }
}
