#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$ServerXml = '\\retail\applications\SAP\SAPUILandscapeOnServer.xml'
$RegNative = 'HKLM:\SOFTWARE\SAP\SAPLogon\Options'
$RegWow    = 'HKLM:\SOFTWARE\WOW6432Node\SAP\SAPLogon\Options'
$ValName   = 'LandscapeFileOnServer'
$Fixed     = @()
$Issues    = @()

Write-Host "`n=== SAP GUI Diagnostic & Remediation Tool ===" -ForegroundColor Cyan

# --- 1. Server XML reachability ---
Write-Host "`n[1] Server XML reachability" -ForegroundColor Yellow
$serverReachable = Test-Path $ServerXml
if ($serverReachable) {
    Write-Host "    OK: $ServerXml exists and is reachable" -ForegroundColor Green
} else {
    Write-Host "    FAIL: $ServerXml not found or not reachable" -ForegroundColor Red
    $Issues += "Server XML unreachable - check network/DFS/permissions"
}

# --- 2. Registry - native 64-bit hive ---
Write-Host "`n[2] Registry: native hive ($RegNative)" -ForegroundColor Yellow
$nativeVal = try { (Get-ItemProperty -Path $RegNative -Name $ValName -ErrorAction Stop).$ValName } catch { $null }

if ($nativeVal -eq $ServerXml) {
    Write-Host "    OK: $ValName = $nativeVal" -ForegroundColor Green
} elseif ($nativeVal) {
    Write-Host "    WRONG: $ValName = $nativeVal (expected $ServerXml)" -ForegroundColor Red
    Set-ItemProperty -Path $RegNative -Name $ValName -Value $ServerXml
    Write-Host "    FIXED: updated to $ServerXml" -ForegroundColor Green
    $Fixed += "Corrected native registry value"
} else {
    Write-Host "    MISSING: $ValName not set" -ForegroundColor Red
    if (-not (Test-Path $RegNative)) { New-Item -Path $RegNative -Force | Out-Null }
    New-ItemProperty -Path $RegNative -Name $ValName -Value $ServerXml -PropertyType String -Force | Out-Null
    Write-Host "    FIXED: created $ValName = $ServerXml" -ForegroundColor Green
    $Fixed += "Created native registry value"
}

# --- 3. Registry - WOW6432Node (remove stale 32-bit) ---
Write-Host "`n[3] Registry: WOW6432Node ($RegWow)" -ForegroundColor Yellow
$wowVal = try { (Get-ItemProperty -Path $RegWow -Name $ValName -ErrorAction Stop).$ValName } catch { $null }

if (-not $wowVal) {
    Write-Host "    OK: no 32-bit landscape value (clean)" -ForegroundColor Green
} elseif ($wowVal -eq $ServerXml) {
    Write-Host "    STALE: value matches but 32-bit hive is legacy - removing" -ForegroundColor DarkYellow
    Remove-ItemProperty -Path $RegWow -Name $ValName -ErrorAction SilentlyContinue
    Write-Host "    FIXED: removed 32-bit landscape registry value" -ForegroundColor Green
    $Fixed += "Removed legacy WOW6432Node landscape value"
} else {
    Write-Host "    STALE: $ValName = $wowVal - removing" -ForegroundColor DarkYellow
    Remove-ItemProperty -Path $RegWow -Name $ValName -ErrorAction SilentlyContinue
    Write-Host "    FIXED: removed stale 32-bit landscape registry value" -ForegroundColor Green
    $Fixed += "Removed stale WOW6432Node landscape value"
}

# --- 4. Per-user local landscape ---
Write-Host "`n[4] Per-user landscape: %APPDATA%\SAP\Common" -ForegroundColor Yellow
$userXml = Join-Path $env:APPDATA 'SAP\Common\SAPUILandscape.xml'

if (Test-Path $userXml) {
    $content = Get-Content $userXml -Raw
    if ($content -match [regex]::Escape($ServerXml)) {
        Write-Host "    OK: references server XML" -ForegroundColor Green
    } else {
        Write-Host "    STALE: does not reference $ServerXml - deleting for regeneration" -ForegroundColor Red
        Remove-Item $userXml -Force
        Write-Host "    FIXED: removed stale per-user landscape XML" -ForegroundColor Green
        $Fixed += "Deleted stale per-user SAPUILandscape.xml (will regenerate on next launch)"
    }
} else {
    Write-Host "    ABSENT: will be created on next SAP GUI launch" -ForegroundColor DarkGray
}

