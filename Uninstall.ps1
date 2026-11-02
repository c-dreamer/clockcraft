$ErrorActionPreference = 'SilentlyContinue'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object CommandLine -like '*DualClock.ps1*' |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Remove-Item (Join-Path ([Environment]::GetFolderPath('Startup')) 'DualClock.lnk') -Force
Remove-Item (Join-Path $env:LOCALAPPDATA 'DualClock') -Recurse -Force
Remove-Item (Join-Path $env:APPDATA 'DualClock') -Recurse -Force
Write-Host 'DualClock removed.'
