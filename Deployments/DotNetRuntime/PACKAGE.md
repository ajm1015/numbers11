# Packaging Guide for Intune Win32 App

This guide explains how to package your .NET Windows Desktop Runtime deployment for Intune using IntuneWinAppUtil.

## Prerequisites

1. **Download IntuneWinAppUtil** from Microsoft:
   - Download: https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases
   - Extract `IntuneWinAppUtil.exe` to a folder (e.g., `C:\Tools\IntuneWinAppUtil\`)

2. **Verify your package structure**:
   ```
   DotNetRuntime/
   ├── Source/
   │   └── windowsdesktop-runtime-8.0.23-win-x64.exe
   ├── Install.ps1
   ├── Uninstall.ps1
   ├── Detection.ps1
   └── README.md
   ```

## Packaging Steps

### Option 1: Using PowerShell (Recommended)

1. **Open PowerShell** as Administrator
2. **Navigate to your IntuneWinAppUtil directory**:
   ```powershell
   cd C:\Tools\IntuneWinAppUtil
   ```

3. **Run IntuneWinAppUtil** with these parameters:
   ```powershell
   .\IntuneWinAppUtil.exe -c "C:\Path\To\Deployments\DotNetRuntime" -s "C:\Path\To\Deployments\DotNetRuntime\Source" -o "C:\Path\To\Deployments\DotNetRuntime\Output" -q
   ```

   Replace the paths with your actual paths:
   - `-c` = Source folder (the DotNetRuntime folder containing Install.ps1, etc.)
   - `-s` = Setup file folder (the Source folder with the .exe)
   - `-o` = Output folder (where the .intunewin file will be created)
   - `-q` = Quiet mode (optional, suppresses prompts)

### Option 2: Interactive Mode

If you omit the `-q` flag, IntuneWinAppUtil will prompt you:

```powershell
.\IntuneWinAppUtil.exe
```

Then answer the prompts:
- **Source folder**: `C:\Path\To\Deployments\DotNetRuntime`
- **Setup file folder**: `C:\Path\To\Deployments\DotNetRuntime\Source`
- **Output folder**: `C:\Path\To\Deployments\DotNetRuntime\Output`
- **Setup file**: `windowsdesktop-runtime-8.0.23-win-x64.exe`
- **Catalog folder**: (Leave empty, press Enter)

### Option 3: Using the Helper Script

See `Package-IntuneApp.ps1` in this directory for an automated packaging script.

## What Gets Created

After running IntuneWinAppUtil, you'll get:
- `DotNetRuntime.intunewin` - The packaged file ready for Intune upload

## Intune Configuration

When uploading to Intune, use these settings:

### Program Tab
- **Install command**: 
  ```
  powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1
  ```
- **Uninstall command**: 
  ```
  powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
  ```

### Detection Rules Tab
- **Rules format**: Use a custom script
- **Script file**: Upload `Detection.ps1`
- **Run script as 32-bit process**: No (unchecked)

### Requirements Tab
- **Operating system architecture**: x64
- **Minimum operating system**: Windows 10 1809 or later

### Return Codes
- **0** = Success
- **3010** = Success, reboot required
- **1** = Failure

## Troubleshooting

### Error: "Setup file not found"
- Ensure the installer is in the `Source/` folder
- Check the filename matches exactly: `windowsdesktop-runtime-8.0.23-win-x64.exe`

### Error: "Source folder not found"
- Use absolute paths, not relative paths
- Ensure the path doesn't have trailing backslashes

### Package is too large
- The .intunewin file will be roughly the same size as your installer
- Windows Desktop Runtime installer is typically ~100-200 MB

## Example Full Command

```powershell
# Navigate to IntuneWinAppUtil
cd C:\Tools\IntuneWinAppUtil

# Package the app (adjust paths as needed)
.\IntuneWinAppUtil.exe `
  -c "C:\Users\YourName\Documents\GitHub\Deployments\DotNetRuntime" `
  -s "C:\Users\YourName\Documents\GitHub\Deployments\DotNetRuntime\Source" `
  -o "C:\Users\YourName\Documents\GitHub\Deployments\DotNetRuntime\Output" `
  -q
```

The output `.intunewin` file will be in the Output folder and ready to upload to Intune!
