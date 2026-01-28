#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Quick script to create a bootable Windows 11 USB drive.

.DESCRIPTION
    Simplified script that:
    1. Mounts a Windows 11 ISO
    2. Formats a USB drive as bootable
    3. Copies all files including the autounattend.xml for unattended install

.PARAMETER IsoPath
    Path to Windows 11 ISO file.

.PARAMETER USBDrive
    Drive letter of USB drive (e.g., "E:" or "E").

.PARAMETER AnswerFile
    Optional path to custom autounattend.xml file.

.EXAMPLE
    .\Create-BootableUSB.ps1 -IsoPath "C:\ISO\Win11.iso" -USBDrive "E:"

.EXAMPLE
    .\Create-BootableUSB.ps1 -IsoPath "D:\Win11_23H2.iso" -USBDrive "F" -AnswerFile ".\custom-autounattend.xml"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$IsoPath,

    [Parameter(Mandatory = $true)]
    [string]$USBDrive,

    [Parameter(Mandatory = $false)]
    [string]$AnswerFile
)

$ErrorActionPreference = 'Stop'

# Normalize drive letter
$USBDrive = $USBDrive.TrimEnd(':').ToUpper() + ":"

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Fast Windows 11 USB Creator                   ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Validate USB drive
Write-Host "[1/5] Validating USB drive..." -ForegroundColor Yellow

$partition = Get-Partition -DriveLetter $USBDrive.TrimEnd(':') -ErrorAction SilentlyContinue
if (-not $partition) {
    throw "Drive $USBDrive not found!"
}

$diskNumber = $partition.DiskNumber
$disk = Get-Disk -Number $diskNumber

if ($disk.BusType -ne 'USB') {
    Write-Host "      WARNING: $USBDrive may not be a USB drive (BusType: $($disk.BusType))" -ForegroundColor Yellow
}

$diskSizeGB = [math]::Round($disk.Size / 1GB, 2)
Write-Host "      Found: $($disk.FriendlyName) ($diskSizeGB GB)" -ForegroundColor Green

# Confirm
Write-Host ""
Write-Host "WARNING: ALL DATA ON $USBDrive WILL BE ERASED!" -ForegroundColor Red
$confirm = Read-Host "Type 'YES' to continue"
if ($confirm -ne 'YES') {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit
}

# Format USB drive
Write-Host ""
Write-Host "[2/5] Formatting USB drive..." -ForegroundColor Yellow

# Create diskpart script with proper UEFI partitioning (EFI + Windows)
$diskpartScript = @"
select disk $diskNumber
clean
convert gpt
rem === EFI System Partition (ESP) - Required for UEFI boot ===
create partition efi size=300
format quick fs=fat32 label="System"
assign letter=S
rem === Main Windows Installation Partition ===
create partition primary
format quick fs=ntfs label="WIN11INSTALL"
assign letter=$($USBDrive.TrimEnd(':'))
exit
"@

$scriptPath = Join-Path $env:TEMP "format_usb.txt"
$diskpartScript | Out-File -FilePath $scriptPath -Encoding ASCII -Force

