# WinRepairKit - Setup & Installation Script
# Installs WinRepairKit desktop application, CLI tools, and engine components.

[CmdletBinding()]
param(
    [Parameter()]
    [string]$InstallDir,

    [Parameter()]
    [bool]$AddToPath = $true,

    [Parameter()]
    [bool]$CreateDesktopShortcut = $true,

    [Parameter()]
    [bool]$CreateStartMenuShortcut = $true,

    [Parameter()]
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Write-SetupLog {
    param([string]$Message, [string]$Color = 'Cyan')
    if (-not $Quiet) {
        Write-Host -ForegroundColor $Color "  [Setup] $Message"
    }
}

if (-not $Quiet) {
    Write-Host -ForegroundColor Cyan @"
===============================================================================
  WinRepairKit v0.1.0 — Installer
  Transparent, Safety-First Windows 10 & 11 Repair Toolkit
===============================================================================
"@
}

# 1. Determine Target Directory
$isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $InstallDir) {
    if ($isElevated) {
        $InstallDir = Join-Path -Path $env:ProgramFiles -ChildPath "WinRepairKit"
    }
    else {
        $InstallDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Programs\WinRepairKit"
    }
}

Write-SetupLog "Target Directory: $InstallDir" -Color 'Yellow'

# 2. Source Payload Paths
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$repoRoot = Split-Path -Path $scriptDir -Parent
if (-not (Test-Path -LiteralPath (Join-Path -Path $repoRoot -ChildPath "src"))) {
    $repoRoot = Split-Path -Path $repoRoot -Parent
}

$distDir = Join-Path -Path $repoRoot -ChildPath "dist"
$engineSrcDir = Join-Path -Path $repoRoot -ChildPath "src\Engine"
$cliSrcDir = Join-Path -Path $repoRoot -ChildPath "src\CLI"

