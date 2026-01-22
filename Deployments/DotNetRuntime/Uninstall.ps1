#Requires -Version 5.1
<#
.SYNOPSIS
    Uninstall Microsoft .NET Runtime
.DESCRIPTION
    Uninstalls Microsoft .NET Runtime silently for Intune Win32 app deployment.
    Handles silent uninstallation, logging, error handling, and exit codes.
.NOTES
    Author: 
    Version: 1.0
    Date: 
    
    This script will attempt to find and use the .NET Runtime uninstaller from registry.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "$env:ProgramData\Logs\DotNetRuntime_Uninstall.log"
)

# Set error handling
$ErrorActionPreference = 'Stop'

# Application configuration
$AppName = "Microsoft .NET Windows Desktop Runtime"
$AppDisplayNamePattern = "*Microsoft Windows Desktop Runtime*"

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
    
    # Find .NET Runtime in registry
    $RegPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $DotNetApps = Get-ItemProperty -Path $RegPaths -ErrorAction SilentlyContinue | 
                  Where-Object { 
                      $_.DisplayName -like $AppDisplayNamePattern -or
                      $_.DisplayName -like "*Microsoft .NET Desktop Runtime*" -or
                      $_.DisplayName -like "*Windows Desktop Runtime 8.0*"
                  }
    
    if (-not $DotNetApps) {
        Write-LogEntry ".NET Runtime not found in registry. May already be uninstalled."
        exit 0
    }
    
    Write-LogEntry "Found $($DotNetApps.Count) .NET Runtime installation(s)"
    
    # Uninstall each found .NET Runtime installation
    $SuccessCount = 0
    $FailureCount = 0
    
    foreach ($App in $DotNetApps) {
        $DisplayName = $App.DisplayName
        Write-LogEntry "Processing: $DisplayName"
        
        $UninstallerPath = $null
        $UninstallerArguments = $null
        
        if ($App.UninstallString) {
            # Extract uninstaller path and arguments
            $UninstallString = $App.UninstallString.Trim()
            
            if ($UninstallString -match '^"([^"]+)"\s*(.*)$') {
                # Quoted path with arguments
                $UninstallerPath = $Matches[1]
                $UninstallerArguments = $Matches[2]
            }
            elseif ($UninstallString -match '^(\S+)\s+(.*)$') {
                # Unquoted path with arguments
                $UninstallerPath = $Matches[1]
                $UninstallerArguments = $Matches[2]
            }
            else {
                # Just the path
                $UninstallerPath = $UninstallString
            }
            
            # Add silent arguments if not already present
            if ($UninstallerArguments -notmatch '/quiet|/q|/silent') {
                $UninstallerArguments = "/quiet /norestart $UninstallerArguments"
            }
        }
        elseif ($App.PSChildName) {
            # MSI GUID found
            $UninstallerPath = "msiexec.exe"
            $UninstallerArguments = "/x $($App.PSChildName) /qn /norestart /L*v `"$LogPath`""
        }
        
        if ($UninstallerPath) {
            Write-LogEntry "Uninstaller: $UninstallerPath $UninstallerArguments"
            
            # Verify uninstaller exists (skip check for msiexec.exe)
            if ($UninstallerPath -ne "msiexec.exe" -and -not (Test-Path $UninstallerPath)) {
                Write-LogEntry "Uninstaller not found at: $UninstallerPath" -Level "ERROR"
                $FailureCount++
                continue
            }
            
            # Run uninstaller
            try {
                $Process = Start-Process -FilePath $UninstallerPath -ArgumentList $UninstallerArguments -Wait -NoNewWindow -PassThru
                
                if ($Process.ExitCode -eq 0) {
                    Write-LogEntry "Successfully uninstalled: $DisplayName"
                    $SuccessCount++
                }
                elseif ($Process.ExitCode -eq 3010) {
                    Write-LogEntry "Successfully uninstalled: $DisplayName (reboot required)"
                    $SuccessCount++
                }
                else {
                    Write-LogEntry "Uninstall failed for $DisplayName with exit code: $($Process.ExitCode)" -Level "ERROR"
                    $FailureCount++
                }
            }
            catch {
                Write-LogEntry "Error uninstalling $DisplayName : $_" -Level "ERROR"
                $FailureCount++
            }
        }
        else {
            Write-LogEntry "Could not determine uninstaller for: $DisplayName" -Level "ERROR"
            $FailureCount++
        }
    }
    
    if ($FailureCount -eq 0) {
        Write-LogEntry "All .NET Runtime installations uninstalled successfully (Count: $SuccessCount)"
        exit 0
    }
    elseif ($SuccessCount -gt 0) {
        Write-LogEntry "Partial success: $SuccessCount succeeded, $FailureCount failed" -Level "WARNING"
        exit 0  # Partial success still exits 0 to avoid blocking
    }
    else {
        throw "Failed to uninstall .NET Runtime. All attempts failed."
    }
}
catch {
    Write-LogEntry "Uninstallation failed: $_" -Level "ERROR"
    Write-Error "Failed to uninstall $AppName : $_"
    exit 1
}
