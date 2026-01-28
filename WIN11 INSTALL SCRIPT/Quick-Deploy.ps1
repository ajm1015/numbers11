#Requires -Version 5.1
<#
.SYNOPSIS
    Ultra-fast Windows 11 deployment script for WinPE environments.

.DESCRIPTION
    This script is designed to be run from WinPE for maximum deployment speed.
    It handles disk partitioning, image application, and boot configuration
    in a single streamlined process.

.PARAMETER DiskNumber
    Target disk number (default: 0). Use Get-Disk to list available disks.

.PARAMETER ImageIndex
    Windows edition index (default: 1). Use Get-WindowsImage to list available editions.

.PARAMETER Compact
    Apply image in compact mode to reduce disk space usage.

.PARAMETER NoReboot
    Don't automatically reboot after deployment.

.PARAMETER WipeDisk
    Skip confirmation prompt for disk wipe (DANGEROUS - use with caution).

.EXAMPLE
    # Standard deployment
    .\Quick-Deploy.ps1

.EXAMPLE
    # Deploy to disk 1 with compact mode
    .\Quick-Deploy.ps1 -DiskNumber 1 -Compact

.EXAMPLE
    # Automated deployment (no prompts)
    .\Quick-Deploy.ps1 -WipeDisk -NoReboot

.NOTES
    Run this script from WinPE after booting from the USB/ISO created by Build-FastWin11Installer.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$DiskNumber = 0,

    [Parameter(Mandatory = $false)]
    [int]$ImageIndex = 1,

    [Parameter(Mandatory = $false)]
    [switch]$Compact,

    [Parameter(Mandatory = $false)]
    [switch]$NoReboot,

    [Parameter(Mandatory = $false)]
    [switch]$WipeDisk
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

#region Banner
function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                                          ║" -ForegroundColor Cyan
    Write-Host "  ║       ⚡ FAST WINDOWS 11 DEPLOYMENT ⚡                  ║" -ForegroundColor Cyan
    Write-Host "  ║                                                          ║" -ForegroundColor Cyan
    Write-Host "  ║       Optimized for speed • Zero-touch install           ║" -ForegroundColor Cyan
    Write-Host "  ║                                                          ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}
#endregion

