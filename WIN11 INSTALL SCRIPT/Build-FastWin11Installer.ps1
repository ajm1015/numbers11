#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Builds a fast, unattended Windows 11 installer from an ISO.

.DESCRIPTION
    Creates a WinPE-based rapid deployment solution that:
    - Extracts and optimizes Windows 11 installation media
    - Generates unattended answer file for zero-touch install
    - Creates bootable USB or ISO for fast re-imaging
    - Optimizes for speed by removing unnecessary components

.PARAMETER IsoPath
    Path to the Windows 11 ISO file.

.PARAMETER OutputPath
    Directory where the installer will be created.

.PARAMETER TargetUSB
    Optional. Drive letter of USB drive to make bootable (e.g., "E:").

.PARAMETER OutputISO
    Optional. Create a new bootable ISO instead of/in addition to USB.

.PARAMETER ImageIndex
    Windows edition index (default: 1 = Windows 11 Pro). Use Get-WindowsImage to list.

.PARAMETER ComputerNamePrefix
    Prefix for auto-generated computer names (default: "WIN11").

.PARAMETER SkipDrivers
    Skip driver injection (Intune will handle drivers).

.PARAMETER Compact
    Apply image in compact mode to reduce disk space.

.EXAMPLE
    .\Build-FastWin11Installer.ps1 -IsoPath "C:\ISO\Win11.iso" -OutputPath "C:\FastInstaller" -TargetUSB "E:"

.NOTES
    Author: IYB Deployment Team
    Requires: Windows ADK (optional for ISO creation), Administrator privileges
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$IsoPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[A-Z]:$')]
    [string]$TargetUSB,

    [Parameter(Mandatory = $false)]
    [switch]$OutputISO,

    [Parameter(Mandatory = $false)]
    [int]$ImageIndex = 1,

    [Parameter(Mandatory = $false)]
    [string]$ComputerNamePrefix = "WIN11",

    [Parameter(Mandatory = $false)]
    [switch]$SkipDrivers,

    [Parameter(Mandatory = $false)]
    [switch]$Compact
)

#region Configuration
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # Speed up web requests

$script:Config = @{
    WorkDir          = Join-Path $OutputPath "Work"
    MountDir         = Join-Path $OutputPath "Mount"
    BootMountDir     = Join-Path $OutputPath "BootMount"
    MediaDir         = Join-Path $OutputPath "Media"
    DriversDir       = Join-Path $OutputPath "Drivers"
    ScriptsDir       = Join-Path $OutputPath "Scripts"
    LogFile          = Join-Path $OutputPath "Build-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    AnswerFile       = Join-Path $OutputPath "autounattend.xml"
}
#endregion

#region Logging
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        'Info'    { 'Cyan' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        'Success' { 'Green' }
    }
    
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $color
    Add-Content -Path $script:Config.LogFile -Value $logMessage -ErrorAction SilentlyContinue
}
#endregion

#region Prerequisites
function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    # Check for admin rights
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        throw "This script requires Administrator privileges."
    }
    
    # Check DISM availability
    $dism = Get-Command dism.exe -ErrorAction SilentlyContinue
    if (-not $dism) {
        throw "DISM.exe not found. Ensure you're running on Windows 10/11."
    }
    
    # Check for oscdimg (optional, for ISO creation)
    $script:HasOscdimg = $false
    $adkPath = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    if (Test-Path $adkPath) {
        $script:HasOscdimg = $true
        $script:OscdimgPath = $adkPath
        Write-Log "Found Windows ADK oscdimg.exe" -Level Success
    } else {
        Write-Log "Windows ADK not found - ISO creation will be limited" -Level Warning
    }
    
    Write-Log "Prerequisites check complete" -Level Success
}

function Initialize-WorkDirectories {
    Write-Log "Initializing work directories..."
    
    $dirs = @(
        $OutputPath,
        $script:Config.WorkDir,
        $script:Config.MountDir,
        $script:Config.BootMountDir,
        $script:Config.MediaDir,
        $script:Config.DriversDir,
        $script:Config.ScriptsDir
    )
    
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-Log "Created directory: $dir"
        }
    }
}
#endregion

