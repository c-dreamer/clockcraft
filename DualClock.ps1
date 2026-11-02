<#
.SYNOPSIS
    Floating "island" overlay showing Ballito (SAST), Boise (MST/MDT) and Manila (PHT) time.
.NOTES
    Stays on top of apps. Drag to move. Double-click to snap to top-center.
    Right-click: add/remove time zones, 12/24h, seconds, always-on-top, snap, exit.
    Settings persist to %APPDATA%\DualClock\settings.json.
    Windows PowerShell 5.1 + WPF only. No third-party dependencies.
#>
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$ErrorActionPreference = 'Stop'

# --- Default zones (first entry is the reference for offsets / Today-Tomorrow) ---
# Windows TZ IDs: Mountain handles MST/MDT; Manila = 'Singapore Standard Time' (UTC+8, no DST).
# Abbr: "STD" or "STD/DST"; blank = show UTC offset. Add/remove at runtime via right-click.
$defaultZones = @(
    [pscustomobject]@{ Label = 'BALLITO'; Id = 'South Africa Standard Time'; Abbr = 'SAST' }
    [pscustomobject]@{ Label = 'BOISE';   Id = 'Mountain Standard Time';     Abbr = 'MST/MDT' }
    [pscustomobject]@{ Label = 'MANILA';  Id = 'Singapore Standard Time';    Abbr = 'PHT' }
)
$accents = '#FFB547','#5AC8FA','#FF6B81','#A78BFA','#34D399','#F472B6','#60A5FA','#FBBF24'

# --- Settings -------------------------------------------------------------
$settingsDir  = Join-Path $env:APPDATA 'DualClock'
$settingsPath = Join-Path $settingsDir 'settings.json'
$settings = [pscustomobject]@{ Left = $null; Top = $null; Use24h = $true; Seconds = $false; Topmost = $true; Zones = $defaultZones }
if (Test-Path $settingsPath) {
    try {
        $saved = Get-Content $settingsPath -Raw | ConvertFrom-Json
        foreach ($p in $saved.PSObject.Properties) {
            if ($settings.PSObject.Properties.Name -contains $p.Name) { $settings.$($p.Name) = $p.Value }
        }
    } catch { }
}
function Save-Settings {
    if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir | Out-Null }
    $settings | ConvertTo-Json -Depth 5 | Set-Content -Path $settingsPath -Encoding UTF8
}

# --- Helpers --------------------------------------------------------------
$bc = New-Object System.Windows.Media.BrushConverter
function Brush([string]$hex) { $b = $bc.ConvertFromString($hex); $b.Freeze(); $b }
$fontDisplay = New-Object System.Windows.Media.FontFamily 'Segoe UI Variable Display, Segoe UI'
$fontText    = New-Object System.Windows.Media.FontFamily 'Segoe UI Variable Text, Segoe UI'
$dim   = Brush '#8E96A3'
$white = Brush '#F5F7FA'

function New-Text($size, $brush, $weight = 'Normal', $font = $fontText) {
    $t = New-Object System.Windows.Controls.TextBlock
    $t.FontSize = $size; $t.Foreground = $brush; $t.FontFamily = $font
    $t.FontWeight = [System.Windows.FontWeights]::$weight
    $t
}

# --- Window shell ---------------------------------------------------------
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ShowInTaskbar="False" ResizeMode="NoResize" SizeToContent="WidthAndHeight"
        Topmost="True" Title="DualClock">
  <Grid Margin="16">
    <Border x:Name="Island" CornerRadius="26" Padding="22,12,22,12"
            BorderThickness="1" Opacity="0.94">
      <Border.Background>
        <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
          <GradientStop Color="#F2232832" Offset="0"/>
          <GradientStop Color="#F2161A21" Offset="1"/>
        </LinearGradientBrush>
      </Border.Background>
      <Border.BorderBrush>
        <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
          <GradientStop Color="#40FFFFFF" Offset="0"/>
          <GradientStop Color="#10FFFFFF" Offset="1"/>
        </LinearGradientBrush>
      </Border.BorderBrush>
      <Border.Effect>
        <DropShadowEffect BlurRadius="22" ShadowDepth="4" Direction="270" Opacity="0.45" Color="Black"/>
      </Border.Effect>
      <StackPanel x:Name="Row" Orientation="Horizontal"/>
    </Border>
  </Grid>