#region Logging
function Write-Step {
    param([string]$Message, [string]$Status = "INFO")
    
    $color = switch ($Status) {
        "INFO"    { "White" }
        "OK"      { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "WORKING" { "Cyan" }
    }
    
    $prefix = switch ($Status) {
        "INFO"    { "[i]" }
        "OK"      { "[✓]" }
        "WARN"    { "[!]" }
        "ERROR"   { "[✗]" }
        "WORKING" { "[>]" }
    }
    
    Write-Host "  $prefix $Message" -ForegroundColor $color
}

function Write-Progress-Bar {
    param(
        [int]$PercentComplete,
        [string]$Activity
    )
    
    $width = 40
    $filled = [math]::Floor($width * $PercentComplete / 100)
    $empty = $width - $filled
    
    $bar = "█" * $filled + "░" * $empty
    
    Write-Host "`r  [$bar] $PercentComplete% - $Activity" -NoNewline -ForegroundColor Cyan
}
#endregion

#region Disk Operations
function Find-InstallMedia {
    Write-Step "Searching for installation media..." -Status WORKING
    
    # Get all available drive letters
    $drives = @('D', 'E', 'F', 'G', 'H', 'I', 'X', 'Y', 'Z')
    
    foreach ($drive in $drives) {
        $wimPath = "${drive}:\sources\install.wim"
        $esdPath = "${drive}:\sources\install.esd"
        
        if (Test-Path $wimPath) {
            Write-Step "Found install.wim at $wimPath" -Status OK
            return @{
                Path = $wimPath
                Drive = "${drive}:"
                Type = "WIM"
            }
        }
        
        if (Test-Path $esdPath) {
            Write-Step "Found install.esd at $esdPath" -Status OK
            return @{
                Path = $esdPath
                Drive = "${drive}:"
                Type = "ESD"
            }
        }
    }
    
    throw "Installation media not found! Ensure USB/ISO is connected."
}

function Get-DiskInfo {
    param([int]$DiskNumber)
    
    Write-Step "Getting disk information..." -Status WORKING
    
    # Try WMI first (works in most WinPE)
    try {
        $disk = Get-CimInstance -ClassName Win32_DiskDrive | Where-Object { $_.Index -eq $DiskNumber }
        
        if ($disk) {
            $sizeGB = [math]::Round($disk.Size / 1GB, 2)
            return @{
                Number = $DiskNumber
                Model = $disk.Model
                Size = $sizeGB
                SizeBytes = $disk.Size
            }
        }
    } catch {
        # Fallback to diskpart
    }
    
    # Fallback: use diskpart
    $diskpartScript = "list disk"
    $diskpartScript | Out-File -FilePath "$env:TEMP\diskinfo.txt" -Encoding ASCII
    $output = & diskpart /s "$env:TEMP\diskinfo.txt" 2>&1
    
    return @{
        Number = $DiskNumber
        Model = "Unknown"
        Size = "Unknown"
    }
}

function Initialize-TargetDisk {
    param([int]$DiskNumber)
    
    Write-Step "Initializing disk $DiskNumber (GPT/UEFI)..." -Status WORKING
    
    $diskpartCommands = @"
select disk $DiskNumber
clean
convert gpt
rem === EFI System Partition (ESP) ===
create partition efi size=300
format quick fs=fat32 label="System"
assign letter=S
rem === Microsoft Reserved Partition ===
create partition msr size=16
rem === Windows Partition ===
create partition primary
format quick fs=ntfs label="Windows"
assign letter=W
exit
"@
    
    $scriptPath = "$env:TEMP\partition.txt"
    $diskpartCommands | Out-File -FilePath $scriptPath -Encoding ASCII -Force
    
    $result = & diskpart /s $scriptPath 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Step "Diskpart output: $result" -Status ERROR
        throw "Disk partitioning failed!"
    }
    
    # Verify partitions
    Start-Sleep -Seconds 2
    
    if (-not (Test-Path "W:\")) {
        throw "Windows partition (W:) not available after partitioning!"
    }
    
    if (-not (Test-Path "S:\")) {
        throw "System partition (S:) not available after partitioning!"
    }
    
    Write-Step "Disk partitioned successfully" -Status OK
}
#endregion

#region Image Application
function Apply-WindowsImage {
    param(
        [hashtable]$Media,
        [int]$ImageIndex,
        [switch]$Compact
    )
    
    Write-Step "Applying Windows image (this is the longest step)..." -Status WORKING
    Write-Host ""
    
    $applyArgs = @(
        "/Apply-Image"
        "/ImageFile:`"$($Media.Path)`""
        "/Index:$ImageIndex"
        "/ApplyDir:W:\"
    )
    
    if ($Compact) {
        $applyArgs += "/Compact"
        Write-Step "Using compact mode (slower but saves disk space)" -Status INFO
    }
    
    # Run DISM with progress
    $startTime = Get-Date
    
    # Start DISM process
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "dism.exe"
    $pinfo.Arguments = $applyArgs -join " "
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $pinfo
    
    # Capture output
    $outputBuilder = New-Object System.Text.StringBuilder
    
    $process.Start() | Out-Null
    
    # Monitor progress
    $lastPercent = 0
    while (-not $process.HasExited) {
        $line = $process.StandardOutput.ReadLine()
        if ($null -ne $line) {
            if ($line -match '(\d+(\.\d+)?)\s*%') {
                $percent = [int][math]::Floor([double]$matches[1])
                if ($percent -ne $lastPercent) {
                    $elapsed = (Get-Date) - $startTime
                    $elapsedStr = "{0:mm\:ss}" -f $elapsed
                    Write-Progress-Bar -PercentComplete $percent -Activity "Elapsed: $elapsedStr"
                    $lastPercent = $percent
                }
            }
            [void]$outputBuilder.AppendLine($line)
        }
    }
    
    # Get remaining output
    $remaining = $process.StandardOutput.ReadToEnd()
    [void]$outputBuilder.Append($remaining)
    
    $stderr = $process.StandardError.ReadToEnd()
    
    Write-Host "" # New line after progress bar
    
    if ($process.ExitCode -ne 0) {
        Write-Step "DISM Error: $stderr" -Status ERROR
        Write-Step "DISM Output: $($outputBuilder.ToString())" -Status ERROR
        throw "Image application failed! Exit code: $($process.ExitCode)"
    }
    
    $duration = (Get-Date) - $startTime
    Write-Step "Image applied in $("{0:mm\:ss}" -f $duration)" -Status OK
}
#endregion

#region Boot Configuration
function Configure-BootManager {
    Write-Step "Configuring UEFI boot manager..." -Status WORKING
    
    # Run bcdboot to configure boot files
    $result = & bcdboot W:\Windows /s S: /f UEFI 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Step "BCDBoot output: $result" -Status ERROR
        throw "Boot configuration failed!"
    }
    
    Write-Step "Boot manager configured" -Status OK
}
#endregion

#region Main
function Invoke-Deployment {
    $totalTimer = [System.Diagnostics.Stopwatch]::StartNew()
    
    Show-Banner
    
    try {
        # Step 1: Find media
        $media = Find-InstallMedia
        
        # Step 2: Get disk info
        $diskInfo = Get-DiskInfo -DiskNumber $DiskNumber
        
        Write-Host ""
        Write-Host "  ┌─────────────────────────────────────────┐" -ForegroundColor DarkGray
        Write-Host "  │ Target Disk: $DiskNumber ($($diskInfo.Model))" -ForegroundColor DarkGray
        Write-Host "  │ Disk Size:   $($diskInfo.Size) GB" -ForegroundColor DarkGray
        Write-Host "  │ Image:       $($media.Path)" -ForegroundColor DarkGray
        Write-Host "  │ Compact:     $($Compact.IsPresent)" -ForegroundColor DarkGray
        Write-Host "  └─────────────────────────────────────────┘" -ForegroundColor DarkGray
        Write-Host ""
        
        # Step 3: Confirm disk wipe
        if (-not $WipeDisk) {
            Write-Host "  ⚠️  WARNING: ALL DATA ON DISK $DiskNumber WILL BE ERASED!" -ForegroundColor Red
            Write-Host ""
            $confirm = Read-Host "  Type 'YES' to continue"
            if ($confirm -ne "YES") {
                Write-Step "Deployment cancelled by user" -Status WARN
                return
            }
            Write-Host ""
        }
        
        # Step 4: Partition disk
        $partitionTimer = [System.Diagnostics.Stopwatch]::StartNew()
        Initialize-TargetDisk -DiskNumber $DiskNumber
        $partitionTimer.Stop()
        
        # Step 5: Apply image
        $imageTimer = [System.Diagnostics.Stopwatch]::StartNew()
        Apply-WindowsImage -Media $media -ImageIndex $ImageIndex -Compact:$Compact
        $imageTimer.Stop()
        
        # Step 6: Configure boot
        $bootTimer = [System.Diagnostics.Stopwatch]::StartNew()
        Configure-BootManager
        $bootTimer.Stop()
        
        $totalTimer.Stop()
        
        # Summary
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "  ║              DEPLOYMENT COMPLETE! ✓                      ║" -ForegroundColor Green
        Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Timing Summary:" -ForegroundColor Cyan
        Write-Host "    Partitioning:    $("{0:mm\:ss}" -f $partitionTimer.Elapsed)"
        Write-Host "    Image Apply:     $("{0:mm\:ss}" -f $imageTimer.Elapsed)"
        Write-Host "    Boot Config:     $("{0:mm\:ss}" -f $bootTimer.Elapsed)"
        Write-Host "    ─────────────────────────"
        Write-Host "    Total Time:      $("{0:mm\:ss}" -f $totalTimer.Elapsed)" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Next Steps:" -ForegroundColor Yellow
        Write-Host "    1. Remove installation media"
        Write-Host "    2. Reboot the system"
        Write-Host "    3. Windows will complete setup"
        Write-Host "    4. Connect to network for Intune enrollment"
        Write-Host ""
        
        if (-not $NoReboot) {
            Write-Host "  System will reboot in 10 seconds..." -ForegroundColor Yellow
            Write-Host "  Press Ctrl+C to cancel" -ForegroundColor DarkGray
            
            for ($i = 10; $i -gt 0; $i--) {
                Write-Host "`r  Rebooting in $i seconds...  " -NoNewline -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
            
            Write-Host ""
            
            # Try WinPE reboot first, then standard
            try {
                & wpeutil reboot
            } catch {
                Restart-Computer -Force
            }
        }
        
    } catch {
        Write-Host ""
        Write-Step "DEPLOYMENT FAILED: $_" -Status ERROR
        Write-Host ""
        Write-Host "  Error Details:" -ForegroundColor Red
        Write-Host "  $($_.ScriptStackTrace)" -ForegroundColor DarkRed
        Write-Host ""
        
        throw
    }
}

# Execute
Invoke-Deployment
#endregion
