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

## Root cause (resolved)
The "SAP Logon 800 — server configuration file incorrect or unavailable" error was **not** a migration artifact, cert trust failure, or missing PSE. The landscape path was set to the NetBIOS short name (`\\retail\applications\...`) instead of the FQDN (`\\retail.nrgenergy.com\applications\...`). NetBIOS resolution is machine-dependent — fails on fresh images, fails intermittently on domain machines depending on DNS suffix search order and WINS availability. FQDN resolves via DNS every time.

The `CertErrorHandlingMode: DoNotIgnoreErrorsMode[3]` in the error dialog was a red herring — it's SAP GUI's default diagnostic output when it can't load a landscape file for any reason, not a cert-specific failure.

## Environment constants
- **Correct server landscape path:** `\\retail.nrgenergy.com\applications\SAP\SAPUILandscapeOnServer.xml`
- **Known bad variant:** `\\retail\applications\SAP\SAPUILandscapeOnServer.xml` (NetBIOS — treat as misconfiguration, auto-fix to FQDN)
- **Native registry:** `HKLM:\SOFTWARE\SAP\SAPLogon\Options` → `LandscapeFileOnServer`
- **WOW6432Node:** `HKLM:\SOFTWARE\WOW6432Node\SAP\SAPLogon\Options` → same value (legacy 32-bit)
- **64-bit SAP GUI is the target.** 32-bit is legacy/orphan.

## Constraints
- **Environment:** Windows 10/11, PowerShell 5.1+. No PSCore dependency.
- **Execution context:** Manual admin run from elevated terminal. Not Intune remediation (yet).
- **Code style:** Maximum compression. No verbose logging, no comment blocks, no single-use wrappers. Names self-document. Guards over conditionals.
- **No destructive actions without explicit intent.** Scripts fix config/registry. They do not uninstall software, delete user profiles, or nuke directories.

## What exists
- `Fix-SAPLandscape.ps1` — Diagnoses and remediates landscape config. **Needs update:**
  - Correct path to `\\retail.nrgenergy.com\applications\SAP\SAPUILandscapeOnServer.xml`
  - Detect NetBIOS short name (`\\retail\`) as a misconfiguration and auto-fix to FQDN
  - Check both FQDN reachability and flag if only short name resolves (DNS/network issue)
  - Remove cert-related backlog items — that was a dead end

## Tasks
- [x] Update `Fix-SAPLandscape.ps1` with FQDN path and NetBIOS detection
- [ ] SAP GUI COM/shortcut registration check (do shortcuts point to x86 or x64 binary?)
- [ ] SAP GUI version detection + mismatch reporting
- [ ] Intune detection/remediation pair variant of `Fix-SAPLandscape.ps1`
- [ ] Review 64-bit Company Portal package (`SAPInstallwithWait_64.ps1`) and submit corrected install script with FQDN landscape path — this is where the bug lives upstream

## Verification
- Run `Fix-SAPLandscape.ps1` on a machine exhibiting the "SAP Logon 800" error.
- Script should detect the NetBIOS path, fix to FQDN, and report it.
- Run on a machine with no landscape key — should create it with FQDN.
- Run on a machine already correct — all checks OK, no fixes applied (idempotent).
- Relaunch SAP Logon after fix — server list populates, error gone.

## What Claude gets wrong
- Overengineers PowerShell: adds logging modules, transcript exports, parameter blocks with 15 params, comment-based help, verbose Write-Output wrappers. **Don't.** These are field tools, not shipped modules.
- Wraps simple registry reads in try/catch/function layers. Inline it.
- Adds "are you sure?" confirmation prompts. These run in an admin terminal by an engineer who chose to run them. No prompts.
- Generates backlog scripts speculatively. Only build when a real incident creates the need.
- Chases secondary error messages (like CertErrorHandlingMode) as root causes. SAP GUI dumps multiple diagnostics when it fails — only the file path and reachability matter. Everything else is noise until proven otherwise.
