#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Quick script to create a bootable Windows 11 USB drive.

.DESCRIPTION
    Simplified script that:
    1. Mounts a Windows 11 ISO
    2. Formats a USB drive as bootable (GPT with EFI partition)
    3. Copies all files including the autounattend.xml for unattended install

.PARAMETER IsoPath
    Path to Windows 11 ISO file.

.PARAMETER USBDrive
    Drive letter of USB drive (e.g., "E:" or "E").

.PARAMETER AnswerFile
    Optional path to custom autounattend.xml file.

.PARAMETER Debug
    Enable verbose debug logging.

.EXAMPLE
    .\Create-BootableUSB.ps1 -IsoPath "C:\ISO\Win11.iso" -USBDrive "E:"

.EXAMPLE
    .\Create-BootableUSB.ps1 -IsoPath "D:\Win11_23H2.iso" -USBDrive "F" -AnswerFile ".\custom-autounattend.xml" -Debug
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$IsoPath,

    [Parameter(Mandatory = $true)]
    [string]$USBDrive,

    [Parameter(Mandatory = $false)]
    [string]$AnswerFile,

    [Parameter(Mandatory = $false)]
    [switch]$DebugMode
)

$ErrorActionPreference = 'Stop'

#region Debug Logging
$script:LogFile = Join-Path $env:TEMP "Create-BootableUSB_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    
    # Always write to log file
    Add-Content -Path $script:LogFile -Value $logLine -ErrorAction SilentlyContinue
    
    # Write to console based on level
    $color = switch ($Level) {
        'INFO'  { 'White' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'DEBUG' { 'Gray' }
    }
    
    if ($Level -ne 'DEBUG' -or $DebugMode) {
        Write-Host "      $logLine" -ForegroundColor $color
    }
}

function Write-DebugInfo {
    param([string]$Message)
    if ($DebugMode) {
        Write-Log -Message $Message -Level DEBUG
    }
}
#endregion

# Normalize drive letter
$USBDrive = $USBDrive.TrimEnd(':').ToUpper() + ":"

# Find an available drive letter for EFI partition (avoid conflicts)
function Get-AvailableEfiDriveLetter {
    $usedLetters = (Get-Volume | Where-Object { $_.DriveLetter }).DriveLetter
    $candidates = @('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z')
    foreach ($letter in $candidates) {
        if ($letter -notin $usedLetters -and $letter -ne $USBDrive.TrimEnd(':')) {
            return $letter
        }
    }
    throw "No available drive letter found for EFI partition"
}

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Fast Windows 11 USB Creator                   ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Log "Script started. Log file: $script:LogFile" -Level INFO
Write-Log "Parameters: IsoPath=$IsoPath, USBDrive=$USBDrive" -Level DEBUG

# Validate USB drive
Write-Host "[1/5] Validating USB drive..." -ForegroundColor Yellow

Write-DebugInfo "Looking for partition with drive letter: $($USBDrive.TrimEnd(':'))"
$partition = Get-Partition -DriveLetter $USBDrive.TrimEnd(':') -ErrorAction SilentlyContinue
if (-not $partition) {
    Write-Log "Drive $USBDrive not found!" -Level ERROR
    throw "Drive $USBDrive not found!"
}

$diskNumber = $partition.DiskNumber
Write-DebugInfo "Found partition on disk number: $diskNumber"

$disk = Get-Disk -Number $diskNumber
Write-DebugInfo "Disk info: Model=$($disk.FriendlyName), Size=$($disk.Size), BusType=$($disk.BusType), PartitionStyle=$($disk.PartitionStyle)"

if ($disk.BusType -ne 'USB') {
    Write-Log "WARNING: $USBDrive may not be a USB drive (BusType: $($disk.BusType))" -Level WARN
}

$diskSizeGB = [math]::Round($disk.Size / 1GB, 2)
Write-Host "      Found: $($disk.FriendlyName) ($diskSizeGB GB)" -ForegroundColor Green

# Get EFI drive letter
$efiDriveLetter = Get-AvailableEfiDriveLetter
Write-DebugInfo "Will use drive letter '$efiDriveLetter' for EFI partition"

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
Write-DebugInfo "Creating diskpart script for GPT/UEFI partitioning"

$diskpartScript = @"
select disk $diskNumber
clean
convert gpt
rem === EFI System Partition (ESP) - Required for UEFI boot ===
create partition efi size=300
format quick fs=fat32 label="System"
assign letter=$efiDriveLetter
rem === Main Windows Installation Partition ===
create partition primary
format quick fs=ntfs label="WIN11INSTALL"
assign letter=$($USBDrive.TrimEnd(':'))
exit
"@

Write-DebugInfo "Diskpart script:`n$diskpartScript"

$scriptPath = Join-Path $env:TEMP "format_usb.txt"
$diskpartScript | Out-File -FilePath $scriptPath -Encoding ASCII -Force

