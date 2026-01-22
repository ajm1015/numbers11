# Windows Deployment & Scripting Repository

Repository for PowerShell scripts, Bash utilities, and Win32 app deployment packages for Windows system management. Focus on clean installations, dependency management, and secure scripting practices for enterprise environments.

## Project Structure

```
/Deployments      - Win32 app packages (install/uninstall/detection scripts)
/Scripts          - Standalone utility scripts
/Modules          - Reusable PowerShell modules
/Audit            - Compliance and audit scripts
/Templates        - Script templates and boilerplate
```

## Quick Start

1. **Review Templates**: Start with the templates in `/Templates` directory
2. **Create Deployment Package**: Copy templates to `/Deployments/AppName_v1.0/`
3. **Customize Scripts**: Modify configuration variables and logic
4. **Package for Intune**: Use IntuneWinAppUtil to create `.intunewin` files

## Documentation

- **Claude.md** - Complete project context and conventions
- **Templates/README.md** - Template usage guide

## Tech Stack

- **Primary**: PowerShell 5.1 / PowerShell 7+
- **Secondary**: Bash (for cross-platform or macOS/Linux tooling)
- **Deployment**: Intune Win32 apps, SCCM/MECM, or standalone installers
- **Packaging**: IntuneWinAppUtil, PSADT (PowerShell App Deployment Toolkit)

## Standards & Conventions

All scripts follow the conventions defined in `Claude.md`:

- PowerShell naming conventions (Verb-Noun.ps1)
- Error handling with try/catch
- Structured logging
- Proper exit codes
- SYSTEM context awareness
- Security best practices

## Getting Started

1. Copy a template from `/Templates` to your target directory
2. Customize the configuration variables
3. Test locally before deployment
4. Package for Intune using IntuneWinAppUtil

For detailed guidelines, see `Claude.md`.
