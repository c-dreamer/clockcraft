# Removes ClockCraft for the current user. Usage: irm https://raw.githubusercontent.com/c-dreamer/clockcraft/main/uninstall.ps1 | iex
Get-Process DualClock -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'ClockCraft' -ErrorAction SilentlyContinue
Remove-Item (Join-Path ([Environment]::GetFolderPath('Desktop')) 'ClockCraft.lnk') -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:LOCALAPPDATA 'ClockCraft') -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:APPDATA 'DualClock') -Recurse -Force -ErrorAction SilentlyContinue
Write-Host 'ClockCraft removed.'
