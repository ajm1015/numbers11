# Microsoft .NET Windows Desktop Runtime 8.0.23 Deployment Package

This package contains scripts for deploying Microsoft .NET Windows Desktop Runtime 8.0.23 via Intune Win32 apps.

## Package Structure

```
DotNetRuntime/
├── Source/
│   └── windowsdesktop-runtime-8.0.23-win-x64.exe  (Your installer)
├── Install.ps1
├── Uninstall.ps1
├── Detection.ps1
└── README.md
```

## Setup Instructions

1. **Place the installer** in the `Source/` directory:
   ```
   DotNetRuntime/Source/windowsdesktop-runtime-8.0.23-win-x64.exe
   ```

   The script is already configured for this installer name.

## Scripts

### Install.ps1
- Installs .NET Runtime silently using `/install /quiet /norestart`
- Logs installation to `$env:ProgramData\Logs\DotNetRuntime_Install.log`
- Handles exit codes: 0 (success), 3010 (reboot required), 1603 (fatal error)

### Uninstall.ps1
- Automatically finds .NET Runtime installations via registry
- Uninstalls all found .NET Runtime installations silently
- Handles multiple .NET Runtime versions if present

### Detection.ps1
- Checks for Windows Desktop Runtime 8.0.23 via registry and `dotnet --version` command
- Requires minimum version 8.0.23
- Detection method: Both (Registry + Command) by default

## Intune Win32 App Configuration

When packaging with IntuneWinAppUtil:

1. **Install command**: `powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1`
2. **Uninstall command**: `powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1`
3. **Detection script**: `Detection.ps1`
4. **Return codes**:
   - 0 = Success
   - 3010 = Success, reboot required
   - 1 = Failure

## Customization

### Minimum Version Requirement
The detection script is configured to require Windows Desktop Runtime 8.0.23 minimum. 
To change this, edit `Detection.ps1`:
```powershell
[version]$MinVersion = [version]"8.0.23"
```

### Different Installer Name
If you need to use a different installer, edit `Install.ps1`:
```powershell
$InstallerPath = "$PSScriptRoot\Source\your-installer-name.exe"
```

## Silent Install Arguments

The installer uses:
- `/install` - Install the runtime
- `/quiet` - Silent installation (no UI)
- `/norestart` - Suppress automatic reboot

For additional options, refer to Microsoft .NET Runtime installer documentation.

## Notes

- Windows Desktop Runtime includes both .NET Runtime and Windows Desktop components
- Multiple .NET versions can coexist on the same system
- The uninstall script will remove Windows Desktop Runtime 8.0.x installations
- Detection checks both 64-bit and 32-bit registry paths
- Installation logs are stored in `$env:ProgramData\Logs\`
- This package is configured for Windows Desktop Runtime 8.0.23 x64
