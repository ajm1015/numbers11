# PowerShell Script Templates

This directory contains standardized templates for Windows deployment and scripting tasks.

## Available Templates

### Installation & Deployment

- **Install-Script-Template.ps1** - Template for Win32 app installation scripts
  - Handles silent installation
  - Logging and error handling
  - Process cleanup before install
  - Exit code management (0 = success, 3010 = reboot required)

- **Uninstall-Script-Template.ps1** - Template for Win32 app uninstallation scripts
  - Automatic uninstaller detection via registry
  - Supports MSI and EXE uninstallers
  - Process cleanup
  - Exit code management

- **Detection-Script-Template.ps1** - Template for Intune detection scripts
  - File-based detection
  - Registry-based detection
  - Version comparison
  - Exit code 0 = detected, 1 = not detected

- **Requirements-Script-Template.ps1** - Template for prerequisite checks
  - OS version validation
  - PowerShell version check
  - Disk space verification
  - Custom requirement checks

### Compliance & Auditing

- **Audit-Script-Template.ps1** - Template for compliance audit scripts
  - Structured output objects
  - Multiple output formats (CSV, JSON, Console)
  - Example checks: BitLocker, Windows Updates, Firewall, Local Admins
  - Easy to extend with custom checks

## Usage

1. Copy the appropriate template to your project directory
2. Rename the file to match your application/script name
3. Modify the configuration variables at the top of the script:
   - Application name
   - Installer paths and arguments
   - Detection methods
   - Log paths
4. Customize the script logic as needed
5. Test thoroughly before deployment

## Template Conventions

All templates follow the standards defined in `../Claude.md`:

- PowerShell 5.1+ compatible
- Comment-based help included
- Error handling with try/catch
- Verbose logging support
- Proper exit codes
- SYSTEM context awareness

## Customization Tips

- **Silent Install Arguments**: Refer to the table in `Claude.md` for common installer types
- **Detection Methods**: Choose File, Registry, or Both based on your application
- **Logging**: Logs are written to `$env:ProgramData\Logs\` when running as SYSTEM
- **Exit Codes**: Use standard codes (0, 1, 3010) for Intune compatibility
