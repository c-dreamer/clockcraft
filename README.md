# DualClock

Floating "island" overlay that sits on top of your apps and shows **Ballito (SAST)**, **Boise (MST/MDT)** and **Pampanga (PHT)** side by side.
Pure Windows PowerShell 5.1 + WPF. No third-party installs, no admin.

- Rounded, translucent dark pill with drop shadow; snaps to top-center of the screen on first run.
- Each city: status dot (green = weekday 08–17, amber = 07–22, grey = night), abbreviation, time, and day + offset relative to SAST.
- Boise uses Windows `Mountain Standard Time`, so MST/MDT switches automatically. Pampanga uses `Singapore Standard Time` (UTC+8, the Windows zone used for the Philippines).
- Drag to move, double-click to snap to top-center. Position is remembered in `%APPDATA%\DualClock\settings.json`.
- Hover to reveal a small close (x) button in the top-right corner.
- Right-click: add/remove time zones, 24-hour time, seconds, always on top, snap, exit.

Add or remove cities from the right-click menu; defaults are the `$defaultZones` list at the top of `DualClock.ps1`.

## Run / Install

```powershell
Get-ChildItem *.ps1 | Unblock-File
powershell -NoProfile -ExecutionPolicy Bypass -File .\DualClock.ps1   # try it
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1     # run at logon (per user)
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1   # remove
```