# --- 5. Global landscape ---
Write-Host "`n[5] Global landscape: Program Files" -ForegroundColor Yellow
$globalPaths = @(
    (Join-Path $env:ProgramFiles 'SAP\SAPsetup\SAPUILandscapeGlobal.xml'),
    (Join-Path ${env:ProgramFiles(x86)} 'SAP\SAPsetup\SAPUILandscapeGlobal.xml')
)
$foundGlobal = $false
foreach ($gp in $globalPaths) {
    if (Test-Path $gp) {
        Write-Host "    FOUND: $gp" -ForegroundColor Green
        $foundGlobal = $true
    }
}
if (-not $foundGlobal) {
    Write-Host "    ABSENT: no global landscape file (not critical if registry is correct)" -ForegroundColor DarkGray
}

# --- 6. Orphaned 32-bit install remnants ---
Write-Host "`n[6] Orphaned 32-bit install check" -ForegroundColor Yellow
$x86Sap = Join-Path ${env:ProgramFiles(x86)} 'SAP\FrontEnd\SAPgui'
$x64Sap = Join-Path $env:ProgramFiles 'SAP\FrontEnd\SAPgui'

if ((Test-Path $x86Sap) -and (Test-Path $x64Sap)) {
    Write-Host "    WARNING: both x86 and x64 SAPgui dirs exist - leftover 32-bit files" -ForegroundColor Red
    $Issues += "Orphaned 32-bit SAPgui folder at $x86Sap - may confuse shortcuts/COM registration"
} elseif (Test-Path $x64Sap) {
    Write-Host "    OK: only 64-bit install present" -ForegroundColor Green
} elseif (Test-Path $x86Sap) {
    Write-Host "    WRONG: only 32-bit install found - 64-bit install may have failed" -ForegroundColor Red
    $Issues += "No 64-bit SAPgui folder found"
} else {
    Write-Host "    MISSING: no SAPgui folder found at all" -ForegroundColor Red
    $Issues += "SAP GUI not found in either Program Files location"
}

# --- 7. SAP GUI version & architecture ---
Write-Host "`n[7] SAP GUI version & architecture" -ForegroundColor Yellow
$uninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$sapEntries = foreach ($up in $uninstallPaths) {
    try {
        Get-ItemProperty -Path $up -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match 'SAP GUI|SAP Logon|SAP Business Client' }
    } catch { }
}

if ($sapEntries) {
    foreach ($entry in $sapEntries) {
        $arch = if ($entry.PSPath -match 'WOW6432Node') { 'x86' } else { 'x64' }
        $ver  = if ($entry.DisplayVersion) { $entry.DisplayVersion } else { 'unknown' }
        $loc  = if ($entry.InstallLocation) { $entry.InstallLocation } else { 'N/A' }
        $color = if ($arch -eq 'x86') { 'Red' } else { 'Green' }
        Write-Host "    $($entry.DisplayName) - v$ver ($arch)" -ForegroundColor $color
        Write-Host "      Install: $loc" -ForegroundColor DarkGray
        if ($arch -eq 'x86') {
            $Issues += "32-bit SAP component installed: $($entry.DisplayName) v$ver"
        }
    }
} else {
    Write-Host "    NO SAP GUI entries found in uninstall registry" -ForegroundColor Red
    $Issues += "No SAP GUI found in Windows uninstall registry"
}

