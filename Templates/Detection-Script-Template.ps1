#Requires -Version 5.1
<#
.SYNOPSIS
    Template for Win32 app detection scripts
.DESCRIPTION
    Standard detection script template for Intune Win32 app deployments.
    Returns output for detected applications, nothing for not detected.
    Exit code 0 = detected, Exit code 1 = not detected.
.NOTES
    Author: 
    Version: 1.0
    Date: 
    
    Modify the following variables:
    - $AppName: Application name
    - $DetectionMethod: Choose "File", "Registry", or "Both"
    - $AppPath: Path to application executable (for file detection)
    - $MinVersion: Minimum required version
    - $RegPath: Registry path (for registry detection)
    - $RegValue: Registry value name to check
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("File", "Registry", "Both")]
    [string]$DetectionMethod = "File",
    
    [Parameter(Mandatory = $false)]
    [string]$AppPath = "${env:ProgramFiles}\AppName\app.exe",
    
    [Parameter(Mandatory = $false)]
    [version]$MinVersion = [version]"1.0.0",
    
    [Parameter(Mandatory = $false)]
    [string]$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{GUID}",
    
    [Parameter(Mandatory = $false)]
    [string]$RegValue = "DisplayVersion"
)

$ErrorActionPreference = 'Stop'
$AppName = "ApplicationName"

# Function to check file-based detection
function Test-FileDetection {
    if (Test-Path $AppPath) {
        try {
            $FileVersion = [version](Get-Item $AppPath).VersionInfo.FileVersion
            if ($FileVersion -ge $MinVersion) {
                Write-Output "Detected: $AppName version $FileVersion (File: $AppPath)"
                return $true
            }
            else {
                Write-Verbose "File found but version $FileVersion is below minimum required $MinVersion"
                return $false
            }
        }
        catch {
            Write-Verbose "Error reading file version: $_"
            return $false
        }
    }
    return $false
}

# Function to check registry-based detection
function Test-RegistryDetection {
    # Check both 64-bit and 32-bit registry paths
    $RegPaths = @(
        $RegPath,
        $RegPath -replace "SOFTWARE\\", "SOFTWARE\WOW6432Node\"
    )
    
    foreach ($Path in $RegPaths) {
        if (Test-Path $Path) {
            try {
                $RegValueData = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).$RegValue
                if ($RegValueData) {
                    # Try to parse as version if it looks like one
                    if ($RegValueData -match '^\d+\.\d+') {
                        $RegVersion = [version]$RegValueData
                        if ($RegVersion -ge $MinVersion) {
                            Write-Output "Detected: $AppName version $RegVersion (Registry: $Path)"
                            return $true
                        }
                        else {
                            Write-Verbose "Registry found but version $RegVersion is below minimum required $MinVersion"
                        }
                    }
                    else {
                        # Non-version value, just check if it exists
                        Write-Output "Detected: $AppName (Registry: $Path, Value: $RegValueData)"
                        return $true
                    }
                }
            }
            catch {
                Write-Verbose "Error reading registry: $_"
            }
        }
    }
    return $false
}

try {
    $Detected = $false
    
    switch ($DetectionMethod) {
        "File" {
            $Detected = Test-FileDetection
        }
        "Registry" {
            $Detected = Test-RegistryDetection
        }
        "Both" {
            $FileDetected = Test-FileDetection
            $RegDetected = Test-RegistryDetection
            $Detected = $FileDetected -or $RegDetected
        }
    }
    
    if ($Detected) {
        exit 0
    }
    else {
        exit 1
    }
}
catch {
    Write-Error "Detection script error: $_"
    exit 1
}
