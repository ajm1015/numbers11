#Requires -Version 5.1
<#
.SYNOPSIS
    Template for Win32 app requirements/pre-requisite checks
.DESCRIPTION
    Optional requirements script template for Intune Win32 app deployments.
    Checks for prerequisites before installation (OS version, PowerShell version, etc.).
    Exit code 0 = requirements met, Exit code 1 = requirements not met.
.NOTES
    Author: 
    Version: 1.0
    Date: 
    
    Modify the following checks as needed:
    - OS version requirements
    - PowerShell version requirements
    - Disk space requirements
    - Other prerequisites
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [version]$MinOSVersion = [version]"10.0.19041",  # Windows 10 2004 or later
    
    [Parameter(Mandatory = $false)]
    [version]$MinPSVersion = [version]"5.1",
    
    [Parameter(Mandatory = $false)]
    [long]$RequiredDiskSpaceMB = 500,  # Required free space in MB
    
    [Parameter(Mandatory = $false)]
    [string]$RequiredDrive = "C:"
)

$ErrorActionPreference = 'Stop'
$AppName = "ApplicationName"
$RequirementsMet = $true
$Failures = @()

# Function to write log entry
function Write-LogEntry {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Write-Verbose $LogMessage
}

try {
    Write-LogEntry "Checking requirements for $AppName"
    
    # Check OS version
    if ($MinOSVersion) {
        $OSVersion = [version](Get-CimInstance Win32_OperatingSystem).Version
        if ($OSVersion -lt $MinOSVersion) {
            $Failures += "OS version $OSVersion is below required $MinOSVersion"
            $RequirementsMet = $false
        }
        else {
            Write-LogEntry "OS version check passed: $OSVersion"
        }
    }
    
    # Check PowerShell version
    if ($MinPSVersion) {
        $PSVersion = $PSVersionTable.PSVersion
        if ($PSVersion -lt $MinPSVersion) {
            $Failures += "PowerShell version $PSVersion is below required $MinPSVersion"
            $RequirementsMet = $false
        }
        else {
            Write-LogEntry "PowerShell version check passed: $PSVersion"
        }
    }
    
    # Check disk space
    if ($RequiredDiskSpaceMB) {
        $Drive = Get-PSDrive -Name $RequiredDrive.TrimEnd(':') -ErrorAction SilentlyContinue
        if ($Drive) {
            $FreeSpaceMB = [math]::Round($Drive.Free / 1MB, 2)
            if ($FreeSpaceMB -lt $RequiredDiskSpaceMB) {
                $Failures += "Insufficient disk space on $RequiredDrive. Required: $RequiredDiskSpaceMB MB, Available: $FreeSpaceMB MB"
                $RequirementsMet = $false
            }
            else {
                Write-LogEntry "Disk space check passed: $FreeSpaceMB MB available on $RequiredDrive"
            }
        }
        else {
            $Failures += "Drive $RequiredDrive not found"
            $RequirementsMet = $false
        }
    }
    
    # Add custom requirement checks here
    # Example: Check for specific Windows features
    # $Feature = Get-WindowsOptionalFeature -Online -FeatureName "FeatureName" -ErrorAction SilentlyContinue
    # if ($Feature.State -ne "Enabled") {
    #     $Failures += "Required Windows feature 'FeatureName' is not enabled"
    #     $RequirementsMet = $false
    # }
    
    # Example: Check for specific software
    # $RequiredApp = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
    #                Where-Object { $_.DisplayName -like "*RequiredApp*" }
    # if (-not $RequiredApp) {
    #     $Failures += "Required application 'RequiredApp' is not installed"
    #     $RequirementsMet = $false
    # }
    
    if ($RequirementsMet) {
        Write-LogEntry "All requirements met for $AppName"
        exit 0
    }
    else {
        Write-LogEntry "Requirements not met. Failures: $($Failures -join '; ')" -Level "ERROR"
        Write-Error "Requirements check failed: $($Failures -join '; ')"
        exit 1
    }
}
catch {
    Write-LogEntry "Requirements check error: $_" -Level "ERROR"
    Write-Error "Requirements check failed: $_"
    exit 1
}
