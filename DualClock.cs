// ClockCraft - floating multi-timezone "island" overlay for Windows.
// Single file, C# 5 / .NET Framework 4.x so it builds with the csc.exe that ships in Windows (see build.cmd).
//
// Drag to move (any monitor). Double-click to snap to the top-center of the current monitor.
// Hover for a close (x) button, which hides it to the system tray. Tray icon: click to show/hide,
// right-click for snap, start at login, desktop shortcut, exit.
// Right-click the island: add/remove time zones, 12/24h, seconds, always on top, start at login, snap, exit.
// Settings: %APPDATA%\DualClock\settings.json (same file the PowerShell version used).

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Shapes;
using System.Windows.Threading;
using Microsoft.Win32;

namespace ClockCraft
{
    public class ZoneCfg
    {
        public string Label { get; set; }
        public string Id { get; set; }   // Windows time zone ID
        public string Abbr { get; set; } // "STD" or "STD/DST"; blank = show UTC offset
    }

    public class Settings
    {
        public double? Left { get; set; }
        public double? Top { get; set; }
        public bool Use24h { get; set; }
        public bool Seconds { get; set; }
        public bool Topmost { get; set; }
        public List<ZoneCfg> Zones { get; set; }

        public Settings()
        {
            Use24h = true;
            Topmost = true;
            Zones = Defaults();
        }

        // First zone is the reference for offsets and Today/Tomorrow.
        public static List<ZoneCfg> Defaults()
        {
            return new List<ZoneCfg>
            {
                new ZoneCfg { Label = "BALLITO",  Id = "South Africa Standard Time", Abbr = "SAST" },
                new ZoneCfg { Label = "BOISE",    Id = "Mountain Standard Time",     Abbr = "MST/MDT" },
                new ZoneCfg { Label = "PAMPANGA", Id = "Singapore Standard Time",    Abbr = "PHT" } // UTC+8, Philippines
            };
        }

        static readonly string Dir  = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "DualClock");
        static readonly string FilePath = System.IO.Path.Combine(Dir, "settings.json");

        public static Settings Load()
        {
            try
            {
                if (File.Exists(FilePath))
                {
                    var s = new JavaScriptSerializer().Deserialize<Settings>(File.ReadAllText(FilePath));
                    if (s != null)
                    {
                        if (s.Zones == null || s.Zones.Count == 0) s.Zones = Defaults();
                        return s;
                    }
                }
            }
            catch { }
            return new Settings();
        }

