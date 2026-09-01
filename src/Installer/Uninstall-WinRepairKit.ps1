# WinRepairKit - Clean Uninstaller Script
# Removes shortcuts, PATH registrations, installation files, and registry entries.

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$PurgeData,

    [Parameter()]
    [switch]$Quiet
)

$ErrorActionPreference = 'SilentlyContinue'

function Write-UninstallLog {
    param([string]$Message, [string]$Color = 'Cyan')
    if (-not $Quiet) {
        Write-Host -ForegroundColor $Color "  [Uninstall] $Message"
    }
}

Write-Host -ForegroundColor Cyan @"
===============================================================================
  WinRepairKit — Uninstaller
===============================================================================
"@

$isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$installDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

Write-UninstallLog "Removing WinRepairKit from $installDir..."

# 1. Remove Shortcuts
$startMenuDir = if ($isElevated) { [Environment]::GetFolderPath('CommonStartMenu') } else { [Environment]::GetFolderPath('StartMenu') }
$programsDir = Join-Path -Path $startMenuDir -ChildPath "Programs\WinRepairKit"
if (Test-Path -LiteralPath $programsDir) {
    Remove-Item -LiteralPath $programsDir -Recurse -Force
    Write-UninstallLog "Removed Start Menu shortcuts." -Color 'Green'
}

$desktopDir = [Environment]::GetFolderPath('Desktop')
$desktopShortcut = Join-Path -Path $desktopDir -ChildPath "WinRepairKit.lnk"
if (Test-Path -LiteralPath $desktopShortcut) {
    Remove-Item -LiteralPath $desktopShortcut -Force
    Write-UninstallLog "Removed Desktop shortcut." -Color 'Green'
}

# 2. Remove PATH Entry
$pathTarget = if ($isElevated) { "Machine" } else { "User" }
$currentPath = [Environment]::GetEnvironmentVariable("PATH", $pathTarget)
if ($currentPath) {
    $paths = $currentPath -split ';' | Where-Object { $_ -and $_ -ne $installDir }
    $newPath = $paths -join ';'
    [Environment]::SetEnvironmentVariable("PATH", $newPath, $pathTarget)
    Write-UninstallLog "Removed from PATH ($pathTarget)." -Color 'Green'
}

# 3. Remove Registry Entry
$regRoot = if ($isElevated) { "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\WinRepairKit" } else { "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\WinRepairKit" }
if (Test-Path -LiteralPath $regRoot) {
    Remove-Item -Path $regRoot -Recurse -Force
    Write-UninstallLog "Removed Windows Programs & Features entry." -Color 'Green'
}

# 4. Optional Data Purge
if ($PurgeData) {
    $dataDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "WinRepairKit"
    if (Test-Path -LiteralPath $dataDir) {
        Remove-Item -LiteralPath $dataDir -Recurse -Force
        Write-UninstallLog "Purged logs, snapshots, and transactions." -Color 'Yellow'
    }
}

# 5. Remove Installation Files (via deferred command if running from within installDir)
Write-UninstallLog "Cleaning up installation files..."
Start-Process -FilePath "cmd.exe" -ArgumentList "/c timeout /t 2 & rmdir /s /q `"$installDir`"" -WindowStyle Hidden

Write-Host -ForegroundColor Green "==============================================================================="
Write-Host -ForegroundColor Green "  WinRepairKit was uninstalled cleanly."
Write-Host -ForegroundColor Green "==============================================================================="
Write-Host ""
