#Requires -Version 5.1
<#
.SYNOPSIS
    Install Microsoft .NET Runtime
.DESCRIPTION
    Installs Microsoft .NET Runtime silently for Intune Win32 app deployment.
    Handles silent installation, logging, error handling, and exit codes.
.NOTES
    Author: 
    Version: 1.0
    Date: 
    
    Installer should be placed in: $PSScriptRoot\Source\
    Modify $InstallerFileName if your installer has a different name.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$InstallerPath = "$PSScriptRoot\Source\windowsdesktop-runtime-8.0.23-win-x64.exe",
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "$env:ProgramData\Logs\DotNetRuntime_Install.log"
)

# Set error handling
$ErrorActionPreference = 'Stop'

# Application configuration
$AppName = "Microsoft .NET Windows Desktop Runtime 8.0.23"
# Installer: windowsdesktop-runtime-8.0.23-win-x64.exe

# Microsoft .NET Runtime installer silent arguments
# /install - Install the runtime
# /quiet - Silent installation (no UI)
# /norestart - Suppress automatic reboot
$InstallerArguments = "/install /quiet /norestart"

# Check if running as SYSTEM
$IsSystem = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq 'S-1-5-18'

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
    Write-LogEntry "Starting installation of $AppName"
    
    # Verify installer exists
    if (-not (Test-Path $InstallerPath)) {
        throw "Installer not found at: $InstallerPath"
    }
    
    Write-LogEntry "Installer found: $InstallerPath"
    Write-LogEntry "Running installer with arguments: $InstallerArguments"
    
    # Check if .NET Runtime is already installed (optional - installer handles this)
    # Uncomment to add pre-check logic:
    # try {
    #     $DotNetVersion = dotnet --version 2>&1
    #     if ($DotNetVersion) {
    #         Write-LogEntry ".NET Runtime already installed: $DotNetVersion"
    #     }
    # } catch {
    #     Write-LogEntry ".NET Runtime not detected, proceeding with installation"
    # }
    
    # Run installer
    Write-LogEntry "Executing installer..."
    $Process = Start-Process -FilePath $InstallerPath -ArgumentList $InstallerArguments -Wait -NoNewWindow -PassThru
    
    Write-LogEntry "Installer completed with exit code: $($Process.ExitCode)"
    
    # Check exit code
    # .NET Runtime installer exit codes:
    # 0 = Success
    # 3010 = Success with reboot required
    # 1603 = Fatal error during installation
    # Other non-zero = Error
    if ($Process.ExitCode -eq 0) {
        Write-LogEntry "Installation completed successfully"
        
        # Verify installation (optional)
        Start-Sleep -Seconds 2
        try {
            $DotNetCheck = dotnet --version 2>&1
            if ($DotNetCheck) {
                Write-LogEntry "Verified .NET Runtime installation: $DotNetCheck"
            }
        } catch {
            Write-LogEntry "Note: Could not verify .NET Runtime via 'dotnet --version' command"
        }
        
        exit 0
    }
    elseif ($Process.ExitCode -eq 3010) {
        Write-LogEntry "Installation completed successfully, reboot required"
        exit 3010
    }
    elseif ($Process.ExitCode -eq 1603) {
        Write-LogEntry "Installation failed with fatal error (exit code 1603)" -Level "ERROR"
        throw "Fatal error during installation. Check Windows Event Log for details."
    }
    else {
        throw "Installation failed with exit code: $($Process.ExitCode)"
    }
}
catch {
    Write-LogEntry "Installation failed: $_" -Level "ERROR"
    Write-Error "Failed to install $AppName : $_"
    exit 1
}