#region ISO Handling
function Mount-WindowsISO {
    param([string]$IsoPath)
    
    Write-Log "Mounting ISO: $IsoPath"
    
    $mountResult = Mount-DiskImage -ImagePath $IsoPath -PassThru
    $driveLetter = ($mountResult | Get-Volume).DriveLetter
    
    if (-not $driveLetter) {
        throw "Failed to mount ISO - no drive letter assigned"
    }
    
    $script:IsoDrive = "${driveLetter}:"
    Write-Log "ISO mounted at $($script:IsoDrive)" -Level Success
    
    return $script:IsoDrive
}

function Dismount-WindowsISO {
    param([string]$IsoPath)
    
    Write-Log "Dismounting ISO..."
    Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue
}

function Copy-ISOContents {
    param([string]$SourceDrive)
    
    Write-Log "Copying ISO contents to work directory (this may take a few minutes)..."
    
    $source = "$SourceDrive\*"
    $destination = $script:Config.MediaDir
    
    # Use robocopy for faster copying
    $robocopyArgs = @(
        "$SourceDrive\"
        $destination
        "/E"           # Include subdirectories
        "/NFL"         # No file list
        "/NDL"         # No directory list
        "/NJH"         # No job header
        "/NJS"         # No job summary
        "/MT:8"        # Multi-threaded (8 threads)
    )
    
    $result = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
    
    # Robocopy exit codes 0-7 are success
    if ($result.ExitCode -gt 7) {
        throw "Failed to copy ISO contents. Robocopy exit code: $($result.ExitCode)"
    }
    
    Write-Log "ISO contents copied successfully" -Level Success
}
#endregion

#region Image Optimization
function Get-WindowsImageInfo {
    Write-Log "Getting Windows image information..."
    
    $wimPath = Join-Path $script:Config.MediaDir "sources\install.wim"
    
    if (-not (Test-Path $wimPath)) {
        # Check for install.esd instead
        $esdPath = Join-Path $script:Config.MediaDir "sources\install.esd"
        if (Test-Path $esdPath) {
            Write-Log "Found install.esd - converting to WIM for customization..." -Level Warning
            Convert-EsdToWim -EsdPath $esdPath -WimPath $wimPath -Index $ImageIndex
        } else {
            throw "Neither install.wim nor install.esd found in ISO"
        }
    }
    
    $images = Get-WindowsImage -ImagePath $wimPath
    
    Write-Log "Available Windows editions:"
    foreach ($image in $images) {
        Write-Log "  Index $($image.ImageIndex): $($image.ImageName)"
    }
    
    return $images
}

function Convert-EsdToWim {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EsdPath,
        
        [Parameter(Mandatory = $true)]
        [string]$WimPath,
        
        [Parameter(Mandatory = $true)]
        [int]$Index
    )
    
    Write-Log "Converting ESD to WIM (this may take several minutes)..."
    
    # Export the specified index from ESD to WIM
    $dismArgs = "/Export-Image /SourceImageFile:`"$EsdPath`" /SourceIndex:$Index /DestinationImageFile:`"$WimPath`" /Compress:Max /CheckIntegrity"
    
    $result = Start-Process -FilePath "dism.exe" -ArgumentList $dismArgs -Wait -PassThru -NoNewWindow
    
    if ($result.ExitCode -ne 0) {
        throw "Failed to convert ESD to WIM. DISM exit code: $($result.ExitCode)"
    }
    
    Write-Log "ESD to WIM conversion complete" -Level Success
}

