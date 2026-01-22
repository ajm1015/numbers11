#Requires -Version 5.1
<#
.SYNOPSIS
    Helper script to package DotNetRuntime for Intune using IntuneWinAppUtil
.DESCRIPTION
    Automates the packaging process for Intune Win32 app deployment.
    This script will locate IntuneWinAppUtil and package your deployment.
.NOTES
    Author: 
    Version: 1.0
    Date: 
    
    Prerequisites:
    - IntuneWinAppUtil.exe must be available
    - Installer must be in Source/ folder
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$IntuneWinAppUtilPath,
    
    [Parameter(Mandatory = $false)]
    [string]$PackagePath = $PSScriptRoot,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "$PSScriptRoot\Output"
)

$ErrorActionPreference = 'Stop'

# Application configuration
$AppName = "DotNetRuntime"
$InstallerName = "windowsdesktop-runtime-8.0.23-win-x64.exe"
$SourceFolder = "$PackagePath\Source"
$SetupFile = "$SourceFolder\$InstallerName"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Intune Win32 App Packaging Helper" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if installer exists
Write-Host "Checking installer..." -ForegroundColor Yellow
if (-not (Test-Path $SetupFile)) {
    Write-Error "Installer not found at: $SetupFile"
    Write-Host "Please ensure the installer is in the Source/ folder." -ForegroundColor Red
    exit 1
}
Write-Host "✓ Installer found: $InstallerName" -ForegroundColor Green
Write-Host ""

# Find IntuneWinAppUtil
Write-Host "Locating IntuneWinAppUtil..." -ForegroundColor Yellow
if ($IntuneWinAppUtilPath) {
    if (-not (Test-Path $IntuneWinAppUtilPath)) {
        Write-Error "IntuneWinAppUtil not found at: $IntuneWinAppUtilPath"
        exit 1
    }
    $IntuneWinAppUtil = $IntuneWinAppUtilPath
}
else {
    # Try common locations
    $CommonPaths = @(
        "$env:ProgramFiles\IntuneWinAppUtil\IntuneWinAppUtil.exe",
        "$env:ProgramFiles(x86)\IntuneWinAppUtil\IntuneWinAppUtil.exe",
        "C:\Tools\IntuneWinAppUtil\IntuneWinAppUtil.exe",
        "$env:USERPROFILE\Downloads\IntuneWinAppUtil.exe",
        "$PSScriptRoot\IntuneWinAppUtil.exe"
    )
    
    $IntuneWinAppUtil = $null
    foreach ($Path in $CommonPaths) {
        if (Test-Path $Path) {
            $IntuneWinAppUtil = $Path
            break
        }
    }
    
    if (-not $IntuneWinAppUtil) {
        Write-Host "IntuneWinAppUtil not found in common locations." -ForegroundColor Red
        Write-Host ""
        Write-Host "Please download it from:" -ForegroundColor Yellow
        Write-Host "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Then either:" -ForegroundColor Yellow
        Write-Host "1. Place it in one of these locations:" -ForegroundColor White
        foreach ($Path in $CommonPaths) {
            Write-Host "   - $Path" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "2. Or run this script with -IntuneWinAppUtilPath parameter:" -ForegroundColor White
        Write-Host "   .\Package-IntuneApp.ps1 -IntuneWinAppUtilPath `"C:\Path\To\IntuneWinAppUtil.exe`"" -ForegroundColor Gray
        exit 1
    }
}

Write-Host "✓ IntuneWinAppUtil found: $IntuneWinAppUtil" -ForegroundColor Green
Write-Host ""

# Create output folder
Write-Host "Preparing output folder..." -ForegroundColor Yellow
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    Write-Host "✓ Created output folder: $OutputPath" -ForegroundColor Green
}
else {
    Write-Host "✓ Output folder exists: $OutputPath" -ForegroundColor Green
}
Write-Host ""

# Display configuration
Write-Host "Packaging Configuration:" -ForegroundColor Cyan
Write-Host "  Package Name:     $AppName" -ForegroundColor White
Write-Host "  Source Folder:    $PackagePath" -ForegroundColor White
Write-Host "  Setup File:       $SetupFile" -ForegroundColor White
Write-Host "  Output Folder:    $OutputPath" -ForegroundColor White
Write-Host ""

# Confirm before proceeding
$Confirm = Read-Host "Proceed with packaging? (Y/N)"
if ($Confirm -ne 'Y' -and $Confirm -ne 'y') {
    Write-Host "Packaging cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Starting packaging..." -ForegroundColor Yellow
Write-Host ""

# Run IntuneWinAppUtil
try {
    $Arguments = @(
        "-c", "`"$PackagePath`"",
        "-s", "`"$SourceFolder`"",
        "-o", "`"$OutputPath`"",
        "-q"
    )
    
    Write-Host "Running: $IntuneWinAppUtil $($Arguments -join ' ')" -ForegroundColor Gray
    Write-Host ""
    
    $Process = Start-Process -FilePath $IntuneWinAppUtil -ArgumentList $Arguments -Wait -NoNewWindow -PassThru
    
    if ($Process.ExitCode -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Packaging completed successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        
        $IntuneWinFile = Get-ChildItem -Path $OutputPath -Filter "*.intunewin" | Select-Object -First 1
        if ($IntuneWinFile) {
            Write-Host "Package created: $($IntuneWinFile.FullName)" -ForegroundColor Cyan
            Write-Host "File size: $([math]::Round($IntuneWinFile.Length / 1MB, 2)) MB" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Yellow
            Write-Host "1. Upload $($IntuneWinFile.Name) to Intune" -ForegroundColor White
            Write-Host "2. Use these settings:" -ForegroundColor White
            Write-Host "   Install:   powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1" -ForegroundColor Gray
            Write-Host "   Uninstall: powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1" -ForegroundColor Gray
            Write-Host "   Detection: Upload Detection.ps1" -ForegroundColor Gray
        }
        exit 0
    }
    else {
        Write-Host ""
        Write-Host "Packaging failed with exit code: $($Process.ExitCode)" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "Error during packaging: $_" -ForegroundColor Red
    exit 1
}
