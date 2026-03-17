<#
.SYNOPSIS
    Scans network shares for Excel files and exports a triage list sorted by size.

.DESCRIPTION
    Recurses one or more UNC paths for .xls/.xlsx/.xlsm/.xlsb files.
    Exports: Path, SizeMB, LastModified, Owner, Extension.
    Output CSV is sorted descending by size — worst offenders first.

.PARAMETER SharePaths
    One or more UNC paths or local directories to scan.

.PARAMETER OutputPath
    CSV output path. Defaults to .\ExcelTriage_<timestamp>.csv in script directory.

.PARAMETER MinSizeMB
    Minimum file size in MB to include. Default 1 MB. Set to 0 for all files.

.EXAMPLE
    .\Scan-ExcelShares.ps1 -SharePaths "\\fileserver01\shared","\\fileserver02\dept"
    .\Scan-ExcelShares.ps1 -SharePaths "\\fileserver01\shared" -MinSizeMB 5

.NOTES
    Exit Codes:
        0 = Success
        1 = No share paths provided
        2 = No accessible shares found
        3 = No Excel files found matching criteria
#>

#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

param(
    [Parameter(Mandatory)]
    [string[]]$SharePaths,

    [string]$OutputPath,

    [double]$MinSizeMB = 1
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if (-not $OutputPath) { $OutputPath = Join-Path $ScriptDir "ExcelTriage_$Timestamp.csv" }

$ExcelExtensions = @('.xls', '.xlsx', '.xlsm', '.xlsb')
$MinSizeBytes = [math]::Floor($MinSizeMB * 1MB)

# Validate at least one share is reachable
$AccessibleShares = $SharePaths | Where-Object { Test-Path $_ }
if (-not $AccessibleShares) {
    Write-Error "None of the provided share paths are accessible: $($SharePaths -join ', ')"
    exit 2
}

$Inaccessible = $SharePaths | Where-Object { $_ -notin $AccessibleShares }
if ($Inaccessible) {
    Write-Warning "Skipping inaccessible paths: $($Inaccessible -join ', ')"
}

Write-Host "Scanning $($AccessibleShares.Count) share(s) for Excel files >= $MinSizeMB MB..." -ForegroundColor Cyan

$Results = [System.Collections.Generic.List[PSObject]]::new()

foreach ($Share in $AccessibleShares) {
    Write-Host "  Scanning: $Share" -ForegroundColor Gray
    try {
        Get-ChildItem -Path $Share -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in $ExcelExtensions -and $_.Length -ge $MinSizeBytes } |
            ForEach-Object {
                $Owner = try {
                    (Get-Acl $_.FullName).Owner
                } catch { 'UNKNOWN' }

                $Results.Add([PSCustomObject]@{
                    Path         = $_.FullName
                    SizeMB       = [math]::Round($_.Length / 1MB, 2)
                    LastModified = $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
                    Owner        = $Owner
                    Extension    = $_.Extension
                })
            }
    } catch {
        Write-Warning "Error scanning ${Share}: $_"
    }
}

if ($Results.Count -eq 0) {
    Write-Warning "No Excel files found matching criteria (>= $MinSizeMB MB)."
    exit 3
}

$Sorted = $Results | Sort-Object SizeMB -Descending
$Sorted | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

Write-Host "`nResults:" -ForegroundColor Green
Write-Host "  Files found : $($Results.Count)"
Write-Host "  Total size  : $([math]::Round(($Results | Measure-Object SizeMB -Sum).Sum, 2)) MB"
Write-Host "  Largest     : $($Sorted[0].SizeMB) MB - $($Sorted[0].Path)"
Write-Host "  Output      : $OutputPath"

exit 0
