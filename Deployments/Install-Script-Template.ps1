#Requires -Version 5.1
<#
.SYNOPSIS
    Template for Win32 app installation scripts
.DESCRIPTION
    Standard installation script template for Intune Win32 app deployments.
    Handles silent installation, logging, error handling, and exit codes.
.NOTES
    Author: 
    Version: 1.0
    Date: 
    
    Modify the following variables:
    - $AppName: Application name
    - $InstallerPath: Path to installer executable
    - $InstallerArguments: Silent install arguments
    - $LogPath: Log file location
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$InstallerPath = "$PSScriptRoot\Source\installer.exe",
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "$env:ProgramData\Logs\AppName_Install.log"
)

# Set error handling
$ErrorActionPreference = 'Stop'

# Application configuration
$AppName = "ApplicationName"
$InstallerArguments = "/S /L=$LogPath"  # Modify based on installer type

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
    
    # Stop any running processes that might interfere
    # Uncomment and modify as needed:
    # $ProcessesToKill = @('app', 'apphelper', 'appservice')
    # foreach ($Proc in $ProcessesToKill) {
    #     Get-Process -Name $Proc -ErrorAction SilentlyContinue | Stop-Process -Force
    #     Write-LogEntry "Stopped process: $Proc"
    # }
    
    # Run installer
    $Process = Start-Process -FilePath $InstallerPath -ArgumentList $InstallerArguments -Wait -NoNewWindow -PassThru
    
    # Check exit code
    if ($Process.ExitCode -eq 0) {
        Write-LogEntry "Installation completed successfully"
        exit 0
    }
    elseif ($Process.ExitCode -eq 3010) {
        Write-LogEntry "Installation completed successfully, reboot required"
        exit 3010
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