# 3. Create Target Directories
if (-not (Test-Path -LiteralPath $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

$targetEngineDir = Join-Path -Path $InstallDir -ChildPath "Engine"
$targetCliDir = Join-Path -Path $InstallDir -ChildPath "CLI"
New-Item -ItemType Directory -Path $targetEngineDir -Force | Out-Null
New-Item -ItemType Directory -Path $targetCliDir -Force | Out-Null

# 4. Copy Binaries & Assets
Write-SetupLog "Copying GUI application binaries..."
if (Test-Path -LiteralPath $distDir) {
    $files = Get-ChildItem -Path $distDir -File
    foreach ($f in $files) {
        Copy-Item -Path $f.FullName -Destination $InstallDir -Force
    }
}
else {
    $binDir = Join-Path -Path $repoRoot -ChildPath "src\GUI\WinRepairKit.App\bin\Release\net8.0-windows"
    if (Test-Path -LiteralPath $binDir) {
        Copy-Item -Path "$binDir\*" -Destination $InstallDir -Recurse -Force
    }
}

Write-SetupLog "Copying Engine & CLI modules..."
if (Test-Path -LiteralPath $engineSrcDir) {
    Copy-Item -Path "$engineSrcDir\*" -Destination $targetEngineDir -Recurse -Force
}
if (Test-Path -LiteralPath $cliSrcDir) {
    Copy-Item -Path "$cliSrcDir\*" -Destination $targetCliDir -Recurse -Force
}

# Copy uninstaller
Copy-Item -Path (Join-Path -Path $scriptDir -ChildPath "Uninstall-WinRepairKit.ps1") -Destination $InstallDir -Force -ErrorAction SilentlyContinue

# 5. Create winrepair.cmd CLI Shim in InstallDir
$shimCmd = Join-Path -Path $InstallDir -ChildPath "winrepair.cmd"
$shimContent = @"
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CLI\winrepair.ps1" %*
"@
Set-Content -Path $shimCmd -Value $shimContent -Force

# 6. Add to PATH
if ($AddToPath) {
    Write-SetupLog "Adding WinRepairKit to PATH..."
    $pathTarget = if ($isElevated) { "Machine" } else { "User" }
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", $pathTarget)
    $paths = if ($currentPath) { $currentPath -split ';' | Where-Object { $_ } } else { @() }

    if ($paths -notcontains $InstallDir) {
        $newPath = ($paths + $InstallDir) -join ';'
        [Environment]::SetEnvironmentVariable("PATH", $newPath, $pathTarget)
        $env:PATH = "$env:PATH;$InstallDir"
        Write-SetupLog "PATH updated ($pathTarget environment)." -Color 'Green'
    }
}

# 7. Create Shortcuts (Start Menu & Desktop)
$exePath = Join-Path -Path $InstallDir -ChildPath "WinRepairKit.exe"
$wsh = New-Object -ComObject WScript.Shell

if ($CreateStartMenuShortcut) {
    try {
        $startMenuDir = if ($isElevated) { [Environment]::GetFolderPath('CommonStartMenu') } else { [Environment]::GetFolderPath('StartMenu') }
        $programsDir = Join-Path -Path $startMenuDir -ChildPath "Programs\WinRepairKit"
        if (-not (Test-Path -LiteralPath $programsDir)) {
            New-Item -ItemType Directory -Path $programsDir -Force | Out-Null
        }

        $shortcutPath = Join-Path -Path $programsDir -ChildPath "WinRepairKit.lnk"
        $shortcut = $wsh.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $exePath
        $shortcut.WorkingDirectory = $InstallDir
        $shortcut.Description = "Windows 10 & 11 Repair and Maintenance Toolkit"
        $shortcut.Save()
        Write-SetupLog "Start Menu shortcut created: $shortcutPath" -Color 'Green'
    }
    catch {}
}

if ($CreateDesktopShortcut) {
    try {
        $desktopDir = [Environment]::GetFolderPath('Desktop')
        $desktopShortcutPath = Join-Path -Path $desktopDir -ChildPath "WinRepairKit.lnk"
        $dShortcut = $wsh.CreateShortcut($desktopShortcutPath)
        $dShortcut.TargetPath = $exePath
        $dShortcut.WorkingDirectory = $InstallDir
        $dShortcut.Description = "Windows 10 & 11 Repair and Maintenance Toolkit"
        $dShortcut.Save()
        Write-SetupLog "Desktop shortcut created." -Color 'Green'
    }
    catch {}
}

# 8. Register in Windows Programs & Features (Add/Remove Programs)
try {
    $regRoot = if ($isElevated) { "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\WinRepairKit" } else { "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\WinRepairKit" }
    if (-not (Test-Path -LiteralPath $regRoot)) {
        New-Item -Path $regRoot -Force | Out-Null
    }

    Set-ItemProperty -Path $regRoot -Name "DisplayName" -Value "WinRepairKit"
    Set-ItemProperty -Path $regRoot -Name "DisplayVersion" -Value "0.1.0"
    Set-ItemProperty -Path $regRoot -Name "Publisher" -Value "WinRepairKit Contributors"
    Set-ItemProperty -Path $regRoot -Name "InstallLocation" -Value $InstallDir
    Set-ItemProperty -Path $regRoot -Name "DisplayIcon" -Value "$exePath,0"
    Set-ItemProperty -Path $regRoot -Name "UninstallString" -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\Uninstall-WinRepairKit.ps1`""
    Set-ItemProperty -Path $regRoot -Name "NoModify" -Value 1
    Set-ItemProperty -Path $regRoot -Name "NoRepair" -Value 1
    Write-SetupLog "Registered in Windows Programs & Features." -Color 'Green'
}
catch {}

if (-not $Quiet) {
    Write-Host ""
    Write-Host -ForegroundColor Green "==============================================================================="
    Write-Host -ForegroundColor Green "  Installation Completed Successfully!"
    Write-Host -ForegroundColor Green "  Executable : $exePath"
    Write-Host -ForegroundColor Green "  CLI Command: winrepair scan"
    Write-Host -ForegroundColor Green "==============================================================================="
    Write-Host ""
}