$result = Start-Process -FilePath "diskpart.exe" -ArgumentList "/s `"$scriptPath`"" -Wait -PassThru -NoNewWindow
Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue

if ($result.ExitCode -ne 0) {
    throw "Diskpart failed!"
}

# Wait for drive to be ready
Start-Sleep -Seconds 3
Write-Host "      USB formatted successfully" -ForegroundColor Green

# Mount ISO
Write-Host ""
Write-Host "[3/5] Mounting ISO..." -ForegroundColor Yellow

$mountResult = Mount-DiskImage -ImagePath $IsoPath -PassThru
$volume = $mountResult | Get-Volume

if (-not $volume -or -not $volume.DriveLetter) {
    Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue
    throw "Failed to mount ISO or get drive letter. Ensure the ISO file is valid."
}

$isoDrive = $volume.DriveLetter + ":"
Write-Host "      ISO mounted at $isoDrive" -ForegroundColor Green

try {
    # Copy files
    Write-Host ""
    Write-Host "[4/5] Copying files (this may take 5-10 minutes)..." -ForegroundColor Yellow
    
    # Check for large install.wim
    $installWim = Join-Path $isoDrive "sources\install.wim"
    $installEsd = Join-Path $isoDrive "sources\install.esd"
    
    $largeFile = $null
    if (Test-Path $installWim) {
        $size = (Get-Item $installWim).Length
        if ($size -gt 4GB) {
            $largeFile = $installWim
        }
    }
    
    if ($largeFile) {
        Write-Host "      Note: install.wim is > 4GB, splitting for FAT32 compatibility..." -ForegroundColor Cyan
        
        # Copy everything except install.wim first
        $robocopyArgs = @(
            "$isoDrive\"
            "$USBDrive\"
            "/E"
            "/XF"
            "install.wim"
            "/NFL"
            "/NDL"
            "/NJH"
            "/NJS"
            "/MT:8"
        )
        
        $proc = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
        
        # Split install.wim
        $destWim = Join-Path $USBDrive "sources\install.swm"
        Write-Host "      Splitting install.wim into .swm files..." -ForegroundColor Yellow
        
        $dismResult = & dism.exe /Split-Image /ImageFile:"$installWim" /SWMFile:"$destWim" /FileSize:3800
        if ($LASTEXITCODE -ne 0) {
            Write-Host "      DISM output: $dismResult" -ForegroundColor Red
            throw "Failed to split install.wim. DISM exit code: $LASTEXITCODE"
        }
        
    } else {
        # Standard copy
        $robocopyArgs = @(
            "$isoDrive\"
            "$USBDrive\"
            "/E"
            "/NFL"
            "/NDL"
            "/NJH"
            "/NJS"
            "/MT:8"
        )
        
        $proc = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
    }
    
    Write-Host "      Files copied successfully" -ForegroundColor Green
    
    # Copy autounattend.xml
    Write-Host ""
    Write-Host "[5/5] Adding unattended answer file..." -ForegroundColor Yellow
    
    $sourceAnswer = if ($AnswerFile -and (Test-Path $AnswerFile)) {
        $AnswerFile
    } else {
        # Use the one from same directory as this script
        Join-Path $PSScriptRoot "autounattend.xml"
    }
    
    if (Test-Path $sourceAnswer) {
        Copy-Item -Path $sourceAnswer -Destination (Join-Path $USBDrive "autounattend.xml") -Force
        Write-Host "      Added autounattend.xml for zero-touch install" -ForegroundColor Green
    } else {
        Write-Host "      Warning: autounattend.xml not found - install will require manual steps" -ForegroundColor Yellow
    }
    
    # Also copy the Quick-Deploy script
    $quickDeployScript = Join-Path $PSScriptRoot "Quick-Deploy.ps1"
    if (Test-Path $quickDeployScript) {
        $scriptsDir = Join-Path $USBDrive "Scripts"
        New-Item -Path $scriptsDir -ItemType Directory -Force | Out-Null
        Copy-Item -Path $quickDeployScript -Destination $scriptsDir -Force
        Write-Host "      Added Quick-Deploy.ps1 script" -ForegroundColor Green
    }
    
} finally {
    # Unmount ISO
    Write-Host ""
    Write-Host "Unmounting ISO..." -ForegroundColor Yellow
    Dismount-DiskImage -ImagePath $IsoPath | Out-Null
}

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║     USB CREATION COMPLETE! ✓                      ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Your bootable USB is ready at: $USBDrive" -ForegroundColor Cyan
Write-Host ""
Write-Host "To use:" -ForegroundColor Yellow
Write-Host "  1. Insert USB into target computer"
Write-Host "  2. Boot from USB (usually F12 or F2 at startup)"
Write-Host "  3. Windows will install automatically (unattended)"
Write-Host "  4. After reboot, connect to network for Intune enrollment"
Write-Host ""