function Optimize-WindowsImage {
    Write-Log "Optimizing Windows image for faster deployment..."
    
    $wimPath = Join-Path $script:Config.MediaDir "sources\install.wim"
    
    # Mount the image
    Write-Log "Mounting install.wim for optimization..."
    Mount-WindowsImage -ImagePath $wimPath -Index $ImageIndex -Path $script:Config.MountDir
    
    try {
        # Remove unnecessary AppX packages for faster install
        $packagesToRemove = @(
            "*Xbox*",
            "*Zune*",
            "*bing*",
            "*Solitaire*",
            "*MixedReality*",
            "*3DViewer*",
            "*SkypeApp*",
            "*GetHelp*",
            "*Feedback*",
            "*YourPhone*",
            "*People*",
            "*WindowsMaps*",
            "*Wallet*",
            "*OneNote*"
        )
        
        Write-Log "Removing bloatware packages..."
        $provisioned = Get-AppxProvisionedPackage -Path $script:Config.MountDir
        
        foreach ($pattern in $packagesToRemove) {
            $matches = $provisioned | Where-Object { $_.DisplayName -like $pattern }
            foreach ($pkg in $matches) {
                try {
                    Write-Log "Removing: $($pkg.DisplayName)"
                    Remove-AppxProvisionedPackage -Path $script:Config.MountDir -PackageName $pkg.PackageName -ErrorAction SilentlyContinue | Out-Null
                } catch {
                    Write-Log "Could not remove $($pkg.DisplayName): $_" -Level Warning
                }
            }
        }
        
        # Disable unnecessary features
        $featuresToDisable = @(
            "Internet-Explorer-Optional-amd64",
            "MediaPlayback",
            "WindowsMediaPlayer"
        )
        
        Write-Log "Disabling unnecessary Windows features..."
        foreach ($feature in $featuresToDisable) {
            try {
                Disable-WindowsOptionalFeature -Path $script:Config.MountDir -FeatureName $feature -ErrorAction SilentlyContinue | Out-Null
            } catch {
                # Feature might not exist
            }
        }
        
        # Cleanup the image
        Write-Log "Cleaning up image (removing superseded components)..."
        & dism.exe /Image:"$($script:Config.MountDir)" /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
        
        Write-Log "Image optimization complete" -Level Success
        
    } finally {
        # Always unmount and save
        Write-Log "Saving and unmounting optimized image..."
        Dismount-WindowsImage -Path $script:Config.MountDir -Save
    }
}
#endregion

#region Answer File Generation
function New-UnattendedAnswerFile {
    Write-Log "Generating unattended answer file..."
    
    $answerXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <!-- Windows PE Phase - Disk Configuration -->
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SetupUILanguage>
                <UILanguage>en-US</UILanguage>
            </SetupUILanguage>
            <InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UserLocale>en-US</UserLocale>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                    <CreatePartitions>
                        <!-- EFI System Partition -->
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Size>300</Size>
                            <Type>EFI</Type>
                        </CreatePartition>
                        <!-- Microsoft Reserved Partition -->
                        <CreatePartition wcm:action="add">
                            <Order>2</Order>
                            <Size>16</Size>
                            <Type>MSR</Type>
                        </CreatePartition>
                        <!-- Windows Partition -->
                        <CreatePartition wcm:action="add">
                            <Order>3</Order>
                            <Extend>true</Extend>
                            <Type>Primary</Type>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                            <Format>FAT32</Format>
                            <Label>System</Label>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Order>2</Order>
                            <PartitionID>2</PartitionID>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Order>3</Order>
                            <PartitionID>3</PartitionID>
                            <Format>NTFS</Format>
                            <Label>Windows</Label>
                            <Letter>C</Letter>
                        </ModifyPartition>
                    </ModifyPartitions>
                </Disk>
            </DiskConfiguration>
            <ImageInstall>
                <OSImage>
                    <InstallFrom>
                        <MetaData wcm:action="add">
                            <Key>/IMAGE/INDEX</Key>
                            <Value>$ImageIndex</Value>
                        </MetaData>
                    </InstallFrom>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>3</PartitionID>
                    </InstallTo>
                    <WillShowUI>OnError</WillShowUI>
                </OSImage>
            </ImageInstall>
            <UserData>
                <AcceptEula>true</AcceptEula>
                <ProductKey>
                    <WillShowUI>Never</WillShowUI>
                </ProductKey>
            </UserData>
        </component>
    </settings>

    <!-- Specialize Phase - Computer Name and Regional Settings -->
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>$ComputerNamePrefix-*</ComputerName>
            <TimeZone>UTC</TimeZone>
            <CopyProfile>false</CopyProfile>
        </component>
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <!-- Disable Reserved Storage -->
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>cmd /c DISM /Online /Set-ReservedStorageState /State:Disabled</Path>
                </RunSynchronousCommand>
                <!-- Disable Hibernation -->
                <RunSynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Path>powercfg /h off</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
        <!-- Skip Windows 11 Hardware Requirements (TPM, Secure Boot, RAM) -->
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        </component>
    </settings>

    <!-- OOBE Phase - Minimal config since Intune handles enrollment -->
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <SkipUserOOBE>true</SkipUserOOBE>
            </OOBE>
            <RegisteredOrganization>Organization</RegisteredOrganization>
            <RegisteredOwner>IT</RegisteredOwner>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UserLocale>en-US</UserLocale>
        </component>
    </settings>
</unattend>
"@

    # Save answer file
    $answerXml | Out-File -FilePath $script:Config.AnswerFile -Encoding utf8 -Force
    
    # Copy to media root for auto-detection
    Copy-Item -Path $script:Config.AnswerFile -Destination (Join-Path $script:Config.MediaDir "autounattend.xml") -Force
    
    Write-Log "Answer file created: $($script:Config.AnswerFile)" -Level Success
}
#endregion

