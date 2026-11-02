# ClockCraft installer: downloads the source, builds DualClock.exe with the C# compiler built into Windows,
# installs per-user (no admin) to %LOCALAPPDATA%\ClockCraft, enables start at login, adds a desktop shortcut, launches it.
# Usage: irm https://raw.githubusercontent.com/c-dreamer/clockcraft/main/install.ps1 | iex
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$branch = if ($env:CLOCKCRAFT_BRANCH) { $env:CLOCKCRAFT_BRANCH } else { 'main' }
$dest = Join-Path $env:LOCALAPPDATA 'ClockCraft'
$tmp  = Join-Path $env:TEMP ('clockcraft-' + [guid]::NewGuid())

try {
    Write-Host "Downloading ClockCraft ($branch)..."
    New-Item -ItemType Directory -Path $tmp | Out-Null
    Invoke-WebRequest "https://github.com/c-dreamer/clockcraft/archive/refs/heads/$branch.zip" -OutFile "$tmp\src.zip" -UseBasicParsing
    Expand-Archive "$tmp\src.zip" -DestinationPath $tmp
    $src = Get-ChildItem $tmp -Directory | Select-Object -First 1

    Get-Process DualClock -ErrorAction SilentlyContinue | Stop-Process -Force
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    foreach ($f in 'DualClock.cs', 'app.manifest', 'clockcraft.ico', 'build.cmd') {
        Copy-Item (Join-Path $src.FullName $f) $dest -Force
    }

    Write-Host 'Building...'
    cmd /c "`"$dest\build.cmd`" < nul" | Out-Host
    $exe = Join-Path $dest 'DualClock.exe'
    if (-not (Test-Path $exe)) { throw 'Build failed - see errors above.' }

    # Start at login (same registry value the app's own menu toggles)
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'ClockCraft' -Value "`"$exe`""

    # Desktop shortcut
    $sc = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'ClockCraft.lnk'))
    $sc.TargetPath = $exe; $sc.WorkingDirectory = $dest; $sc.IconLocation = "$exe,0"; $sc.Description = 'ClockCraft time zone overlay'
    $sc.Save()

    Start-Process $exe
    Write-Host "ClockCraft installed to $dest and running (look for the tray icon)." -ForegroundColor Green
}
finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
