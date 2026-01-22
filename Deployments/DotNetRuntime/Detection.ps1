#Requires -Version 5.1
<#
.SYNOPSIS
    Detection script for Microsoft .NET Runtime
.DESCRIPTION
    Detects if Microsoft .NET Runtime is installed via registry and/or dotnet command.
    Returns output for detected runtime, nothing for not detected.
    Exit code 0 = detected, Exit code 1 = not detected.
.NOTES
    Author: 
    Version: 1.0
    Date: 
    
    Modify $MinVersion if you need a specific minimum version requirement.
    Detection checks both registry and dotnet --version command.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [version]$MinVersion = [version]"8.0.23",  # Windows Desktop Runtime 8.0.23
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Registry", "Command", "Both")]
    [string]$DetectionMethod = "Both"
)

$ErrorActionPreference = 'Stop'
$AppName = "Microsoft .NET Windows Desktop Runtime"

# Function to check registry-based detection
function Test-RegistryDetection {
    $RegPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $DotNetApps = Get-ItemProperty -Path $RegPaths -ErrorAction SilentlyContinue | 
                  Where-Object { 
                      $_.DisplayName -like "*Microsoft Windows Desktop Runtime*" -or
                      $_.DisplayName -like "*Microsoft .NET Desktop Runtime*" -or
                      $_.DisplayName -like "*Windows Desktop Runtime 8.0*"
                  }
    
    if ($DotNetApps) {
        foreach ($App in $DotNetApps) {
            if ($App.DisplayVersion) {
                try {
                    $RegVersion = [version]$App.DisplayVersion
                    if ($RegVersion -ge $MinVersion) {
                        Write-Output "Detected: $($App.DisplayName) version $RegVersion (Registry)"
                        return $true
                    }
                    else {
                        Write-Verbose "Registry found but version $RegVersion is below minimum required $MinVersion"
                    }
                }
                catch {
                    Write-Verbose "Could not parse version from registry: $($App.DisplayVersion)"
                    # If version parsing fails but app is found, consider it detected
                    Write-Output "Detected: $($App.DisplayName) (Registry - version not parseable)"
                    return $true
                }
            }
            else {
                # App found but no version - still detected
                Write-Output "Detected: $($App.DisplayName) (Registry - no version info)"
                return $true
            }
        }
    }
    return $false
}

# Function to check command-based detection (dotnet --version)
function Test-CommandDetection {
    try {
        # Check if dotnet.exe exists in common locations
        $DotNetPaths = @(
            "$env:ProgramFiles\dotnet\dotnet.exe",
            "${env:ProgramFiles(x86)}\dotnet\dotnet.exe"
        )
        
        $DotNetExe = $null
        foreach ($Path in $DotNetPaths) {
            if (Test-Path $Path) {
                $DotNetExe = $Path
                break
            }
        }
        
        if ($DotNetExe) {
            # Run dotnet --version
            $DotNetVersion = & $DotNetExe --version 2>&1
            
            if ($DotNetVersion -and $DotNetVersion -match '^\d+\.\d+\.\d+') {
                $Version = [version]$DotNetVersion
                if ($Version -ge $MinVersion) {
                    Write-Output "Detected: $AppName version $DotNetVersion (Command: $DotNetExe)"
                    return $true
                }
                else {
                    Write-Verbose "Command found but version $DotNetVersion is below minimum required $MinVersion"
                }
            }
        }
        
        # Alternative: Try from PATH
        try {
            $DotNetVersion = dotnet --version 2>&1
            if ($DotNetVersion -and $DotNetVersion -match '^\d+\.\d+\.\d+') {
                $Version = [version]$DotNetVersion
                if ($Version -ge $MinVersion) {
                    Write-Output "Detected: $AppName version $DotNetVersion (Command: PATH)"
                    return $true
                }
            }
        }
        catch {
            Write-Verbose "dotnet command not available in PATH"
        }
    }
    catch {
        Write-Verbose "Error checking dotnet command: $_"
    }
    return $false
}

try {
    $Detected = $false
    
    switch ($DetectionMethod) {
        "Registry" {
            $Detected = Test-RegistryDetection
        }
        "Command" {
            $Detected = Test-CommandDetection
        }
        "Both" {
            $RegDetected = Test-RegistryDetection
            $CmdDetected = Test-CommandDetection
            $Detected = $RegDetected -or $CmdDetected
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
