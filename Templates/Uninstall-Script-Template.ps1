#Requires -Version 5.1
<#
.SYNOPSIS
    Template for Win32 app uninstallation scripts
.DESCRIPTION
    Standard uninstallation script template for Intune Win32 app deployments.
    Handles silent uninstallation, logging, error handling, and exit codes.
.NOTES
    Author: 
    Version: 1.0
    Date: 
    
    Modify the following variables:
    - $AppName: Application name
    - $UninstallerPath: Path to uninstaller executable or MSI GUID
    - $UninstallerArguments: Silent uninstall arguments
    - $LogPath: Log file location
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$UninstallerPath,
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "$env:ProgramData\Logs\AppName_Uninstall.log"
)

# Set error handling
$ErrorActionPreference = 'Stop'

# Application configuration
$AppName = "ApplicationName"
# Option 1: Direct uninstaller path
# $UninstallerPath = "$env:ProgramFiles\AppName\uninstall.exe"
# $UninstallerArguments = "/S"

# Option 2: MSI uninstall by GUID
# $UninstallerPath = "msiexec.exe"
# $UninstallerArguments = "/x {GUID-HERE} /qn /norestart /L*v `"$LogPath`""

# Option 3: MSI uninstall by product name (if GUID unknown)
# $ProductName = "ApplicationName"
# $UninstallerPath = "msiexec.exe"
# $UninstallerArguments = "/x `"$ProductName`" /qn /norestart /L*v `"$LogPath`""

# Ensure log directory exists
$LogDir = Split-Path -Path $LogPath -Parent
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

# Function to write log entry
function Write-LogEntry {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $LogMessage
    Write-Verbose $LogMessage
}

try {
    Write-LogEntry "Starting uninstallation of $AppName"
    
    # Stop any running processes
    # Uncomment and modify as needed:
    # $ProcessesToKill = @('app', 'apphelper', 'appservice')
    # foreach ($Proc in $ProcessesToKill) {
    #     Get-Process -Name $Proc -ErrorAction SilentlyContinue | Stop-Process -Force
    #     Write-LogEntry "Stopped process: $Proc"
    # }
    
    # If UninstallerPath not provided, try to find it
    if (-not $UninstallerPath) {
        # Try to find uninstaller in registry
        $RegPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        
        $App = Get-ItemProperty -Path $RegPaths -ErrorAction SilentlyContinue | 
               Where-Object { $_.DisplayName -like "*$AppName*" } | 
               Select-Object -First 1
        
        if ($App) {
            if ($App.UninstallString) {
                $UninstallerPath = $App.UninstallString -replace '"', ''
                $UninstallerArguments = "/S"  # Modify as needed
                Write-LogEntry "Found uninstaller in registry: $UninstallerPath"
            }
            elseif ($App.PSChildName) {
                # MSI GUID found
                $UninstallerPath = "msiexec.exe"
                $UninstallerArguments = "/x $($App.PSChildName) /qn /norestart /L*v `"$LogPath`""
                Write-LogEntry "Found MSI GUID: $($App.PSChildName)"
            }
        }
    }
    
    if (-not $UninstallerPath) {
        throw "Uninstaller not found for $AppName"
    }
    
    # Verify uninstaller exists (skip check for msiexec.exe)
    if ($UninstallerPath -ne "msiexec.exe" -and -not (Test-Path $UninstallerPath)) {
        throw "Uninstaller not found at: $UninstallerPath"
    }
    
    Write-LogEntry "Running uninstaller: $UninstallerPath $UninstallerArguments"
    
    # Run uninstaller
    $Process = Start-Process -FilePath $UninstallerPath -ArgumentList $UninstallerArguments -Wait -NoNewWindow -PassThru
    
    # Check exit code
    if ($Process.ExitCode -eq 0) {
        Write-LogEntry "Uninstallation completed successfully"
        exit 0
    }
    elseif ($Process.ExitCode -eq 3010) {
        Write-LogEntry "Uninstallation completed successfully, reboot required"
        exit 3010
    }
    else {
        throw "Uninstallation failed with exit code: $($Process.ExitCode)"
    }
}
catch {
    Write-LogEntry "Uninstallation failed: $_" -Level "ERROR"
    Write-Error "Failed to uninstall $AppName : $_"
    exit 1
}