Write-DebugInfo "Running diskpart..."
$result = Start-Process -FilePath "diskpart.exe" -ArgumentList "/s `"$scriptPath`"" -Wait -PassThru -NoNewWindow
Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue

Write-DebugInfo "Diskpart exit code: $($result.ExitCode)"
if ($result.ExitCode -ne 0) {
    Write-Log "Diskpart failed with exit code: $($result.ExitCode)" -Level ERROR
    throw "Diskpart failed!"
}

# Wait for drive to be ready and verify partitions
Write-DebugInfo "Waiting for drives to be ready..."
Start-Sleep -Seconds 3

# Verify both partitions exist
$efiPartitionPath = "${efiDriveLetter}:\"
$dataPartitionPath = "$USBDrive\"

Write-DebugInfo "Checking EFI partition at: $efiPartitionPath"
if (-not (Test-Path $efiPartitionPath)) {
    Write-Log "EFI partition ($efiDriveLetter`:) not accessible after formatting" -Level ERROR
    throw "EFI partition not accessible. Diskpart may have failed silently."
}

Write-DebugInfo "Checking data partition at: $dataPartitionPath"
if (-not (Test-Path $dataPartitionPath)) {
    Write-Log "Data partition ($USBDrive) not accessible after formatting" -Level ERROR
    throw "Data partition not accessible. Diskpart may have failed silently."
}

Write-Host "      USB formatted successfully (EFI: ${efiDriveLetter}:, Data: $USBDrive)" -ForegroundColor Green
Write-Log "Partitions created: EFI=${efiDriveLetter}:, Data=$USBDrive" -Level INFO

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
    
    Write-DebugInfo "Checking for install.wim at: $installWim"
    Write-DebugInfo "Checking for install.esd at: $installEsd"
    
    $largeFile = $null
    if (Test-Path $installWim) {
        $size = (Get-Item $installWim).Length
        $sizeGB = [math]::Round($size / 1GB, 2)
        Write-DebugInfo "Found install.wim, size: $sizeGB GB"
        if ($size -gt 4GB) {
            $largeFile = $installWim
            Write-Log "install.wim is > 4GB ($sizeGB GB), will need splitting for FAT32 EFI partition" -Level INFO
        }
    } elseif (Test-Path $installEsd) {
        Write-DebugInfo "Found install.esd instead of install.wim"
    } else {
        Write-Log "Neither install.wim nor install.esd found in ISO" -Level WARN
    }
    
    # Helper function to validate robocopy exit code
    function Test-RobocopySuccess {
        param([int]$ExitCode)
        # Robocopy exit codes: 0-7 = success (with various copy conditions), 8+ = error
        return $ExitCode -lt 8
    }
    
    # Copy main installation files to data partition
    Write-DebugInfo "Copying ISO contents to $USBDrive"
    
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
    
    Write-DebugInfo "Robocopy args: $($robocopyArgs -join ' ')"
    $proc = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
    
    Write-DebugInfo "Robocopy exit code: $($proc.ExitCode)"
    if (-not (Test-RobocopySuccess -ExitCode $proc.ExitCode)) {
        Write-Log "Robocopy failed with exit code: $($proc.ExitCode)" -Level ERROR
        throw "Failed to copy files to USB. Robocopy exit code: $($proc.ExitCode)"
    }
    
    Write-Host "      Main files copied" -ForegroundColor Green
    
    # Copy EFI boot files to EFI partition for UEFI boot
    Write-Host "      Copying EFI boot files..." -ForegroundColor Yellow
    Write-DebugInfo "Copying EFI boot files to ${efiDriveLetter}:"
    
    $efiSourceDir = Join-Path $isoDrive "efi"
    $efiDestDir = "${efiDriveLetter}:\efi"
    
    if (Test-Path $efiSourceDir) {
        Write-DebugInfo "Copying $efiSourceDir to $efiDestDir"
        
        $efiRobocopyArgs = @(
            "$efiSourceDir"
            "$efiDestDir"
            "/E"
            "/NFL"
            "/NDL"
            "/NJH"
            "/NJS"
        )
        
        $efiProc = Start-Process -FilePath "robocopy.exe" -ArgumentList $efiRobocopyArgs -Wait -PassThru -NoNewWindow
        Write-DebugInfo "EFI robocopy exit code: $($efiProc.ExitCode)"
        
        if (-not (Test-RobocopySuccess -ExitCode $efiProc.ExitCode)) {
            Write-Log "Failed to copy EFI files. Exit code: $($efiProc.ExitCode)" -Level ERROR
            throw "Failed to copy EFI boot files"
        }
    } else {
        Write-Log "EFI directory not found in ISO at: $efiSourceDir" -Level WARN
    }
    
    # Also copy boot directory to EFI partition (needed for some UEFI implementations)
    $bootSourceDir = Join-Path $isoDrive "boot"
    $bootDestDir = "${efiDriveLetter}:\boot"
    
    if (Test-Path $bootSourceDir) {
        Write-DebugInfo "Copying $bootSourceDir to $bootDestDir"
        
        $bootRobocopyArgs = @(
            "$bootSourceDir"
            "$bootDestDir"
            "/E"
            "/NFL"
            "/NDL"
            "/NJH"
            "/NJS"
        )
        
        $bootProc = Start-Process -FilePath "robocopy.exe" -ArgumentList $bootRobocopyArgs -Wait -PassThru -NoNewWindow
        Write-DebugInfo "Boot robocopy exit code: $($bootProc.ExitCode)"
    }
    
    Write-Host "      EFI boot files copied" -ForegroundColor Green
    Write-Log "All files copied successfully" -Level INFO
    
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