        public void Save()
        {
            try
            {
                Directory.CreateDirectory(Dir);
                File.WriteAllText(FilePath, new JavaScriptSerializer().Serialize(this));
            }
            catch { }
        }
    }

    class ZoneView
    {
        public TimeZoneInfo Tz;
        public string Std, Dst;
        public Ellipse Dot;
        public TextBlock Abbr, Time, AmPm, Foot;
    }

    static class Ui
    {
        public static SolidColorBrush Br(string hex)
        {
            var b = (SolidColorBrush)new BrushConverter().ConvertFromString(hex);
            b.Freeze();
            return b;
        }
        public static readonly FontFamily Display = new FontFamily("Segoe UI Variable Display, Segoe UI");
        public static readonly FontFamily Text    = new FontFamily("Segoe UI Variable Text, Segoe UI");
        public static readonly Brush Dim   = Br("#8E96A3");
        public static readonly Brush White = Br("#F5F7FA");
        public static readonly Brush Work  = Br("#34C759");
        public static readonly Brush Shoul = Br("#FFCC00");
        public static readonly Brush Night = Br("#5E6673");
        public static readonly string[] Accents = { "#FFB547", "#5AC8FA", "#FF6B81", "#A78BFA", "#34D399", "#F472B6", "#60A5FA", "#FBBF24" };

        public static TextBlock T(double size, Brush fg, FontWeight weight, FontFamily font)
        {
            return new TextBlock { FontSize = size, Foreground = fg, FontWeight = weight, FontFamily = font };
        }
    }

    class ClockWindow : Window
    {
        const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
        const string RunName = "ClockCraft";

        readonly Settings settings = Settings.Load();
        readonly List<ZoneView> views = new List<ZoneView>();
        readonly StackPanel row = new StackPanel { Orientation = Orientation.Horizontal };
        readonly Border island;
        readonly Border closeBtn;
        readonly Brush closeIdle = Ui.Br("#FF3A3F4A");
        readonly Brush closeHot  = Ui.Br("#FFE5484D");
        System.Windows.Forms.NotifyIcon tray;
        bool quitting;

        public ClockWindow()
        {
            Title = "ClockCraft";
            WindowStyle = WindowStyle.None;
            AllowsTransparency = true;
            Background = Brushes.Transparent;
            ShowInTaskbar = false;
            ResizeMode = ResizeMode.NoResize;
            SizeToContent = SizeToContent.WidthAndHeight;
            Topmost = settings.Topmost;

            var bg = new LinearGradientBrush(Color.FromArgb(0xF2, 0x23, 0x28, 0x32), Color.FromArgb(0xF2, 0x16, 0x1A, 0x21), 90);
            var bd = new LinearGradientBrush(Color.FromArgb(0x40, 0xFF, 0xFF, 0xFF), Color.FromArgb(0x10, 0xFF, 0xFF, 0xFF), 90);
            island = new Border
            {
                CornerRadius = new CornerRadius(26),
                Padding = new Thickness(22, 12, 22, 12),
                Background = bg,
                BorderBrush = bd,
                BorderThickness = new Thickness(1),
                Opacity = 0.94,
                Effect = new DropShadowEffect { BlurRadius = 22, ShadowDepth = 4, Direction = 270, Opacity = 0.45, Color = Colors.Black },
                Child = new StackPanel { Children = { row, BuildPhoneBar() } }
            };

            var x = Ui.T(10, Ui.Br("#DDE1E6"), FontWeights.Normal, Ui.Text);
            x.Text = "✕";
            x.HorizontalAlignment = HorizontalAlignment.Center;
            x.VerticalAlignment = VerticalAlignment.Center;
            closeBtn = new Border
            {
                Width = 20, Height = 20,
                CornerRadius = new CornerRadius(10),
                Cursor = Cursors.Hand,
                HorizontalAlignment = HorizontalAlignment.Right,
                VerticalAlignment = VerticalAlignment.Top,
                Margin = new Thickness(0, -7, -7, 0),
                Background = closeIdle,
                BorderBrush = Ui.Br("#40FFFFFF"),
                BorderThickness = new Thickness(1),
                Visibility = Visibility.Hidden,
                ToolTip = "Close",
                Child = x
            };
            closeBtn.MouseEnter += delegate { closeBtn.Background = closeHot; };
            closeBtn.MouseLeave += delegate { closeBtn.Background = closeIdle; };
            closeBtn.MouseLeftButtonDown += (s, e) => { e.Handled = true; HideToTray(); };

            var root = new Grid { Margin = new Thickness(16) };
            root.Children.Add(island);
            root.Children.Add(closeBtn);
            Content = root;

            MouseEnter += delegate { island.Opacity = 1.0;  closeBtn.Visibility = Visibility.Visible; };
            MouseLeave += delegate { island.Opacity = 0.94; closeBtn.Visibility = Visibility.Hidden; };
            MouseLeftButtonDown += OnMouseDown;
            LocationChanged += delegate { settings.Left = Left; settings.Top = Top; };
            // Re-assert topmost when another window takes focus
            Deactivated += delegate { if (settings.Topmost) { Topmost = false; Topmost = true; } };
            Loaded += delegate { PlaceOnLoad(); };
            Closing += (s, e) =>
            {
                settings.Save();
                if (!quitting) { e.Cancel = true; HideToTray(); return; }
                if (tray != null) { tray.Visible = false; tray.Dispose(); }
            };

            BuildMenu();
            BuildTray();
            BuildRow();
            Tick();

            var timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(500) };
            timer.Tick += delegate { Tick(); };
            timer.Start();
        }

        // ---------------------------------------------------------------- phone bar
        const string MtsNumber = "208-345-0054";

        // Strip under the clocks with the Microtech main number; click copies it.
        Border BuildPhoneBar()
        {
            var label = Ui.T(10.5, Ui.Dim, FontWeights.SemiBold, Ui.Text);
            label.Text = "MTS";
            var num = Ui.T(13, Ui.White, FontWeights.SemiBold, Ui.Text);
            num.Text = MtsNumber;
            num.Margin = new Thickness(8, 0, 8, 0);
            var hint = Ui.T(10, Ui.Dim, FontWeights.Normal, Ui.Text);
            hint.Text = "click to copy";
            hint.VerticalAlignment = label.VerticalAlignment = VerticalAlignment.Center;

            var bar = new Border
            {
                Margin = new Thickness(0, 10, 0, 0),
                Padding = new Thickness(0, 8, 0, 0),
                BorderBrush = Ui.Br("#22FFFFFF"),
                BorderThickness = new Thickness(0, 1, 0, 0),
                Background = Brushes.Transparent, // so the whole strip is clickable
                Cursor = Cursors.Hand,
                ToolTip = "Copy Microtech number",
                Child = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center, Children = { label, num, hint } }
            };
            bar.MouseLeftButtonDown += (s, e) =>
            {
                e.Handled = true; // don't start a window drag
                try { Clipboard.SetText(MtsNumber); hint.Text = "copied ✓"; hint.Foreground = Ui.Work; }
                catch { hint.Text = "copy failed"; }
                var t = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1.5) };
                t.Tick += delegate { t.Stop(); hint.Text = "click to copy"; hint.Foreground = Ui.Dim; };
                t.Start();
            };
            return bar;
        }

        // ---------------------------------------------------------------- layout
        void BuildRow()
        {
            row.Children.Clear();
            views.Clear();
            int n = 0;
            foreach (var cfg in settings.Zones)
            {
                TimeZoneInfo tz;
                try { tz = TimeZoneInfo.FindSystemTimeZoneById(cfg.Id); }
                catch { continue; }

                if (n > 0)
                    row.Children.Add(new Rectangle { Width = 1, Margin = new Thickness(20, 6, 20, 6), Fill = Ui.Br("#22FFFFFF") });

                var parts = (cfg.Abbr ?? "").Split('/');
                var v = new ZoneView { Tz = tz, Std = parts[0].Trim(), Dst = parts[parts.Length - 1].Trim() };

                var col = new StackPanel { MinWidth = 92 };

                var hdr = new StackPanel { Orientation = Orientation.Horizontal };
                v.Dot = new Ellipse { Width = 7, Height = 7, Margin = new Thickness(0, 0, 6, 0), VerticalAlignment = VerticalAlignment.Center };
                var city = Ui.T(10.5, Ui.Br(Ui.Accents[n % Ui.Accents.Length]), FontWeights.SemiBold, Ui.Text);
                city.Text = cfg.Label;
                v.Abbr = Ui.T(10.5, Ui.Dim, FontWeights.Normal, Ui.Text);
                v.Abbr.Margin = new Thickness(6, 0, 0, 0);
                hdr.Children.Add(v.Dot); hdr.Children.Add(city); hdr.Children.Add(v.Abbr);

                var timeRow = new StackPanel { Orientation = Orientation.Horizontal };
                v.Time = Ui.T(28, Ui.White, FontWeights.SemiBold, Ui.Display);
                v.Time.Margin = new Thickness(0, -2, 0, -3);
                v.AmPm = Ui.T(12, Ui.Dim, FontWeights.SemiBold, Ui.Text);
                v.AmPm.Margin = new Thickness(4, 0, 0, 5);
                v.AmPm.VerticalAlignment = VerticalAlignment.Bottom;
                timeRow.Children.Add(v.Time); timeRow.Children.Add(v.AmPm);

                v.Foot = Ui.T(10.5, Ui.Dim, FontWeights.Normal, Ui.Text);

                col.Children.Add(hdr); col.Children.Add(timeRow); col.Children.Add(v.Foot);
                row.Children.Add(col);
                views.Add(v);
                n++;
            }
        }

        // ---------------------------------------------------------------- render
        static Brush StatusBrush(DateTime t)
        {
            bool weekday = t.DayOfWeek != DayOfWeek.Saturday && t.DayOfWeek != DayOfWeek.Sunday;
            if (weekday && t.Hour >= 8 && t.Hour < 17) return Ui.Work;
            if (t.Hour >= 7 && t.Hour < 22) return Ui.Shoul;
            return Ui.Night;
        }

        void Tick()
        {
            if (views.Count == 0) return;
            DateTime utc = DateTime.UtcNow;
            DateTime refT = TimeZoneInfo.ConvertTimeFromUtc(utc, views[0].Tz);
            string fmt = settings.Use24h ? "HH:mm" : "h:mm";
            if (settings.Seconds) fmt += ":ss";

            for (int i = 0; i < views.Count; i++)
            {
                var v = views[i];
                DateTime t = TimeZoneInfo.ConvertTimeFromUtc(utc, v.Tz);
                v.Time.Text = t.ToString(fmt);
                v.AmPm.Text = settings.Use24h ? "" : t.ToString("tt");
                v.Dot.Fill = StatusBrush(t);

                string a = v.Tz.IsDaylightSavingTime(t) ? v.Dst : v.Std;
                if (string.IsNullOrEmpty(a))
                {
                    TimeSpan o = v.Tz.GetUtcOffset(utc);
                    a = "UTC" + (o.Ticks < 0 ? "-" : "+") + o.Duration().ToString(@"h\:mm").Replace(":00", "");
                }
                v.Abbr.Text = a;

                if (i == 0)
                {
                    v.Foot.Text = t.ToString("ddd d MMM");
                }
                else
                {
                    int dd = (t.Date - refT.Date).Days;
                    string day = dd == 0 ? "Today" : dd == 1 ? "Tomorrow" : dd == -1 ? "Yesterday" : t.ToString("ddd");
                    double hrs = (t - refT).TotalHours;
                    v.Foot.Text = day + "  " + hrs.ToString("+0.##;-0.##;+0") + "h";
                }
            }
        }

        // ---------------------------------------------------------------- position
        void OnMouseDown(object sender, MouseButtonEventArgs e)
        {
            if (e.ClickCount == 2) { SnapTopCenter(); settings.Save(); return; }
            try { DragMove(); } catch (InvalidOperationException) { }
            settings.Save();
        }

        void PlaceOnLoad()
        {
            bool ok = settings.Left.HasValue && settings.Top.HasValue
                && settings.Left.Value >= SystemParameters.VirtualScreenLeft
                && settings.Left.Value <= SystemParameters.VirtualScreenLeft + SystemParameters.VirtualScreenWidth - 80
                && settings.Top.Value >= SystemParameters.VirtualScreenTop
                && settings.Top.Value <= SystemParameters.VirtualScreenTop + SystemParameters.VirtualScreenHeight - 40;
            if (ok) { Left = settings.Left.Value; Top = settings.Top.Value; }
            else SnapTopCenter();
        }

        // Snap to the top-center of whichever monitor the widget is currently on.
        void SnapTopCenter()
        {
            var src = PresentationSource.FromVisual(this);
            if (src == null || src.CompositionTarget == null) return;
            Matrix toDev = src.CompositionTarget.TransformToDevice;
            Matrix fromDev = src.CompositionTarget.TransformFromDevice;

            Point c = toDev.Transform(new Point(Left + ActualWidth / 2, Top + ActualHeight / 2));
            var wa = System.Windows.Forms.Screen.FromPoint(new System.Drawing.Point((int)c.X, (int)c.Y)).WorkingArea;
            Point tl = fromDev.Transform(new Point(wa.Left, wa.Top));
            Point br = fromDev.Transform(new Point(wa.Right, wa.Bottom));

            Left = tl.X + ((br.X - tl.X) - ActualWidth) / 2;
            Top = tl.Y - 6;
        }

        // ---------------------------------------------------------------- startup
        static string ExePath { get { return Process.GetCurrentProcess().MainModule.FileName; } }

        static bool StartsWithWindows()
        {
            using (var k = Registry.CurrentUser.OpenSubKey(RunKey))
                return k != null && k.GetValue(RunName) != null;
        }

        static void SetStartWithWindows(bool on)
        {
            using (var k = Registry.CurrentUser.CreateSubKey(RunKey))
            {
                if (on) k.SetValue(RunName, "\"" + ExePath + "\"");
                else if (k.GetValue(RunName) != null) k.DeleteValue(RunName);
            }
        }

        // ---------------------------------------------------------------- menu
        void BuildMenu()
        {
            var menu = new ContextMenu();

            var add = new MenuItem { Header = "Add time zone..." };
            add.Click += delegate { AddZone(); };
            var rem = new MenuItem { Header = "Remove time zone" };

            var h24 = new MenuItem { Header = "24-hour time", IsCheckable = true, IsChecked = settings.Use24h };
            h24.Click += delegate { settings.Use24h = h24.IsChecked; Tick(); settings.Save(); };
            var sec = new MenuItem { Header = "Show seconds", IsCheckable = true, IsChecked = settings.Seconds };
            sec.Click += delegate { settings.Seconds = sec.IsChecked; Tick(); settings.Save(); };
            var top = new MenuItem { Header = "Always on top", IsCheckable = true, IsChecked = settings.Topmost };
            top.Click += delegate { settings.Topmost = top.IsChecked; Topmost = top.IsChecked; settings.Save(); };
            var boot = new MenuItem { Header = "Start at login", IsCheckable = true };
            boot.Click += delegate
            {
                try { SetStartWithWindows(boot.IsChecked); }
                catch (Exception ex) { MessageBox.Show(ex.Message, "ClockCraft"); }
                boot.IsChecked = StartsWithWindows();
            };
            var snap = new MenuItem { Header = "Snap to top center" };
            snap.Click += delegate { SnapTopCenter(); settings.Save(); };
            var hide = new MenuItem { Header = "Hide to tray" };
            hide.Click += delegate { HideToTray(); };
            var exit = new MenuItem { Header = "Exit" };
            exit.Click += delegate { Quit(); };

            menu.Items.Add(add);
            menu.Items.Add(rem);
            menu.Items.Add(new Separator());
            menu.Items.Add(h24);
            menu.Items.Add(sec);
            menu.Items.Add(top);
            menu.Items.Add(boot);
            menu.Items.Add(snap);
            menu.Items.Add(new Separator());
            menu.Items.Add(hide);
            menu.Items.Add(exit);

            menu.Opened += delegate
            {
                boot.IsChecked = StartsWithWindows();
                rem.Items.Clear();
                for (int i = 0; i < settings.Zones.Count; i++)
                {
                    int idx = i; // capture per item
                    var it = new MenuItem { Header = settings.Zones[i].Label, IsEnabled = settings.Zones.Count > 1 };
                    it.Click += delegate
                    {
                        settings.Zones.RemoveAt(idx);
                        BuildRow(); Tick(); settings.Save();
                    };
                    rem.Items.Add(it);
                }
            };

            ContextMenu = menu;
        }

        // ---------------------------------------------------------------- tray
        void BuildTray()
        {
            var icon = System.Drawing.Icon.ExtractAssociatedIcon(ExePath);
            var m = new System.Windows.Forms.ContextMenuStrip();
            var show  = new System.Windows.Forms.ToolStripMenuItem("Show / hide");
            var snap  = new System.Windows.Forms.ToolStripMenuItem("Snap to top center");
            var login = new System.Windows.Forms.ToolStripMenuItem("Start at login") { CheckOnClick = false };
            var desk  = new System.Windows.Forms.ToolStripMenuItem("Create desktop shortcut");
            var exit  = new System.Windows.Forms.ToolStripMenuItem("Exit");
            show.Font = new System.Drawing.Font(show.Font, System.Drawing.FontStyle.Bold);
            show.Click  += delegate { ToggleVisible(); };
            snap.Click  += delegate { ShowFromTray(); SnapTopCenter(); settings.Save(); };
            login.Click += delegate
            {
                try { SetStartWithWindows(!StartsWithWindows()); }
                catch (Exception ex) { MessageBox.Show(ex.Message, "ClockCraft"); }
            };
            desk.Click  += delegate { CreateDesktopShortcut(); };
            exit.Click  += delegate { Quit(); };
            m.Opening += delegate { login.Checked = StartsWithWindows(); };
            m.Items.AddRange(new System.Windows.Forms.ToolStripItem[] { show, snap, new System.Windows.Forms.ToolStripSeparator(), login, desk, new System.Windows.Forms.ToolStripSeparator(), exit });

            tray = new System.Windows.Forms.NotifyIcon { Icon = icon, Text = "ClockCraft", ContextMenuStrip = m, Visible = true };
            tray.MouseClick += (s, e) => { if (e.Button == System.Windows.Forms.MouseButtons.Left) ToggleVisible(); };
        }

        void ToggleVisible() { if (IsVisible) HideToTray(); else ShowFromTray(); }

        void HideToTray()
        {
            settings.Save();
            Hide();
        }

        public void ShowFromTray()
        {
            Show();
            Topmost = false; Topmost = settings.Topmost;
            Activate();
        }

        // Called on Windows logoff/shutdown so the hide-to-tray cancel doesn't block it.
        public void AllowExit() { quitting = true; }

        void Quit()
        {
            quitting = true;
            Close();
        }

        static void CreateDesktopShortcut()
        {
            try
            {
                string lnk = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "ClockCraft.lnk");
                Type t = Type.GetTypeFromProgID("WScript.Shell");
                object shell = Activator.CreateInstance(t);
                object sc = t.InvokeMember("CreateShortcut", System.Reflection.BindingFlags.InvokeMethod, null, shell, new object[] { lnk });
                Type st = sc.GetType();
                st.InvokeMember("TargetPath", System.Reflection.BindingFlags.SetProperty, null, sc, new object[] { ExePath });
                st.InvokeMember("WorkingDirectory", System.Reflection.BindingFlags.SetProperty, null, sc, new object[] { System.IO.Path.GetDirectoryName(ExePath) });
                st.InvokeMember("IconLocation", System.Reflection.BindingFlags.SetProperty, null, sc, new object[] { ExePath + ",0" });
                st.InvokeMember("Description", System.Reflection.BindingFlags.SetProperty, null, sc, new object[] { "ClockCraft time zone overlay" });
                st.InvokeMember("Save", System.Reflection.BindingFlags.InvokeMethod, null, sc, null);
                MessageBox.Show("Shortcut created on your desktop.\n\nTo pin to the taskbar: right-click it > Show more options > Pin to taskbar.", "ClockCraft");
            }
            catch (Exception ex) { MessageBox.Show("Couldn't create shortcut: " + ex.Message, "ClockCraft"); }
        }

        void AddZone()
        {
            var dlg = new AddZoneDialog();
            if (dlg.ShowDialog() == true && dlg.Result != null)
            {
                settings.Zones.Add(dlg.Result);
                BuildRow(); Tick(); settings.Save();
            }
        }
    }

    class AddZoneDialog : Window
    {
        public ZoneCfg Result;

        public AddZoneDialog()
        {
            Title = "Add time zone";
            Width = 440;
            SizeToContent = SizeToContent.Height;
            ResizeMode = ResizeMode.NoResize;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            Topmost = true;

            var cb = new ComboBox
            {
                IsEditable = true,
                IsTextSearchEnabled = true,
                DisplayMemberPath = "DisplayName",
                ItemsSource = TimeZoneInfo.GetSystemTimeZones()
            };
            TextSearch.SetTextPath(cb, "DisplayName");
            var lbl = new TextBox { Padding = new Thickness(4) };
            var ab = new TextBox { Padding = new Thickness(4) };

            cb.SelectionChanged += delegate
            {
                var tz = cb.SelectedItem as TimeZoneInfo;
                if (tz == null) return;
                string name = Regex.Replace(tz.DisplayName, @"^\([^)]*\)\s*", "");
                lbl.Text = name.Split(',')[0].Trim().ToUpperInvariant();
            };

            var ok = new Button { Content = "Add", Width = 80, IsDefault = true, Margin = new Thickness(0, 0, 8, 0) };
            var cancel = new Button { Content = "Cancel", Width = 80, IsCancel = true };
            ok.Click += delegate
            {
                var tz = cb.SelectedItem as TimeZoneInfo;
                if (tz == null) { cb.Focus(); return; }
                string label = lbl.Text.Trim();
                Result = new ZoneCfg
                {
                    Label = label.Length > 0 ? label.ToUpperInvariant() : tz.Id,
                    Id = tz.Id,
                    Abbr = ab.Text.Trim()
                };
                DialogResult = true;
            };

            var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 16, 0, 0) };
            buttons.Children.Add(ok);
            buttons.Children.Add(cancel);

            var p = new StackPanel { Margin = new Thickness(18) };
            p.Children.Add(Caption("Time zone", 0));
            p.Children.Add(cb);
            p.Children.Add(Caption("Label", 12));
            p.Children.Add(lbl);
            p.Children.Add(Caption("Abbreviation (e.g. PHT, or GMT/BST for standard/summer; blank = UTC offset)", 12));
            p.Children.Add(ab);
            p.Children.Add(buttons);
            Content = p;
        }

        static TextBlock Caption(string text, double top)
        {
            return new TextBlock { Text = text, Margin = new Thickness(0, top, 0, 4), Foreground = Brushes.DimGray, TextWrapping = TextWrapping.Wrap };
        }
    }

    static class Program
    {
        [STAThread]
        static void Main()
        {
            bool first;
            using (new Mutex(true, "ClockCraft.DualClock.SingleInstance", out first))
            {
                var showSignal = new EventWaitHandle(false, EventResetMode.AutoReset, "ClockCraft.DualClock.Show");
                if (!first)
                {
                    // Already running (e.g. launched again from the taskbar pin): bring that one up.
                    showSignal.Set();
                    return;
                }

                var app = new Application();
                var win = new ClockWindow();
                var listener = new Thread(() =>
                {
                    while (true)
                    {
                        showSignal.WaitOne();
                        win.Dispatcher.BeginInvoke(new Action(win.ShowFromTray));
                    }
                }) { IsBackground = true };
                listener.Start();
                app.SessionEnding += delegate { win.AllowExit(); };
                app.Run(win);
            }
        }
    }
}