</Window>
'@
$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$island = $window.FindName('Island')
$row    = $window.FindName('Row')

# --- Build one column per zone --------------------------------------------
$zones = @()
function Build-Row {
    $row.Children.Clear()
    $script:zones = @()
    $n = 0
    foreach ($cfg in @($settings.Zones)) {
        try { $tz = [TimeZoneInfo]::FindSystemTimeZoneById($cfg.Id) } catch { continue }
        $parts = "$($cfg.Abbr)".Split('/')
        $script:zones += @{ Label = $cfg.Label; Tz = $tz; Std = $parts[0]; Dst = $parts[-1]; Accent = $accents[$n % $accents.Count] }
        $n++
    }
    $zones = $script:zones
    for ($i = 0; $i -lt $zones.Count; $i++) {
    $z = $zones[$i]
    if ($i -gt 0) {
        $sep = New-Object System.Windows.Shapes.Rectangle
        $sep.Width = 1; $sep.Margin = '20,6,20,6'; $sep.Fill = Brush '#22FFFFFF'
        [void]$row.Children.Add($sep)
    }
    $col = New-Object System.Windows.Controls.StackPanel
    $col.MinWidth = 92

    # Header: status dot + city + abbreviation
    $hdr = New-Object System.Windows.Controls.StackPanel
    $hdr.Orientation = 'Horizontal'
    $dot = New-Object System.Windows.Shapes.Ellipse
    $dot.Width = 7; $dot.Height = 7; $dot.Margin = '0,0,6,0'; $dot.VerticalAlignment = 'Center'
    $city = New-Text 10.5 (Brush $z.Accent) 'SemiBold'
    $city.Text = $z.Label
    $abbr = New-Text 10.5 $dim
    $abbr.Margin = '6,0,0,0'
    [void]$hdr.Children.Add($dot); [void]$hdr.Children.Add($city); [void]$hdr.Children.Add($abbr)

    # Time
    $timeRow = New-Object System.Windows.Controls.StackPanel
    $timeRow.Orientation = 'Horizontal'
    $time = New-Text 28 $white 'SemiBold' $fontDisplay
    $time.Margin = '0,-2,0,-3'
    $ampm = New-Text 12 $dim 'SemiBold'
    $ampm.Margin = '4,0,0,5'; $ampm.VerticalAlignment = 'Bottom'
    [void]$timeRow.Children.Add($time); [void]$timeRow.Children.Add($ampm)

    # Footer: day + offset
    $foot = New-Text 10.5 $dim

    [void]$col.Children.Add($hdr); [void]$col.Children.Add($timeRow); [void]$col.Children.Add($foot)
    [void]$row.Children.Add($col)

    $z.Dot = $dot; $z.Abbr = $abbr; $z.Time = $time; $z.AmPm = $ampm; $z.Foot = $foot
}
}

# --- Status colours: working hours / shoulder / night ---------------------
$cWork  = Brush '#34C759'
$cShoul = Brush '#FFCC00'
$cNight = Brush '#5E6673'
function Get-StatusBrush([DateTime]$t) {
    $wkday = $t.DayOfWeek -ne 'Saturday' -and $t.DayOfWeek -ne 'Sunday'
    if ($wkday -and $t.Hour -ge 8 -and $t.Hour -lt 17) { return $cWork }
    if ($t.Hour -ge 7 -and $t.Hour -lt 22) { return $cShoul }
    return $cNight
}