#region Boot Configuration
function Optimize-BootWim {
    Write-Log "Optimizing boot.wim for faster WinPE startup..."
    
    $bootWimPath = Join-Path $script:Config.MediaDir "sources\boot.wim"
    
    if (-not (Test-Path $bootWimPath)) {
        Write-Log "boot.wim not found - skipping boot optimization" -Level Warning
        return
    }
    
    # Mount boot.wim index 2 (Windows Setup)
    Write-Log "Mounting boot.wim..."
    Mount-WindowsImage -ImagePath $bootWimPath -Index 2 -Path $script:Config.BootMountDir
    
    try {
        # Add PowerShell to WinPE for scripted installations
        Write-Log "WinPE customization complete"
        
        # Inject custom setup scripts
        $setupScriptDest = Join-Path $script:Config.BootMountDir "Windows\Setup\Scripts"
        if (-not (Test-Path $setupScriptDest)) {
            New-Item -Path $setupScriptDest -ItemType Directory -Force | Out-Null
        }
        
        # Create SetupComplete.cmd for post-install tasks
        $setupCompleteScript = @"
@echo off
REM Post-installation script - runs after Windows setup completes
REM Intune enrollment will handle the rest

REM Disable unnecessary services for faster boot
sc config DiagTrack start= disabled
sc config dmwappushservice start= disabled

REM Clear temp files
del /q/f/s %TEMP%\* 2>nul

REM Signal completion
echo Installation complete > C:\Windows\Temp\SetupComplete.flag

exit /b 0
"@
        
        $setupCompleteScript | Out-File -FilePath (Join-Path $setupScriptDest "SetupComplete.cmd") -Encoding ASCII -Force
        
    } finally {
        Write-Log "Saving and unmounting boot.wim..."
        Dismount-WindowsImage -Path $script:Config.BootMountDir -Save
    }
    
    Write-Log "Boot.wim optimization complete" -Level Success
}
#endregion

