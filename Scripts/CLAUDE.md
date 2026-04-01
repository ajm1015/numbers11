# SAPFIX

## Goal
Portable PowerShell toolkit for diagnosing and remediating SAP GUI deployment issues in a Microsoft-managed enterprise (Intune/Company Portal). Primary use case: field engineer runs a script on a broken box and it fixes the problem or tells them exactly what's wrong.

## Architecture
```
SAPFIX/
├── CLAUDE.md
├── Fix-SAPLandscape.ps1      # Landscape config diagnostic + remediation
└── (future scripts follow same pattern)
```

Each script is **standalone, single-file, zero dependencies beyond PowerShell 5.1+**. No modules, no dot-sourcing, no shared libs. Every script runs in isolation on a cold machine.

### Script pattern
- `#Requires -RunAsAdministrator` when HKLM/system writes are needed.
- `$ErrorActionPreference = 'Stop'` at top.
- Numbered checks, each prints colored pass/fail/fix status.
- Auto-fixes what's safe to fix. Logs what it fixed and what remains.
- Summary block at end: what was fixed, what needs manual attention.
- No logging frameworks, no transcript files, no external output. Console only.

## Constraints
- **Environment:** Windows 10/11, PowerShell 5.1+. No PSCore dependency.
- **Execution context:** Manual admin run from elevated terminal. Not Intune remediation (yet).
- **SAP specifics:**
  - Server landscape UNC: `\\retail\applications\SAP\SAPUILandscapeOnServer.xml` (hardcoded, single-site environment).
  - 64-bit SAP GUI is the target. 32-bit is legacy/orphan.
  - Native registry: `HKLM:\SOFTWARE\SAP\SAPLogon\Options`
  - WOW6432Node: `HKLM:\SOFTWARE\WOW6432Node\SAP\SAPLogon\Options`
- **Code style:** Maximum compression. No verbose logging, no comment blocks, no single-use wrappers. Names self-document. Guards over conditionals.
- **No destructive actions without explicit intent.** Scripts fix config/registry. They do not uninstall software, delete user profiles, or nuke directories.

## What exists
- `Fix-SAPLandscape.ps1` — Diagnoses and remediates the `SAPUILandscapeOnServer.xml` missing/stale config after 32→64-bit migration. Checks: server XML reachability, native + WOW6432Node registry, per-user landscape XML, global landscape XML, orphaned 32-bit install remnants.

## Tasks (backlog — build only when a real issue triggers it)
- [ ] SAP GUI COM/shortcut registration check (do shortcuts point to x86 or x64 binary?)
- [ ] SAP GUI version detection + mismatch reporting
- [ ] Certificate trust check for landscape server path (the `CertErrorHandlingMode: DoNotIgnoreErrorsMode[3]` issue)
- [ ] Intune detection/remediation pair variant of `Fix-SAPLandscape.ps1`
- [ ] Shared config module IF and only if 3+ scripts duplicate the same env constants

## Verification
- Run `Fix-SAPLandscape.ps1` on a machine exhibiting the "SAP Logon 800 — server configuration file incorrect or unavailable" error.
- Script should report the missing/wrong registry value, fix it, and summary should show the fix.
- Relaunch SAP Logon — error should not reappear and server list should populate.
- Run again on same machine — should report all checks OK, no fixes applied (idempotent).

## What Claude gets wrong
- Overengineers PowerShell: adds logging modules, transcript exports, parameter blocks with 15 params, comment-based help, verbose Write-Output wrappers. **Don't.** These are field tools, not shipped modules.
- Wraps simple registry reads in try/catch/function layers. Inline it.
- Adds "are you sure?" confirmation prompts. These run in an admin terminal by an engineer who chose to run them. No prompts.
- Generates backlog scripts speculatively. Only build when a real incident creates the need.