# --- Render ---------------------------------------------------------------
function Update-Clock {
    $utc = [DateTime]::UtcNow
    if ($zones.Count -eq 0) { return }
    $ref = [TimeZoneInfo]::ConvertTimeFromUtc($utc, $zones[0].Tz)
    $fmt = if ($settings.Use24h) { 'HH:mm' } else { 'h:mm' }
    if ($settings.Seconds) { $fmt += ':ss' }

    foreach ($z in $zones) {
        $t = [TimeZoneInfo]::ConvertTimeFromUtc($utc, $z.Tz)
        $z.Time.Text = $t.ToString($fmt)
        $z.AmPm.Text = if ($settings.Use24h) { '' } else { $t.ToString('tt') }
        $a = if ($z.Tz.IsDaylightSavingTime($t)) { $z.Dst } else { $z.Std }
        if ([string]::IsNullOrWhiteSpace($a)) {
            $o = $z.Tz.GetUtcOffset($utc); $a = 'UTC{0}{1}' -f $(if ($o.Ticks -lt 0) { '-' } else { '+' }), $o.Duration().ToString('h\:mm').Replace(':00','')
        }
        $z.Abbr.Text = $a
        $z.Dot.Fill  = Get-StatusBrush $t

        $dayDiff = ($t.Date - $ref.Date).Days
        $day = switch ($dayDiff) { 0 { 'Today' } 1 { 'Tomorrow' } -1 { 'Yesterday' } default { $t.ToString('ddd') } }
        $hrs = ($t - $ref).TotalHours
        if ([object]::ReferenceEquals($z, $zones[0])) { $z.Foot.Text = $t.ToString('ddd d MMM') }
        else {
            $sign = if ($hrs -ge 0) { '+' } else { '' }
            $z.Foot.Text = '{0}  {1}{2}h' -f $day, $sign, $hrs
        }
    }
}

# --- Positioning ----------------------------------------------------------
function Set-TopCenter {
    $wa = [System.Windows.SystemParameters]::WorkArea
    $window.Left = $wa.Left + ($wa.Width - $window.ActualWidth) / 2
    $window.Top  = $wa.Top + 2
}
$window.Add_Loaded({
    $vs = [System.Windows.SystemParameters]
    $ok = $null -ne $settings.Left -and $null -ne $settings.Top -and
          $settings.Left -ge $vs::VirtualScreenLeft -and $settings.Left -le ($vs::VirtualScreenLeft + $vs::VirtualScreenWidth - 80) -and
          $settings.Top  -ge $vs::VirtualScreenTop  -and $settings.Top  -le ($vs::VirtualScreenTop  + $vs::VirtualScreenHeight - 40)
    if ($ok) { $window.Left = $settings.Left; $window.Top = $settings.Top } else { Set-TopCenter }
})
$window.Topmost = [bool]$settings.Topmost

# --- Interaction ----------------------------------------------------------
$window.Add_MouseLeftButtonDown({
    param($s, $e)
    if ($e.ClickCount -eq 2) { Set-TopCenter; return }
    $window.DragMove()
})
$window.Add_LocationChanged({ $settings.Left = $window.Left; $settings.Top = $window.Top })
$window.Add_MouseEnter({ $island.Opacity = 1.0 })
$window.Add_MouseLeave({ $island.Opacity = 0.94 })

# Re-assert topmost when focus moves elsewhere (some fullscreen-ish apps steal it)
$window.Add_Deactivated({ if ($settings.Topmost) { $window.Topmost = $false; $window.Topmost = $true } })

