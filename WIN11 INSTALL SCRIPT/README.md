# Fast Windows 11 Installer

High-speed, zero-touch Windows 11 deployment solution optimized for Intune-managed environments.

## Overview

This toolkit creates a streamlined Windows 11 installation that:
- Installs in **under 10 minutes** on NVMe drives
- Requires **zero user interaction** during setup
- Automatically partitions disks (GPT/UEFI)
- Bypasses Windows 11 hardware requirements (TPM, Secure Boot checks)
- Skips OOBE for immediate Intune/Azure AD enrollment
- Removes bloatware for faster deployment

## Quick Start

### Option 1: Simple USB Creation

```powershell
# Run as Administrator
.\Create-BootableUSB.ps1 -IsoPath "C:\ISO\Win11_23H2.iso" -USBDrive "E:"
```

This creates a ready-to-use bootable USB with unattended installation.

### Option 2: Full Build (Optimized Image)

```powershell
# Run as Administrator - Creates optimized installer with removed bloatware
.\Build-FastWin11Installer.ps1 -IsoPath "C:\ISO\Win11.iso" -OutputPath "C:\FastInstaller" -TargetUSB "E:"
```

## Files

| File | Purpose |
|------|---------|
| `Build-FastWin11Installer.ps1` | Full build script - optimizes image, removes bloat, creates USB/ISO |
| `Create-BootableUSB.ps1` | Quick USB creator - vanilla Windows with unattended config |
| `Quick-Deploy.ps1` | WinPE deployment script - for manual DISM deployments |
| `autounattend.xml` | Answer file - enables zero-touch installation |

## Usage Scenarios

### Scenario 1: Re-imaging a fleet of machines

1. Build an optimized installer once:
   ```powershell
   .\Build-FastWin11Installer.ps1 -IsoPath "C:\ISO\Win11.iso" -OutputPath "C:\FastInstaller" -OutputISO
   ```

2. Use the resulting ISO/USB across all machines
3. Each machine auto-installs and enrolls via Intune

### Scenario 2: Quick one-off reinstall

1. Create a simple USB:
   ```powershell
   .\Create-BootableUSB.ps1 -IsoPath "C:\ISO\Win11.iso" -USBDrive "E:"
   ```

2. Boot target machine from USB
3. Installation proceeds automatically

### Scenario 3: WinPE-based deployment (MDT/SCCM alternative)

1. Boot into WinPE
2. Run the Quick-Deploy script:
   ```powershell
   X:\Scripts\Quick-Deploy.ps1 -DiskNumber 0
   ```

## Installation Process

When booting from the USB/ISO, the installation proceeds as follows:

```
┌─────────────────────────────────────────────────────────────┐
│  1. Boot from USB/ISO                                       │
│  2. Disk auto-partitioned (EFI + MSR + Windows)             │
│  3. Windows image applied (~3-7 minutes on NVMe)            │
│  4. First boot - specialize phase                           │
│  5. OOBE skipped → Desktop                                  │
│  6. User connects to network → Intune enrollment begins     │
└─────────────────────────────────────────────────────────────┘
```

Total time: **5-15 minutes** depending on storage speed

## Disk Partitioning

The installer creates this partition layout (GPT/UEFI):

| Partition | Size | Format | Purpose |
|-----------|------|--------|---------|
| EFI System | 300 MB | FAT32 | UEFI boot files |
| MSR | 16 MB | - | Microsoft Reserved |
| Windows | Remaining | NTFS | OS installation |

## Customization

### Change Windows Edition

Edit `autounattend.xml` and modify the image index:

```xml
<Key>/IMAGE/INDEX</Key>
<Value>1</Value>  <!-- 1=Pro, 3=Enterprise, etc. -->
```

To list available editions from an ISO:
```powershell
Mount-DiskImage -ImagePath "C:\ISO\Win11.iso"
# Get the drive letter, then:
Get-WindowsImage -ImagePath "D:\sources\install.wim"
```

