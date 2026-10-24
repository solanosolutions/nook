using System;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace Nook;

public partial class SettingsWindow : Window
{
    readonly MainWindow _player;
    double? _aboveAnchorTop;   // topo do player quando o menu abre acima dele
    double _workTop;
    static Settings S => App.Settings;

    public SettingsWindow(MainWindow player)
    {
        InitializeComponent();
        _player = player;

        SourceInitialized += (_, _) => { Native.MakeToolWindow(this); Native.SetBlur(this, true); };
        SizeChanged += (_, _) =>
        {
            Native.RoundCorners(this, 12);
            // Aberto acima do player: ao recolher/expandir, cresce para cima e continua grudado nele.
            if (_aboveAnchorTop is double anchorTop) Top = Math.Max(_workTop + 8, anchorTop - ActualHeight - 8);
        };
        int opened = Environment.TickCount;
        bool closing = false;
        Closing += (_, _) => closing = true;
        Deactivated += (_, _) => { if (!closing && IsLoaded && Environment.TickCount - opened > 400) Close(); };
        KeyDown += (_, e) => { if (e.Key == System.Windows.Input.Key.Escape) Close(); };

        // Cada switch aponta (via Tag) para uma propriedade bool de Settings.
        foreach (var cb in FindAll<CheckBox>(this))
        {
            var prop = typeof(Settings).GetProperty((string)cb.Tag);
            if (prop == null) continue;
            cb.IsChecked = (bool)prop.GetValue(S)!;
            cb.Click += (_, _) =>
            {
                prop.SetValue(S, cb.IsChecked == true);
                if (prop.Name == nameof(Settings.StartWithWindows)) S.ApplyStartup();
                Commit();
            };
        }

        foreach (var rb in FindAll<RadioButton>(VisualGroup))
        {
            rb.IsChecked = (string)rb.Tag == S.Visual;
            rb.Checked += (_, _) => { S.Visual = (string)rb.Tag; Commit(); };
        }

        foreach (var rb in FindAll<RadioButton>(LangGroup))
        {
            rb.IsChecked = (string)rb.Tag == S.Language;
            rb.Checked += (_, _) =>
            {
                S.Language = (string)rb.Tag;
                S.Save();
                Strings.Init(S.Language);
                _player.ApplyLanguage();
                App.RebuildTray();
                Close();
                _player.Dispatcher.BeginInvoke(_player.OpenSettings); // reabre já no idioma novo
            };
        }

        // Seções recolhíveis: lembra quais ficaram abertas.
        foreach (var sec in new[] { SecElements, SecLook, SecBehavior })
        {
            sec.IsChecked = S.OpenSections.Contains((string)sec.Tag);
            sec.Click += (_, _) =>
            {
                S.OpenSections.Remove((string)sec.Tag);
                if (sec.IsChecked == true) S.OpenSections.Add((string)sec.Tag);
                S.Save();
            };
        }

        ScaleSlider.Value = S.Scale;
        OpacitySlider.Value = S.IdleOpacity;
        UpdateLabels();
        ScaleSlider.ValueChanged += (_, e) => { S.Scale = Math.Round(e.NewValue, 2); UpdateLabels(); Commit(); };
        OpacitySlider.ValueChanged += (_, e) => { S.IdleOpacity = Math.Round(e.NewValue, 2); UpdateLabels(); Commit(); };
    }

    void UpdateLabels()
    {
        ScaleLabel.Text = $"{S.Scale * 100:0}%";
        OpacityLabel.Text = $"{S.IdleOpacity * 100:0}%";
    }

    void Commit()
    {
        _player.ApplySettings();
        S.Save();
    }

    /// <summary>Abre logo abaixo do player (ou acima, se não couber).</summary>
    public void ShowNear(Window anchor, Rect workArea)
    {
        Show();
        UpdateLayout();
        double left = Math.Clamp(anchor.Left, workArea.Left + 8, workArea.Right - ActualWidth - 8);
        double below = anchor.Top + anchor.ActualHeight + 8;
        bool fitsBelow = below + ActualHeight <= workArea.Bottom;
        double top = fitsBelow ? below : anchor.Top - ActualHeight - 8;
        _workTop = workArea.Top;
        _aboveAnchorTop = fitsBelow ? null : anchor.Top;
        Left = left;
        Top = Math.Max(workArea.Top + 8, top);
        Activate();
    }

    void Close_Click(object s, RoutedEventArgs e) => Close();
    void Spotify_Click(object s, RoutedEventArgs e) { App.OpenSpotify(); Close(); }
    void Quit_Click(object s, RoutedEventArgs e) => App.Quit();

    static System.Collections.Generic.IEnumerable<T> FindAll<T>(DependencyObject root) where T : DependencyObject
    {
        foreach (var child in LogicalTreeHelper.GetChildren(root).OfType<DependencyObject>())
        {
            if (child is T t) yield return t;
            foreach (var d in FindAll<T>(child)) yield return d;
        }
    }
}
