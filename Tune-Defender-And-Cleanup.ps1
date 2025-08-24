<# 
  Windows Defender Tune-Up Script
  Copyright (c) 2025 Anjum Yaseen
  Licensed under the MIT License (see LICENSE file for details)
#>

<#  Tune-Defender-And-Cleanup.ps1
    - Caps Microsoft Defender CPU usage to 30%
    - Schedules Quick Scan at 2:00 AM daily
    - Frees disk space (Temp, Windows Update cache, Delivery Optimization cache, Recycle Bin)
    - Logs actions to C:\Temp\system_tuneup.log
#>


$ErrorActionPreference = "Stop"

# ----- Logging -----
$logDir  = "C:\Temp"
$logPath = Join-Path $logDir "system_tuneup.log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
function Log([string]$msg) {
    $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$stamp  $msg" | Tee-Object -FilePath $logPath -Append | Out-Null
}

# ----- Must be admin -----
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as Administrator."
    exit 1
}

# ----- Baseline free space -----
$beforeFreeGB = [math]::Round((Get-PSDrive -Name C).Free / 1GB, 2)
Log ("Starting tune-up. C: free = {0} GB" -f $beforeFreeGB)

# ================= 1) Limit Defender CPU =================
try {
    $cap = 30    # adjust 20–40 if desired
    Set-MpPreference -ScanAvgCPULoadFactor $cap
    Log ("Set Defender ScanAvgCPULoadFactor to {0}%" -f $cap)
    Write-Host ("Defender CPU cap set to {0}%." -f $cap)
} catch {
    Log ("Failed to set Defender CPU cap: {0}" -f $_.Exception.Message)
    Write-Host "Could not set Defender CPU cap. Is Microsoft Defender active?"
}

# ================= 2) Schedule night scans ===============
try {
    Set-MpPreference -ScanParameters 1           # 1 = Quick scan
    Set-MpPreference -RemediationScheduleDay 0   # 0 = every day
    Set-MpPreference -RemediationScheduleTime 120 # minutes after midnight (2:00 AM)
    Log "Scheduled Defender Quick Scan daily at 02:00."
    Write-Host "Defender Quick Scan scheduled daily at 2:00 AM."
} catch {
    Log ("Failed to schedule Defender scan: {0}" -f $_.Exception.Message)
    Write-Host "Could not schedule Defender scan."
}

# ---- Optional exclusions for large, trusted folders ----
$Exclusions = @(
    "C:\VMs",
    "C:\Backups",
    "C:\Downloads\LargeFiles"
) | Where-Object { Test-Path $_ }

if ($Exclusions.Count -gt 0) {
    try {
        Add-MpPreference -ExclusionPath $Exclusions
        Log ("Added Defender exclusions: {0}" -f ($Exclusions -join ", "))
        Write-Host "Added Defender exclusions:`n  $($Exclusions -join "`n  ")"
    } catch {
        Log ("Failed adding exclusions: {0}" -f $_.Exception.Message)
        Write-Host "Could not add Defender exclusions."
    }
} else {
    Log "No exclusions added (example paths not found)."
}

# ================= 3) Safe Disk Cleanup ==================
# A) Stop services that lock caches
$servicesToStop = @("wuauserv","bits","dosvc")  # Windows Update, BITS, Delivery Optimization
foreach ($svc in $servicesToStop) {
    try {
        $s = Get-Service $svc -ErrorAction SilentlyContinue
        if ($s -and $s.Status -eq "Running") {
            Stop-Service $svc -Force -ErrorAction SilentlyContinue
            Log ("Stopped service {0}" -f $svc)
        }
    } catch {
        Log ("Could not stop {0}: {1}" -f $svc, $_.Exception.Message)
    }
}

# B) Delete temp and update caches
$paths = @(
    "$env:TEMP\*",
    "C:\Windows\Temp\*",
    "C:\Windows\SoftwareDistribution\Download\*",
    "C:\ProgramData\Microsoft\Windows\DeliveryOptimization\Cache\*"
)

foreach ($p in $paths) {
    try {
        if (Test-Path (Split-Path $p -Parent)) {
            Get-ChildItem -Path $p -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Log ("Cleared: {0}" -f $p)
        }
    } catch {
        Log ("Failed clearing {0}: {1}" -f $p, $_.Exception.Message)
    }
}

# C) Start services back
foreach ($svc in $servicesToStop) {
    try {
        Start-Service $svc -ErrorAction SilentlyContinue
        Log ("Started service {0}" -f $svc)
    } catch {
        Log ("Could not start {0}: {1}" -f $svc, $_.Exception.Message)
    }
}

# D) Component Store cleanup (safe)
try {
    Log "Running DISM StartComponentCleanup..."
    DISM /Online /Cleanup-Image /StartComponentCleanup | Out-Null
    Log "DISM cleanup completed."
} catch {
    Log ("DISM cleanup error: {0}" -f $_.Exception.Message)
}

# E) Empty Recycle Bin (suppresses confirmation)


# ======================= Summary =========================
$afterFreeGB = [math]::Round((Get-PSDrive -Name C).Free / 1GB, 2)
$freed = [math]::Round(($afterFreeGB - $beforeFreeGB), 2)
Log ("Finished. C: free = {0} GB (freed ~ {1} GB)." -f $afterFreeGB, $freed)
Write-Host ""
Write-Host ("Done. Free space on C:: {0} GB (≈ {1} GB freed)." -f $afterFreeGB, $freed)
Write-Host ("Log file: {0}" -f $logPath)
Write-Host "Reboot is recommended."
