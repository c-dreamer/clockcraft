# DualClock

Small always-visible Windows desktop widget showing **SAST (Ballito)** and **Boise (MST/MDT)** time side by side.
Pure PowerShell + WPF (built into Windows) — no third-party installs, no admin rights.

- Boise uses the Windows `Mountain Standard Time` zone, so the MST/MDT switch is automatic; the label and hour offset update themselves.
- Drag to move; position is remembered (`%APPDATA%\DualClock\settings.json`).
- Right-click: 24-hour toggle, always-on-top toggle, Exit.

## Install (per user)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

Copies to `%LOCALAPPDATA%\DualClock`, adds a Startup-folder shortcut so it runs at logon, and launches it.

## Uninstall

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

## Requirements

Windows 10/11, Windows PowerShell 5.1.