# --- 8. Shortcut & COM registration ---
Write-Host "`n[8] Shortcut & COM registration" -ForegroundColor Yellow
$saplogonExe = $null
$searchPaths = @(
    (Join-Path $env:ProgramFiles 'SAP\FrontEnd\SAPgui\saplogon.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'SAP\FrontEnd\SAPgui\saplogon.exe')
)
foreach ($sp in $searchPaths) {
    if (Test-Path $sp) {
        $isX86 = $sp -match [regex]::Escape(${env:ProgramFiles(x86)})
        $color = if ($isX86) { 'Red' } else { 'Green' }
        $arch  = if ($isX86) { 'x86' } else { 'x64' }
        Write-Host "    saplogon.exe: $sp ($arch)" -ForegroundColor $color
        if (-not $isX86) { $saplogonExe = $sp }
        if ($isX86 -and -not $saplogonExe) { $saplogonExe = $sp }
    }
}
if (-not $saplogonExe) {
    Write-Host "    saplogon.exe NOT FOUND" -ForegroundColor Red
    $Issues += "saplogon.exe not found in expected locations"
}

$comKeys = @(
    'HKLM:\SOFTWARE\Classes\SAP.Functions',
    'HKLM:\SOFTWARE\Classes\SAP.Functions.1',
    'HKLM:\SOFTWARE\Classes\CLSID\{A6CF3711-E36D-11D3-A978-0050DA712658}'
)
$comFound = $false
foreach ($ck in $comKeys) {
    if (Test-Path $ck) {
        $comFound = $true
        $inproc = try { (Get-ItemProperty "$ck\InprocServer32" -ErrorAction Stop).'(default)' } catch { $null }
        if ($inproc) {
            $comArch = if ($inproc -match 'x86|WOW6432Node|Program Files \(x86\)') { 'x86' } else { 'x64' }
            Write-Host "    COM $($ck.Split('\')[-1]): $inproc ($comArch)" -ForegroundColor $(if ($comArch -eq 'x86') { 'DarkYellow' } else { 'Green' })
        }
    }
}
if (-not $comFound) {
    Write-Host "    No SAP COM registrations found (may be normal if SAP scripting not enabled)" -ForegroundColor DarkGray
}

# --- 9. SAP-related processes ---
Write-Host "`n[9] SAP-related processes" -ForegroundColor Yellow
$sapProcs = Get-Process -Name saplogon, saplgpad, sapshcut -ErrorAction SilentlyContinue

if ($sapProcs) {
    foreach ($p in $sapProcs) {
        $path = try { $p.Path } catch { 'N/A' }
        $isX86 = $path -match [regex]::Escape(${env:ProgramFiles(x86)})
        $color = if ($isX86) { 'DarkYellow' } else { 'Green' }
        Write-Host "    $($p.Name) (PID $($p.Id)): $path" -ForegroundColor $color
        if ($isX86) {
            $Issues += "$($p.Name) running from x86 path - may need restart after fix"
        }
    }
} else {
    Write-Host "    No SAP processes running" -ForegroundColor DarkGray
}

# --- 10. Network connectivity to landscape servers ---
Write-Host "`n[10] Network connectivity to landscape servers" -ForegroundColor Yellow
if ($serverReachable) {
    try {
        [xml]$xml = Get-Content $ServerXml -Raw
        $services = $xml.SelectNodes('//*[local-name()="Service"]')
        $routers  = $xml.SelectNodes('//*[local-name()="Router"]')
        $hosts = @()
        foreach ($svc in $services) {
            $h = if ($svc.server) { $svc.server } elseif ($svc.host) { $svc.host } else { $null }
            $sysNr = if ($svc.systemNumber) { $svc.systemNumber } elseif ($svc.systemnr) { $svc.systemnr } else { '00' }
            if ($h) { $hosts += @{ Host = $h; Port = 3200 + [int]$sysNr } }
        }
        foreach ($r in $routers) {
            if ($r.router -match '/H/([^/]+)') { $hosts += @{ Host = $matches[1]; Port = 3299 } }
        }

        $msgServers = $xml.SelectNodes('//*[local-name()="MessageServer"]')
        foreach ($ms in $msgServers) {
            $h = if ($ms.host) { $ms.host } elseif ($ms.server) { $ms.server } else { $null }
            $p = if ($ms.port) { [int]$ms.port } else { 3600 }
            if ($h) { $hosts += @{ Host = $h; Port = $p } }
        }

        if ($hosts.Count -eq 0) {
            Write-Host "    No server entries parsed from landscape XML" -ForegroundColor DarkGray
        } else {
            $tested = @{}
            foreach ($target in $hosts) {
                $key = "$($target.Host):$($target.Port)"
                if ($tested.ContainsKey($key)) { continue }
                $tested[$key] = $true
                try {
                    $tcp = New-Object System.Net.Sockets.TcpClient
                    $result = $tcp.BeginConnect($target.Host, $target.Port, $null, $null)
                    $wait = $result.AsyncWaitHandle.WaitOne(2000, $false)
                    if ($wait -and $tcp.Connected) {
                        Write-Host "    OK: $key reachable" -ForegroundColor Green
                    } else {
                        Write-Host "    FAIL: $key unreachable (timeout)" -ForegroundColor Red
                        $Issues += "SAP server $key unreachable"
                    }
                    $tcp.Close()
                } catch {
                    Write-Host "    FAIL: $key - $($_.Exception.Message)" -ForegroundColor Red
                    $Issues += "SAP server $key connection error"
                }
            }
        }
    } catch {
        Write-Host "    ERROR: failed to parse landscape XML - $($_.Exception.Message)" -ForegroundColor Red
        $Issues += "Could not parse server landscape XML for connectivity test"
    }
} else {
    Write-Host "    SKIPPED: server XML not reachable (see check 1)" -ForegroundColor DarkGray
}

# --- Summary ---
Write-Host "`n=== Summary (10 checks) ===" -ForegroundColor Cyan
if ($Fixed.Count) {
    Write-Host "Fixed:" -ForegroundColor Green
    $Fixed | ForEach-Object { Write-Host "  + $_" -ForegroundColor Green }
}
if ($Issues.Count) {
    Write-Host "Remaining issues:" -ForegroundColor Red
    $Issues | ForEach-Object { Write-Host "  ! $_" -ForegroundColor Red }
} elseif (-not $Fixed.Count) {
    Write-Host "No issues found." -ForegroundColor Green
}
if ($Fixed.Count) {
    Write-Host "Relaunch SAP Logon to verify." -ForegroundColor Cyan
}
Write-Host ""
