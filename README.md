# ClockCraft

A floating "island" overlay that sits on top of your apps and shows several time zones side by side.
The defaults are **Ballito (SAST)**, **Boise (MST/MDT)** and **Pampanga (PHT)**.

It's a single C# file built with the compiler that ships with Windows, so there's no SDK, no installer and nothing third-party.

## Build

1. Clone or download this repo.
2. Double-click **`build.cmd`**. It produces `DualClock.exe` next to it.
3. Run `DualClock.exe`. Right-click it and tick **Start with Windows** if you want it at logon.

SmartScreen may warn the first time because the exe isn't code-signed. Click **More info → Run anyway**.

## Use

- **Moving:** drag it anywhere, on any monitor. It remembers its position, and if that monitor is gone it comes back on screen. Double-click to snap it to the top-center of the monitor it's on.
- **Closing:** hover to show a small ✕ in the top-right corner, then click it.
- **Right-click menu:**
  - add or remove time zones
  - 24-hour time
  - seconds
  - always on top
  - start with Windows
  - snap to top center
  - exit
- **Each city shows:**
  - a status dot: green for weekday 08–17, amber for 07–22, grey at night
  - an abbreviation
  - the time
  - the day and offset relative to the first city
- **Abbreviations when adding a zone:**
  - `PHT` for a single abbreviation
  - `GMT/BST` for standard/summer
  - blank to show the UTC offset
- **Settings:** stored in `%APPDATA%\DualClock\settings.json`. This is the same file the old PowerShell version used, so your cities carry over.

## Changing it

All the code is in `DualClock.cs`. The default cities are in `Settings.Defaults()`. Edit the file, then run `build.cmd` again.

## Migrating from the PowerShell version

The old scripts are in `legacy-powershell/`. If you ran its `Install.ps1`, remove the old Startup shortcut so you don't get two clocks at logon:

```powershell
Remove-Item "$([Environment]::GetFolderPath('Startup'))\DualClock.lnk" -ErrorAction SilentlyContinue
```