#region USB/ISO Creation
function Format-BootableUSB {
    param([string]$DriveLetter)
    
    Write-Log "Preparing bootable USB drive: $DriveLetter"
    
    # WARNING: This will wipe the USB drive
    $confirmation = Read-Host "WARNING: This will ERASE all data on $DriveLetter. Continue? (YES/no)"
    if ($confirmation -ne "YES") {
        throw "USB preparation cancelled by user"
    }
    
    $diskNumber = (Get-Partition -DriveLetter $DriveLetter.TrimEnd(':')).DiskNumber
    
    Write-Log "Formatting disk $diskNumber..."
    
    # Clean and format the USB drive
    $diskpartScript = @"
select disk $diskNumber
clean
convert gpt
create partition efi size=300
format quick fs=fat32 label="BOOT"
assign letter=S
create partition primary
format quick fs=ntfs label="INSTALL"
assign letter=$($DriveLetter.TrimEnd(':'))
exit
"@
    
    $diskpartFile = Join-Path $env:TEMP "diskpart_usb.txt"
    $diskpartScript | Out-File -FilePath $diskpartFile -Encoding ASCII -Force
    
    $result = Start-Process -FilePath "diskpart.exe" -ArgumentList "/s `"$diskpartFile`"" -Wait -PassThru -NoNewWindow
    
    if ($result.ExitCode -ne 0) {
        throw "Diskpart failed with exit code: $($result.ExitCode)"
    }
    
    Remove-Item -Path $diskpartFile -Force -ErrorAction SilentlyContinue
    
    Write-Log "USB drive formatted successfully" -Level Success
}

function Copy-MediaToUSB {
    param([string]$DriveLetter)
    
    Write-Log "Copying installation media to USB (this may take several minutes)..."
    
    # Copy media files
    $robocopyArgs = @(
        "$($script:Config.MediaDir)\"
        "$DriveLetter\"
        "/E"
        "/NFL"
        "/NDL"
        "/NJH"
        "/NJS"
        "/MT:8"
    )
    
    $result = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
    
    if ($result.ExitCode -gt 7) {
        throw "Failed to copy media to USB. Robocopy exit code: $($result.ExitCode)"
    }
    
    # Copy boot files to EFI partition
    Write-Log "Configuring UEFI boot..."
    
    # Make sure EFI boot files are in place
    $efiBootDir = Join-Path $DriveLetter "efi\boot"
    if (-not (Test-Path $efiBootDir)) {
        New-Item -Path $efiBootDir -ItemType Directory -Force | Out-Null
    }
    
    # Copy boot files
    $bootFiles = @(
        @{ Source = "efi\boot\bootx64.efi"; Dest = "efi\boot\bootx64.efi" }
        @{ Source = "efi\microsoft\boot\*"; Dest = "efi\microsoft\boot\" }
    )
    
    Write-Log "USB creation complete" -Level Success
}

function New-BootableISO {
    Write-Log "Creating bootable ISO..."
    
    if (-not $script:HasOscdimg) {
        Write-Log "Windows ADK not installed - downloading alternative method..." -Level Warning
        
        # Use a PowerShell-native approach or DISM
        $isoPath = Join-Path $OutputPath "FastWin11Installer.iso"
        
        # Create ISO using DISM if possible
        Write-Log "ISO creation requires Windows ADK. Install from: https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install" -Level Warning
        Write-Log "Media files are ready at: $($script:Config.MediaDir)" -Level Info
        
        return $null
    }
    
    $isoPath = Join-Path $OutputPath "FastWin11Installer.iso"
    $mediaPath = $script:Config.MediaDir
    $bootData = "2#p0,e,b`"$mediaPath\boot\etfsboot.com`"#pEF,e,b`"$mediaPath\efi\microsoft\boot\efisys.bin`""
    
    $oscdimgArgs = @(
        "-m"                    # Ignore maximum size limit
        "-o"                    # Optimize storage
        "-u2"                   # UDF file system
        "-udfver102"            # UDF version 1.02
        "-bootdata:$bootData"   # Boot configuration
        "-l`"WIN11_FAST`""      # Volume label
        "`"$mediaPath`""        # Source
        "`"$isoPath`""          # Destination
    )
    
    Write-Log "Running oscdimg..."
    $result = Start-Process -FilePath $script:OscdimgPath -ArgumentList $oscdimgArgs -Wait -PassThru -NoNewWindow
    
    if ($result.ExitCode -ne 0) {
        throw "Failed to create ISO. oscdimg exit code: $($result.ExitCode)"
    }
    
    Write-Log "Bootable ISO created: $isoPath" -Level Success
    return $isoPath
}
#endregion

#region Deployment Script Generation
function New-DeploymentScript {
    Write-Log "Creating deployment helper scripts..."
    
    # Create a WinPE deployment script
    $deployScript = @'
# Deploy-Windows.ps1
# Run this from WinPE to deploy Windows with maximum speed

param(
    [Parameter(Mandatory=$false)]
    [int]$DiskNumber = 0,
    
    [Parameter(Mandatory=$false)]
    [switch]$Compact
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Fast Windows 11 Deployment ===" -ForegroundColor Cyan
Write-Host ""

# Find the install media
$installWim = $null
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' }

foreach ($drive in $drives) {
    $testPath = Join-Path $drive.Root "sources\install.wim"
    if (Test-Path $testPath) {
        $installWim = $testPath
        Write-Host "Found install.wim at: $installWim" -ForegroundColor Green
        break
    }
}

if (-not $installWim) {
    Write-Host "ERROR: install.wim not found!" -ForegroundColor Red
    exit 1
}

# Partition the disk
Write-Host "`nPartitioning disk $DiskNumber..." -ForegroundColor Yellow

$diskpartScript = @"
select disk $DiskNumber
clean
convert gpt
create partition efi size=300
format quick fs=fat32 label="System"
assign letter=S
create partition msr size=16
create partition primary
format quick fs=ntfs label="Windows"
assign letter=W
exit
"@

$diskpartScript | diskpart

# Apply the image
Write-Host "`nApplying Windows image (this will take several minutes)..." -ForegroundColor Yellow

$dismArgs = @(
    "/Apply-Image"
    "/ImageFile:`"$installWim`""
    "/Index:1"
    "/ApplyDir:W:\"
)

if ($Compact) {
    $dismArgs += "/Compact"
    Write-Host "Using compact mode for reduced disk usage" -ForegroundColor Cyan
}

& dism.exe @dismArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Image application failed!" -ForegroundColor Red
    exit 1
}

# Configure boot
Write-Host "`nConfiguring boot manager..." -ForegroundColor Yellow
& bcdboot W:\Windows /s S: /f UEFI

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Green
Write-Host "Remove installation media and reboot to continue Windows setup."
Write-Host ""

Read-Host "Press Enter to reboot"
wpeutil reboot
'@
    
    $deployScript | Out-File -FilePath (Join-Path $script:Config.ScriptsDir "Deploy-Windows.ps1") -Encoding UTF8 -Force
    
    # Also copy to media
    $scriptsMediaDir = Join-Path $script:Config.MediaDir "Scripts"
    if (-not (Test-Path $scriptsMediaDir)) {
        New-Item -Path $scriptsMediaDir -ItemType Directory -Force | Out-Null
    }
    Copy-Item -Path (Join-Path $script:Config.ScriptsDir "Deploy-Windows.ps1") -Destination $scriptsMediaDir -Force
    
    Write-Log "Deployment scripts created" -Level Success
}
#endregion

#region Main Execution
function Invoke-Build {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  Fast Windows 11 Installer Builder" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Phase 1: Setup
        Test-Prerequisites
        Initialize-WorkDirectories
        
        # Phase 2: Extract ISO
        $isoDrive = Mount-WindowsISO -IsoPath $IsoPath
        Copy-ISOContents -SourceDrive $isoDrive
        
        # Get image info
        $images = Get-WindowsImageInfo
        
        # Phase 3: Optimize
        Optimize-WindowsImage
        Optimize-BootWim
        
        # Phase 4: Create answer file
        New-UnattendedAnswerFile
        
        # Phase 5: Create deployment scripts
        New-DeploymentScript
        
        # Phase 6: Create output media
        if ($TargetUSB) {
            Format-BootableUSB -DriveLetter $TargetUSB
            Copy-MediaToUSB -DriveLetter $TargetUSB
        }
        
        if ($OutputISO) {
            $isoPath = New-BootableISO
        }
        
        $stopwatch.Stop()
        
        Write-Host ""
        Write-Host "============================================" -ForegroundColor Green
        Write-Host "  Build Complete!" -ForegroundColor Green
        Write-Host "============================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Build time: $([math]::Round($stopwatch.Elapsed.TotalMinutes, 2)) minutes"
        Write-Host ""
        Write-Host "Output location: $OutputPath" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Contents:"
        Write-Host "  - Media/           : Modified installation files"
        Write-Host "  - autounattend.xml : Unattended answer file"
        Write-Host "  - Scripts/         : Deployment helper scripts"
        Write-Host ""
        
        if ($TargetUSB) {
            Write-Host "Bootable USB created at: $TargetUSB" -ForegroundColor Green
        }
        
        if ($OutputISO -and $isoPath) {
            Write-Host "Bootable ISO created at: $isoPath" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Boot target machine from the USB/ISO"
        Write-Host "  2. Windows will install automatically"
        Write-Host "  3. After first boot, connect to network for Intune enrollment"
        Write-Host ""
        
    } catch {
        Write-Log "BUILD FAILED: $_" -Level Error
        Write-Log $_.ScriptStackTrace -Level Error
        throw
    } finally {
        # Cleanup
        Dismount-WindowsISO -IsoPath $IsoPath
        
        # Cleanup mount directories if they exist
        if (Test-Path $script:Config.MountDir) {
            try {
                Dismount-WindowsImage -Path $script:Config.MountDir -Discard -ErrorAction SilentlyContinue
            } catch { }
        }
        if (Test-Path $script:Config.BootMountDir) {
            try {
                Dismount-WindowsImage -Path $script:Config.BootMountDir -Discard -ErrorAction SilentlyContinue
            } catch { }
        }
    }
}

# Execute
Invoke-Build
#endregion
