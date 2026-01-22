# Project Context for Claude Code

> This file is automatically read by Claude Code to understand project context.
> Customize this template for each project.

## Overview

[Brief description of what this project does]

## Tech Stack

- **Primary Language**: [e.g., PowerShell, Python, Bash]
- **Platform**: [e.g., Intune, Kandji, Azure]
- **Dependencies**: [List key dependencies]

## Code Standards

### General
- Use consistent indentation (4 spaces for PowerShell/Python, 2 for YAML)
- Include comment headers with version, author, description
- Handle errors explicitly with try/catch blocks

### PowerShell Specific
- Use approved verbs only (Get-, Set-, New-, Remove-, etc.)
- Include `#Requires -Version 5.1` statement
- Use `[CmdletBinding()]` for advanced functions
- Detection scripts: exit 0 for compliant, exit 1 for non-compliant
- Use `Write-Host` for Intune detection output (not Write-Output)

### Bash Specific
- Include shebang: `#!/bin/bash`
- Use `set -e` for error handling
- Quote all variables: `"$variable"`

## File Structure

```
/
├── src/               # Source code
├── tests/             # Test files
├── docs/              # Documentation
└── scripts/           # Utility scripts
```

## Testing

[Describe how to run tests]

```bash
# Example:
Invoke-Pester -Path ./tests/
```

## Deployment

[Describe deployment process]

## When Making Changes

1. **Before starting**: Pull latest changes
2. **While coding**: Follow code standards above
3. **Before committing**: 
   - Run tests
   - Update version in script header
   - Update CHANGELOG.md if significant
4. **Commit messages**: Use conventional commits (feat:, fix:, docs:, etc.)

## Common Tasks

### Adding a new Intune detection script
1. Create script in `/intune/detection/`
2. Add corresponding remediation if needed
3. Update manifest
4. Test locally with `test-detection <script.ps1>`

### Packaging for Intune
1. Run `./scripts/package.ps1 -Name <AppName>`
2. Upload .intunewin to Intune portal

## Important Notes

- [Add project-specific notes, gotchas, or important context]
- [Things Claude should know to work effectively]

## Contacts

- **Owner**: [Name]
- **Team**: [Team name]