### Change Computer Name Prefix

Edit `autounattend.xml`:
```xml
<ComputerName>YOURPREFIX-*</ComputerName>
```

The `*` generates a random suffix.

### Change Regional Settings

Modify all `Locale` settings in `autounattend.xml`:
```xml
<InputLocale>en-GB</InputLocale>
<SystemLocale>en-GB</SystemLocale>
<UILanguage>en-GB</UILanguage>
<UserLocale>en-GB</UserLocale>
```

### Add Custom Drivers

Using `Build-FastWin11Installer.ps1`:
```powershell
.\Build-FastWin11Installer.ps1 -IsoPath "C:\ISO\Win11.iso" -OutputPath "C:\FastInstaller"
# Then inject drivers before creating USB/ISO
```

Or add drivers manually after mounting the WIM.

### Skip Hardware Requirements

The `autounattend.xml` includes registry commands to bypass:
- TPM 2.0 requirement
- Secure Boot requirement
- RAM requirement
- CPU requirement

## Troubleshooting

### Installation hangs at disk selection

The autounattend.xml targets Disk 0. If your system has multiple disks, edit:
```xml
<DiskID>0</DiskID>  <!-- Change to correct disk number -->
```

### USB won't boot

1. Ensure UEFI boot mode is enabled in BIOS
2. Disable Secure Boot temporarily
3. Check USB is formatted as GPT (not MBR)

### Installation starts but fails

Check the Windows setup logs:
```
X:\Windows\Panther\setuperr.log
X:\Windows\Panther\setupact.log
```

### "Windows cannot be installed on this disk"

Usually means MBR/GPT mismatch. The answer file uses GPT. Ensure:
1. UEFI mode is enabled
2. Target disk doesn't have conflicting partition table

## Requirements

### For Creating the Installer
- Windows 10/11 with PowerShell 5.1+
- Administrator privileges
- Windows 11 ISO (download from Microsoft)
- USB drive (8GB minimum, 16GB+ recommended)
- Optional: Windows ADK (for ISO creation)

### Target Machine Requirements
- UEFI firmware (recommended)
- 4GB+ RAM
- 64GB+ storage
- Network connection (for Intune enrollment)

## Integration with Intune

After installation:

1. Machine boots to desktop with local admin access
2. User connects to network (Ethernet or WiFi)
3. Intune enrollment can be triggered via:
   - Azure AD Join during OOBE (if not fully skipped)
   - Provisioning package
   - Bulk enrollment token
   - User-initiated enrollment

### Recommended Intune Configuration

1. **Autopilot**: Register device hash before imaging
2. **Enrollment Status Page**: Show progress during app installation
3. **Required Apps**: Deploy immediately after enrollment
4. **Compliance Policies**: Enforce after 24-hour grace period

## Advanced: WinPE Quick Deploy

For maximum control, boot into WinPE and run:

```powershell
# Basic deployment
.\Quick-Deploy.ps1

# Deploy to specific disk
.\Quick-Deploy.ps1 -DiskNumber 1

# Compact mode (saves disk space)
.\Quick-Deploy.ps1 -Compact

# Fully automated (no prompts)
.\Quick-Deploy.ps1 -WipeDisk -NoReboot
```

## Performance Benchmarks

| Storage Type | Image Apply | Total Install |
|-------------|-------------|---------------|
| NVMe SSD | ~2 min | ~5 min |
| SATA SSD | ~4 min | ~8 min |
| HDD | ~12 min | ~20 min |

Times measured with optimized image (bloat removed).

## Security Considerations

- The answer file skips Windows 11 hardware security checks
- No local user account is created (Intune handles identity)
- BitLocker should be enabled via Intune policy post-enrollment
- Consider creating a dedicated imaging network segment

## Contributing

Feel free to submit issues and pull requests for:
- Additional bloatware removal
- Regional configuration templates
- Driver injection automation
- SCCM/MDT integration scripts
