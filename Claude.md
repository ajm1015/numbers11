# Claude.md - Windows Deployment & Scripting Context

## Project Overview
Repository for PowerShell scripts, Bash utilities, and Win32 app deployment packages for Windows system management. Focus on clean installations, dependency management, and secure scripting practices for enterprise environments.

## Tech Stack
- **Primary**: PowerShell 5.1 / PowerShell 7+
- **Secondary**: Bash (for cross-platform or macOS/Linux tooling)
- **Deployment**: Intune Win32 apps, SCCM/MECM, or standalone installers
- **Packaging**: IntuneWinAppUtil, PSADT (PowerShell App Deployment Toolkit)

## Project Structure
```
/Deployments      - Win32 app packages (install/uninstall/detection scripts)
/Scripts          - Standalone utility scripts
/Modules          - Reusable PowerShell modules
/Audit            - Compliance and audit scripts
/Templates        - Script templates and boilerplate
```

## PowerShell Conventions

### Script Structure
Every script should include:
```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    Brief description
.DESCRIPTION
    Detailed description
.NOTES
    Author: 
    Version: 1.0
    Date: 
#>
[CmdletBinding()]
param (
    # Parameters here
)

# Script body
```

### Naming
- Scripts: `Verb-Noun.ps1` (e.g., `Install-Application.ps1`, `Remove-LegacySoftware.ps1`)
- Functions: PascalCase with approved verbs (`Get-`, `Set-`, `Install-`, `Remove-`)
- Variables: `$PascalCase` for script-level, `$camelCase` for local
- Constants: `$UPPER_SNAKE_CASE`

### Error Handling
```powershell
$ErrorActionPreference = 'Stop'
try {
    # Operations
} catch {
    Write-Error "Failed: $_"
    exit 1
}
```

### Logging
- Use `Write-Verbose` for detailed output
- Use `Write-Output` for standard messages
- Log to file when running as SYSTEM: `$env:ProgramData\Logs\ScriptName.log`
- Include timestamps in logs

### Exit Codes
- `0` = Success
- `1` = General failure
- `3010` = Success, reboot required
- Use meaningful exit codes for Intune detection

## Win32 App Deployment Pattern

### Standard Package Structure
```
/AppName_v1.0/
├── Source/
│   └── installer.exe (or .msi)
├── Install.ps1
├── Uninstall.ps1
├── Detection.ps1
├── Requirements.ps1 (optional)
└── README.md
```

### Install Script Template
```powershell
# Run silently, log output, handle reboots
$InstallerPath = "$PSScriptRoot\Source\installer.exe"
$LogPath = "$env:ProgramData\Logs\AppName_Install.log"
$Arguments = "/S /L=$LogPath"

Start-Process -FilePath $InstallerPath -ArgumentList $Arguments -Wait -NoNewWindow
exit $LASTEXITCODE
```

### Detection Script Pattern
```powershell
# Return output for detected, nothing for not detected
$AppPath = "${env:ProgramFiles}\AppName\app.exe"
$MinVersion = [version]"1.0.0"

if (Test-Path $AppPath) {
    $Version = [version](Get-Item $AppPath).VersionInfo.FileVersion
    if ($Version -ge $MinVersion) {
        Write-Output "Detected: $Version"
        exit 0
    }
}
exit 1
```

## Security Requirements

### Script Signing
- Sign all production scripts with code signing certificate
- Use `Set-AuthenticodeSignature` for signing
- Verify signatures before deployment

### Credential Handling
- NEVER hardcode credentials
- Use `Get-Credential` for interactive scripts
- Use managed identities or secure vaults for automation
- Clear sensitive variables: `Remove-Variable -Name SecureVar`

### Execution Policy Considerations
- Scripts may run under restricted policies
- Use `-ExecutionPolicy Bypass` only when necessary
- Document execution requirements

### SYSTEM Context Awareness
```powershell
# Check if running as SYSTEM
$IsSystem = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq 'S-1-5-18'

# Paths differ in SYSTEM context
if ($IsSystem) {
    $LogPath = "$env:ProgramData\Logs"
} else {
    $LogPath = "$env:LOCALAPPDATA\Logs"
}
```

## Common Patterns

### Silent Installer Arguments
| Installer Type | Silent Args |
|----------------|-------------|
| MSI | `/qn /norestart ALLUSERS=1` |
| NSIS | `/S` |
| Inno Setup | `/VERYSILENT /NORESTART` |
| InstallShield | `/s /v"/qn"` |

### Registry Checks
```powershell
# 64-bit app on 64-bit OS
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{GUID}"

# 32-bit app on 64-bit OS
$RegPath = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{GUID}"

if (Test-Path $RegPath) {
    $Installed = (Get-ItemProperty $RegPath).DisplayVersion
}
```

### Process Cleanup Before Install
```powershell
$ProcessesToKill = @('app', 'apphelper', 'appservice')
foreach ($Proc in $ProcessesToKill) {
    Get-Process -Name $Proc -ErrorAction SilentlyContinue | Stop-Process -Force
}
```

## Audit Script Standards

### Output Format
- Return structured objects for easy reporting
- Use `[PSCustomObject]` for results
- Export to CSV/JSON for compliance reports

### Common Audit Checks
```powershell
[PSCustomObject]@{
    ComputerName = $env:COMPUTERNAME
    CheckName    = "BitLocker Status"
    Status       = "Compliant"  # or "Non-Compliant", "Error"
    Details      = "C: drive encrypted"
    Timestamp    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}
```

## Preferences

### When Writing Scripts
- Prefer native PowerShell cmdlets over calling external executables
- Always include `-ErrorAction` on commands that might fail
- Test in both user and SYSTEM contexts
- Consider 32-bit vs 64-bit scenarios
- Make scripts idempotent (safe to run multiple times)

### When Debugging
- Add `-Verbose` support via `[CmdletBinding()]`
- Include transcript logging for complex scripts
- Test detection scripts return correct exit codes

### Documentation
- Include comment-based help for all scripts
- Document silent install switches for each app
- Note any prerequisites or dependencies

---
*This file provides context for AI assistance with Windows deployment scripting.*
