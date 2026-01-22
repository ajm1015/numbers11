#Requires -Version 5.1
<#
.SYNOPSIS
    Template for compliance and audit scripts
.DESCRIPTION
    Standard audit script template for compliance checking and reporting.
    Returns structured objects for easy reporting and export to CSV/JSON.
.NOTES
    Author: 
    Version: 1.0
    Date: 
    
    Modify the audit checks as needed for your compliance requirements.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("CSV", "JSON", "Console")]
    [string]$OutputFormat = "Console"
)

$ErrorActionPreference = 'Stop'

# Function to create audit result object
function New-AuditResult {
    param (
        [string]$CheckName,
        [string]$Status,  # "Compliant", "Non-Compliant", "Error", "Warning"
        [string]$Details,
        [object]$AdditionalData = $null
    )
    
    return [PSCustomObject]@{
        ComputerName  = $env:COMPUTERNAME
        CheckName     = $CheckName
        Status        = $Status
        Details       = $Details
        Timestamp     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        AdditionalData = $AdditionalData
    }
}

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
    Write-LogEntry "Starting compliance audit"
    $AuditResults = @()
    
    # Example Audit Check 1: BitLocker Status
    Write-LogEntry "Checking BitLocker status"
    try {
        $BitLocker = Get-BitLockerVolume -ErrorAction SilentlyContinue | Where-Object { $_.VolumeType -eq "OperatingSystem" }
        if ($BitLocker -and $BitLocker.VolumeStatus -eq "FullyEncrypted") {
            $AuditResults += New-AuditResult -CheckName "BitLocker Status" -Status "Compliant" -Details "C: drive is encrypted"
        }
        else {
            $AuditResults += New-AuditResult -CheckName "BitLocker Status" -Status "Non-Compliant" -Details "C: drive is not fully encrypted"
        }
    }
    catch {
        $AuditResults += New-AuditResult -CheckName "BitLocker Status" -Status "Error" -Details "Unable to check BitLocker: $_"
    }
    
    # Example Audit Check 2: Windows Update Status
    Write-LogEntry "Checking Windows Update status"
    try {
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        $SearchResult = $UpdateSearcher.Search("IsInstalled=0")
        
        if ($SearchResult.Updates.Count -eq 0) {
            $AuditResults += New-AuditResult -CheckName "Windows Updates" -Status "Compliant" -Details "No pending updates"
        }
        else {
            $AuditResults += New-AuditResult -CheckName "Windows Updates" -Status "Non-Compliant" -Details "$($SearchResult.Updates.Count) pending updates"
        }
    }
    catch {
        $AuditResults += New-AuditResult -CheckName "Windows Updates" -Status "Error" -Details "Unable to check updates: $_"
    }
    
    # Example Audit Check 3: Local Administrator Accounts
    Write-LogEntry "Checking local administrator accounts"
    try {
        $LocalAdmins = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop
        $AdminCount = ($LocalAdmins | Where-Object { $_.PrincipalSource -eq "Local" }).Count
        
        if ($AdminCount -le 1) {
            $AuditResults += New-AuditResult -CheckName "Local Administrators" -Status "Compliant" -Details "Only standard local admin account exists"
        }
        else {
            $AdminNames = ($LocalAdmins | Where-Object { $_.PrincipalSource -eq "Local" }).Name -join ", "
            $AuditResults += New-AuditResult -CheckName "Local Administrators" -Status "Non-Compliant" -Details "Multiple local admin accounts: $AdminNames"
        }
    }
    catch {
        $AuditResults += New-AuditResult -CheckName "Local Administrators" -Status "Error" -Details "Unable to check local admins: $_"
    }
    
    # Example Audit Check 4: Firewall Status
    Write-LogEntry "Checking Windows Firewall status"
    try {
        $FirewallProfiles = Get-NetFirewallProfile -ErrorAction Stop
        $AllEnabled = $true
        $DisabledProfiles = @()
        
        foreach ($Profile in $FirewallProfiles) {
            if ($Profile.Enabled -eq $false) {
                $AllEnabled = $false
                $DisabledProfiles += $Profile.Name
            }
        }
        
        if ($AllEnabled) {
            $AuditResults += New-AuditResult -CheckName "Windows Firewall" -Status "Compliant" -Details "All firewall profiles enabled"
        }
        else {
            $AuditResults += New-AuditResult -CheckName "Windows Firewall" -Status "Non-Compliant" -Details "Disabled profiles: $($DisabledProfiles -join ', ')"
        }
    }
    catch {
        $AuditResults += New-AuditResult -CheckName "Windows Firewall" -Status "Error" -Details "Unable to check firewall: $_"
    }
    
    # Add more audit checks here as needed
    # Example: Check for specific software versions
    # Example: Check registry settings
    # Example: Check service status
    # Example: Check group policy compliance
    
    # Output results
    Write-LogEntry "Audit completed. Total checks: $($AuditResults.Count)"
    
    switch ($OutputFormat) {
        "CSV" {
            if ($OutputPath) {
                $AuditResults | Export-Csv -Path $OutputPath -NoTypeInformation
                Write-LogEntry "Results exported to CSV: $OutputPath"
            }
            else {
                $AuditResults | ConvertTo-Csv -NoTypeInformation
            }
        }
        "JSON" {
            if ($OutputPath) {
                $AuditResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath
                Write-LogEntry "Results exported to JSON: $OutputPath"
            }
            else {
                $AuditResults | ConvertTo-Json -Depth 3
            }
        }
        "Console" {
            $AuditResults | Format-Table -AutoSize
        }
    }
    
    # Return summary
    $CompliantCount = ($AuditResults | Where-Object { $_.Status -eq "Compliant" }).Count
    $NonCompliantCount = ($AuditResults | Where-Object { $_.Status -eq "Non-Compliant" }).Count
    $ErrorCount = ($AuditResults | Where-Object { $_.Status -eq "Error" }).Count
    
    Write-LogEntry "Summary - Compliant: $CompliantCount, Non-Compliant: $NonCompliantCount, Errors: $ErrorCount"
    
    # Exit with error code if any non-compliant items found
    if ($NonCompliantCount -gt 0) {
        exit 1
    }
    else {
        exit 0
    }
}
catch {
    Write-Error "Audit script error: $_"
    exit 1
}
