using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using Forms = System.Windows.Forms;

namespace Nook;

public partial class App : Application
{
    public static Settings Settings { get; private set; } = new();
    public static MainWindow Player { get; private set; } = null!;

    static Mutex? _mutex;
    static Forms.NotifyIcon? _tray;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        _mutex = new Mutex(true, "Nook.SingleInstance.v1", out bool first);
        if (!first) { Shutdown(); return; }

        // Um widget não deve sumir por um erro bobo: registra e segue rodando.
        DispatcherUnhandledException += (_, a) => { Log(a.Exception); a.Handled = true; };
        TaskScheduler.UnobservedTaskException += (_, a) => { Log(a.Exception); a.SetObserved(); };

        Settings = Settings.Load();
        Strings.Init(Settings.Language);
        Settings.ApplyStartup(); // mantém o registro apontando para onde o .exe está agora
        Player = new MainWindow();
        Player.Show();
        UpdateTray();
    }

    /// <summary>Recria o menu da bandeja (ex.: depois de trocar o idioma).</summary>
    public static void RebuildTray()
    {
        _tray?.Dispose();
        _tray = null;
        UpdateTray();
    }

    public static void UpdateTray()
    {
        if (!Settings.TrayIcon)
        {
            _tray?.Dispose();
            _tray = null;
            return;
        }
        if (_tray != null) return;

        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add(Strings.Get("ShowHide"), null, (_, _) => Player.ToggleVisible());
        menu.Items.Add(Strings.Get("Settings"), null, (_, _) => Player.OpenSettings());
        menu.Items.Add(Strings.Get("OpenSpotify"), null, (_, _) => OpenSpotify());
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add(Strings.Get("Quit"), null, (_, _) => Quit());

        _tray = new Forms.NotifyIcon
        {
            Icon = MakeIcon(),
            Text = "Nook",
            ContextMenuStrip = menu,
            Visible = true,
        };
        _tray.MouseClick += (_, a) => { if (a.Button == Forms.MouseButtons.Left) Player.ToggleVisible(); };
    }

    static Icon MakeIcon()
    {
        using var s = GetResourceStream(new Uri("pack://application:,,,/Assets/nook.ico")).Stream;
        return new Icon(s, Forms.SystemInformation.SmallIconSize);
    }

    static void Log(Exception ex)
    {
        try
        {
            var dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Nook");
            Directory.CreateDirectory(dir);
            File.AppendAllText(Path.Combine(dir, "error.log"), $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {ex}\n\n");
        }
        catch { }
    }

    public static void OpenSpotify()
    {
        try { Process.Start(new ProcessStartInfo("spotify:") { UseShellExecute = true }); }
        catch { }
    }

    public static void Quit()
    {
        Settings.Save();
        if (_tray != null) { _tray.Visible = false; _tray.Dispose(); }
        Current.Shutdown();
    }
}
