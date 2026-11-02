@echo off
rem Builds DualClock.exe with the C# compiler that ships with .NET Framework 4.x (built into Windows 10/11).
setlocal
set "FW=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319"
if not exist "%FW%\csc.exe" set "FW=%WINDIR%\Microsoft.NET\Framework\v4.0.30319"
if not exist "%FW%\csc.exe" (
  echo csc.exe not found under %WINDIR%\Microsoft.NET. Is .NET Framework 4.x installed?
  pause & exit /b 1
)

"%FW%\csc.exe" /nologo /target:winexe /optimize+ ^
  /out:"%~dp0DualClock.exe" /win32manifest:"%~dp0app.manifest" ^
  /lib:"%FW%" /lib:"%FW%\WPF" ^
  /r:PresentationFramework.dll /r:PresentationCore.dll /r:WindowsBase.dll /r:System.Xaml.dll ^
  /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Core.dll ^
  "%~dp0DualClock.cs"

if errorlevel 1 (
  echo.
  echo Build FAILED - copy the errors above.
  pause & exit /b 1
)
echo.
echo Built: %~dp0DualClock.exe
pause
