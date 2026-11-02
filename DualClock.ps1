<#
.SYNOPSIS
    Always-visible desktop widget showing South Africa (SAST) and Boise (MST/MDT) time.
.NOTES
    Drag to move. Right-click for 12/24h, always-on-top, and exit.
    Settings persist to %APPDATA%\DualClock\settings.json.
#>
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$ErrorActionPreference = 'Stop'

# --- Settings -------------------------------------------------------------
$settingsDir  = Join-Path $env:APPDATA 'DualClock'
$settingsPath = Join-Path $settingsDir 'settings.json'
$settings = [pscustomobject]@{ Left = 100; Top = 100; Use24h = $true; Topmost = $true }
if (Test-Path $settingsPath) {
    try {
        $saved = Get-Content $settingsPath -Raw | ConvertFrom-Json
        foreach ($p in $saved.PSObject.Properties) { $settings.$($p.Name) = $p.Value }
    } catch { }
}
function Save-Settings {
    if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir | Out-Null }
    $settings | ConvertTo-Json | Set-Content -Path $settingsPath -Encoding UTF8
}

# --- Time zones (Windows IDs; Mountain handles MST/MDT automatically) -----
$tzSast = [TimeZoneInfo]::FindSystemTimeZoneById('South Africa Standard Time')
$tzMtn  = [TimeZoneInfo]::FindSystemTimeZoneById('Mountain Standard Time')

# --- UI -------------------------------------------------------------------
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ShowInTaskbar="False" ResizeMode="NoResize" SizeToContent="WidthAndHeight">
  <Border CornerRadius="10" Background="#E61E1E1E" Padding="14,10" BorderBrush="#33FFFFFF" BorderThickness="1">
    <StackPanel Orientation="Horizontal">
      <StackPanel Margin="0,0,18,0">
        <TextBlock x:Name="LblA" Text="SAST" Foreground="#9AA0A6" FontSize="11" FontFamily="Segoe UI"/>
        <TextBlock x:Name="TimeA" Foreground="White" FontSize="26" FontFamily="Segoe UI Semibold"/>
        <TextBlock x:Name="DateA" Foreground="#9AA0A6" FontSize="11" FontFamily="Segoe UI"/>
      </StackPanel>
      <Rectangle Width="1" Fill="#33FFFFFF" Margin="0,2,18,2"/>
      <StackPanel>
        <TextBlock x:Name="LblB" Foreground="#9AA0A6" FontSize="11" FontFamily="Segoe UI"/>
        <TextBlock x:Name="TimeB" Foreground="White" FontSize="26" FontFamily="Segoe UI Semibold"/>
        <TextBlock x:Name="DateB" Foreground="#9AA0A6" FontSize="11" FontFamily="Segoe UI"/>
      </StackPanel>
    </StackPanel>
  </Border>
</Window>
'@
$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$ui = @{}
'LblA','TimeA','DateA','LblB','TimeB','DateB' | ForEach-Object { $ui[$_] = $window.FindName($_) }

$window.Left    = $settings.Left
$window.Top     = $settings.Top
$window.Topmost = [bool]$settings.Topmost

# Keep the widget on-screen if a monitor was removed since last run
$vs = [System.Windows.SystemParameters]
if ($window.Left -lt $vs::VirtualScreenLeft -or $window.Left -gt ($vs::VirtualScreenLeft + $vs::VirtualScreenWidth - 50) -or
    $window.Top  -lt $vs::VirtualScreenTop  -or $window.Top  -gt ($vs::VirtualScreenTop  + $vs::VirtualScreenHeight - 50)) {
    $window.Left = 100; $window.Top = 100
}

# --- Render ---------------------------------------------------------------
function Update-Clock {
    $utc  = [DateTime]::UtcNow
    $a    = [TimeZoneInfo]::ConvertTimeFromUtc($utc, $tzSast)
    $b    = [TimeZoneInfo]::ConvertTimeFromUtc($utc, $tzMtn)
    $fmt  = if ($settings.Use24h) { 'HH:mm' } else { 'h:mm tt' }
    $abbr = if ($tzMtn.IsDaylightSavingTime($b)) { 'MDT' } else { 'MST' }
    $diff = ($a - $b).TotalHours

    $ui.TimeA.Text = $a.ToString($fmt)
    $ui.DateA.Text = $a.ToString('ddd d MMM')
    $ui.LblB.Text  = "BOISE $abbr  (-$diff h)"
    $ui.TimeB.Text = $b.ToString($fmt)
    $ui.DateB.Text = $b.ToString('ddd d MMM')
}

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({ Update-Clock })

# --- Interaction ----------------------------------------------------------
$window.Add_MouseLeftButtonDown({ $window.DragMove() })
$window.Add_LocationChanged({ $settings.Left = $window.Left; $settings.Top = $window.Top })

$menu = New-Object System.Windows.Controls.ContextMenu
$mi24 = New-Object System.Windows.Controls.MenuItem -Property @{ Header = '24-hour time'; IsCheckable = $true; IsChecked = [bool]$settings.Use24h }
$miTop = New-Object System.Windows.Controls.MenuItem -Property @{ Header = 'Always on top'; IsCheckable = $true; IsChecked = [bool]$settings.Topmost }
$miExit = New-Object System.Windows.Controls.MenuItem -Property @{ Header = 'Exit' }
$mi24.Add_Click({ $settings.Use24h = $mi24.IsChecked; Update-Clock; Save-Settings })
$miTop.Add_Click({ $settings.Topmost = $miTop.IsChecked; $window.Topmost = $miTop.IsChecked; Save-Settings })
$miExit.Add_Click({ $window.Close() })
[void]$menu.Items.Add($mi24); [void]$menu.Items.Add($miTop)
[void]$menu.Items.Add((New-Object System.Windows.Controls.Separator)); [void]$menu.Items.Add($miExit)
$window.ContextMenu = $menu

$window.Add_Closing({ $timer.Stop(); Save-Settings })

Update-Clock
$timer.Start()
[void]$window.ShowDialog()
