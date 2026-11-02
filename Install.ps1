<#
.SYNOPSIS
    Per-user install: copies DualClock.ps1 to %LOCALAPPDATA%\DualClock, adds a Startup shortcut, launches it.
    No admin rights required.
#>
$ErrorActionPreference = 'Stop'
$dest = Join-Path $env:LOCALAPPDATA 'DualClock'
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'DualClock.ps1') -Destination $dest -Force

$script = Join-Path $dest 'DualClock.ps1'
$args_  = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
$lnk    = Join-Path ([Environment]::GetFolderPath('Startup')) 'DualClock.lnk'

$shell = New-Object -ComObject WScript.Shell
$sc = $shell.CreateShortcut($lnk)
$sc.TargetPath       = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$sc.Arguments        = $args_
$sc.WorkingDirectory = $dest
$sc.WindowStyle      = 7   # minimized
$sc.Description      = 'SAST / Boise / Manila clock'
$sc.Save()

Start-Process -FilePath $sc.TargetPath -ArgumentList $args_ -WindowStyle Hidden
Write-Host "Installed to $dest; Startup shortcut: $lnk"
