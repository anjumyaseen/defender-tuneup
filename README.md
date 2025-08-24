# Windows Defender Tune-Up (PowerShell)

Limit Microsoft Defender's CPU usage, schedule scans for off-hours, and safely free disk space (temp + update caches + recycle bin).  
Designed for older laptops/desktops that peg CPU at 100% due to `Antimalware Service Executable (MsMpEng.exe)`.

> ⚠️ Run on your own computer at your own risk. The script **keeps Defender enabled** and only tunes it.

## What it does

- Sets Defender CPU cap (default **30%**) via `Set-MpPreference -ScanAvgCPULoadFactor`
- Schedules a **Quick Scan at 2:00 AM daily**
- Cleans:
  - `%TEMP%`, `C:\Windows\Temp`
  - `C:\Windows\SoftwareDistribution\Download` (Windows Update cache)
  - `C:\ProgramData\Microsoft\Windows\DeliveryOptimization\Cache`
  - Empties Recycle Bin
- Logs to `C:\Temp\system_tuneup.log`

## Usage

1. Open **PowerShell as Administrator**
2. (One-time in this session)
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
   
## License
MIT © 2025 Anjum Yaseen  
See [LICENSE](LICENSE.txt) for details.