# --- Add-zone dialog ------------------------------------------------------
function Show-AddZone {
    [xml]$dx = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Add time zone" Width="440" SizeToContent="Height" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen" Topmost="True" Background="#FF1E2229">
  <StackPanel Margin="18">
    <TextBlock Text="Time zone" Foreground="#8E96A3" Margin="0,0,0,4"/>
    <ComboBox x:Name="Tz" IsEditable="True" IsTextSearchEnabled="True" DisplayMemberPath="DisplayName" TextSearch.TextPath="DisplayName"/>
    <TextBlock Text="Label" Foreground="#8E96A3" Margin="0,12,0,4"/>
    <TextBox x:Name="Lbl" Padding="4"/>
    <TextBlock Text="Abbreviation (e.g. GMT/BST; blank = UTC offset)" Foreground="#8E96A3" Margin="0,12,0,4"/>
    <TextBox x:Name="Ab" Padding="4"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,16,0,0">
      <Button x:Name="Ok" Content="Add" Width="80" IsDefault="True" Margin="0,0,8,0"/>
      <Button Content="Cancel" Width="80" IsCancel="True"/>
    </StackPanel>
  </StackPanel>
</Window>
'@
    $d = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $dx))
    $cb = $d.FindName('Tz'); $lbl = $d.FindName('Lbl'); $ab = $d.FindName('Ab')
    $cb.ItemsSource = [TimeZoneInfo]::GetSystemTimeZones()
    $cb.Add_SelectionChanged({
        $sel = $cb.SelectedItem
        if ($sel) { $lbl.Text = ($sel.DisplayName -replace '^\([^)]*\)\s*', '').Split(',')[0].Trim().ToUpper() }
    })
    $d.FindName('Ok').Add_Click({ if ($cb.SelectedItem) { $d.DialogResult = $true } })
    if ($d.ShowDialog()) {
        $label = if ($lbl.Text.Trim()) { $lbl.Text.Trim().ToUpper() } else { $cb.SelectedItem.Id }
        $settings.Zones = @(@($settings.Zones) + [pscustomobject]@{ Label = $label; Id = $cb.SelectedItem.Id; Abbr = $ab.Text.Trim() })
        Build-Row; Update-Clock; Save-Settings
    }
}

$menu   = New-Object System.Windows.Controls.ContextMenu
$mi24   = New-Object System.Windows.Controls.MenuItem -Property @{ Header = '24-hour time';  IsCheckable = $true; IsChecked = [bool]$settings.Use24h }
$miSec  = New-Object System.Windows.Controls.MenuItem -Property @{ Header = 'Show seconds';  IsCheckable = $true; IsChecked = [bool]$settings.Seconds }
$miTop  = New-Object System.Windows.Controls.MenuItem -Property @{ Header = 'Always on top'; IsCheckable = $true; IsChecked = [bool]$settings.Topmost }
$miSnap = New-Object System.Windows.Controls.MenuItem -Property @{ Header = 'Snap to top center' }
$miExit = New-Object System.Windows.Controls.MenuItem -Property @{ Header = 'Exit' }
$miAdd  = New-Object System.Windows.Controls.MenuItem -Property @{ Header = 'Add time zone...' }
$miRem  = New-Object System.Windows.Controls.MenuItem -Property @{ Header = 'Remove time zone' }
$miAdd.Add_Click({ Show-AddZone })
$mi24.Add_Click({  $settings.Use24h  = $mi24.IsChecked;  Update-Clock; Save-Settings })
$miSec.Add_Click({ $settings.Seconds = $miSec.IsChecked; Update-Clock; Save-Settings })
$miTop.Add_Click({ $settings.Topmost = $miTop.IsChecked; $window.Topmost = $miTop.IsChecked; Save-Settings })
$miSnap.Add_Click({ Set-TopCenter; Save-Settings })
$miExit.Add_Click({ $window.Close() })
foreach ($m in $miAdd, $miRem) { [void]$menu.Items.Add($m) }
[void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))
foreach ($m in $mi24, $miSec, $miTop, $miSnap) { [void]$menu.Items.Add($m) }
$menu.Add_Opened({
    $miRem.Items.Clear()
    $list = @($settings.Zones)
    for ($k = 0; $k -lt $list.Count; $k++) {
        $it = New-Object System.Windows.Controls.MenuItem
        $it.Header = $list[$k].Label; $it.Tag = $k
        $it.IsEnabled = $list.Count -gt 1
        $it.Add_Click({ param($s, $e)
            $idx = [int]$s.Tag
            $settings.Zones = @(@($settings.Zones) | Select-Object -Index (0..(@($settings.Zones).Count - 1) | Where-Object { $_ -ne $idx }))
            Build-Row; Update-Clock; Save-Settings
        })
        [void]$miRem.Items.Add($it)
    }
})
[void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))
[void]$menu.Items.Add($miExit)
$window.ContextMenu = $menu

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(500)
$timer.Add_Tick({ Update-Clock })
$window.Add_Closing({ $timer.Stop(); Save-Settings })

Build-Row
Update-Clock
$timer.Start()
[void]$window.ShowDialog()
