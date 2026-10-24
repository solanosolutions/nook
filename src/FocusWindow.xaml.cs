using System;
using System.IO;
using System.Linq;
using System.Media;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;

namespace Nook;

/// <summary>
/// Timer de foco: pílula de vidro colada ao player (acima dele, ou abaixo se não couber).
/// Repouso: "Foco" esmaecido; hover: 5 · 10 · 25 · [__] min. Rodando: mm:ss + pausar/cancelar no hover.
/// </summary>
public partial class FocusWindow : Window
{
    enum State { Idle, Running, Paused, Done }

    static readonly Color Solid = Color.FromArgb(0xF2, 0x16, 0x16, 0x16);
    static readonly Color Glass = Color.FromArgb(0x50, 0x16, 0x16, 0x16);
    static readonly Color Dim = Color.FromArgb(0xD0, 0x16, 0x16, 0x16);
    static readonly Duration Fade = TimeSpan.FromMilliseconds(220);
    static Settings S => App.Settings;

    readonly MainWindow _player;
    readonly SolidColorBrush _accent;
    readonly DispatcherTimer _tick = new() { Interval = TimeSpan.FromMilliseconds(250) };
    readonly DispatcherTimer _autoClear = new() { Interval = TimeSpan.FromMinutes(2) };
    State _state = State.Idle;
    TimeSpan _total, _remaining;
    DateTime _endsAt;
    bool _hover;

    public FocusWindow(MainWindow player, SolidColorBrush accent)
    {
        InitializeComponent();
        _player = player;
        _accent = accent;
        Fill.Background = accent;

        SourceInitialized += (_, _) => { Native.MakeToolWindow(this); Native.SetBlur(this, S.Blur); };
        SizeChanged += (_, _) => { Native.RoundCorners(this, 10); Reposition(); };
        MouseEnter += (_, _) => SetHover(true);
        MouseLeave += (_, _) => { if (!Custom.IsKeyboardFocusWithin) SetHover(false); };
        Deactivated += (_, _) => { if (!IsMouseOver) SetHover(false); };
        MouseLeftButtonUp += (_, _) => { if (_state == State.Done) Reset(); };
        _tick.Tick += (_, _) => Tick();
        _autoClear.Tick += (_, _) => Reset();
        // A 1ª medida acontece antes de os atalhos serem escondidos; força a janela a encolher para o conteúdo real.
        ContentRendered += (_, _) => { SizeToContent = SizeToContent.Manual; SizeToContent = SizeToContent.WidthAndHeight; };

        ApplySettings();
        Render();
    }

    // ---------- Aparência (mesma linguagem do player) ----------

    public void ApplySettings()
    {
        ScaleXf.ScaleX = ScaleXf.ScaleY = S.Scale;
        Topmost = S.Topmost;
        Native.SetBlur(this, S.Blur);
        ApplyLook(animate: false);
    }

    public void ApplyLanguage()
    {
        IdleLabel.Text = Strings.Get("Focus");
        Custom.ToolTip = Strings.Get("CustomTip");
        Render();
    }

    void SetHover(bool hover)
    {
        if (hover == _hover) return;
        _hover = hover;
        ApplyLook(animate: true);
        Render();
    }

    void ApplyLook(bool animate)
    {
        var color = _hover ? Solid : (S.Blur ? Glass : Dim);
        double opacity = _hover || _state == State.Done ? 1.0 : S.IdleOpacity;
        if (animate)
        {
            RootBrush.BeginAnimation(SolidColorBrush.ColorProperty, new ColorAnimation(color, Fade));
            BeginAnimation(OpacityProperty, new DoubleAnimation(opacity, Fade));
        }
        else
        {
            RootBrush.BeginAnimation(SolidColorBrush.ColorProperty, null);
            BeginAnimation(OpacityProperty, null);
            RootBrush.Color = color;
            Opacity = opacity;
        }
    }

    /// <summary>Gruda no player: logo acima, alinhado à esquerda; abaixo se não houver espaço.</summary>
    public void Reposition()
    {
        if (!_player.IsLoaded || ActualHeight <= 0) return;
        var wa = _player.WorkAreaRect();
        double top = _player.Top - ActualHeight - 6;
        if (top < wa.Top + 4) top = _player.Top + _player.ActualHeight + 6;
        Left = _player.Left;
        Top = top;
    }

    // ---------- Estado ----------

    void Render()
    {
        bool idle = _state == State.Idle;
        IdleLabel.Visibility = Vis(idle && !_hover);
        Presets.Visibility = Vis(idle && _hover);
        Clock.Visibility = Vis(!idle);
        RunButtons.Visibility = Vis(_state is State.Running or State.Paused && _hover);
        Track.Visibility = Vis(_state is State.Running or State.Paused);

        Clock.Text = _state == State.Done ? Strings.Get("TimesUp") : Format(_remaining);
        Clock.Foreground = _state == State.Done ? _accent : (Brush)FindResource("Fg");
        Clock.Opacity = _state == State.Paused ? 0.55 : 1;
        PauseBtn.Content = _state == State.Paused ? "" : "";
        PauseBtn.ToolTip = Strings.Get(_state == State.Paused ? "Resume" : "Pause");
        FillScale.ScaleX = _total.Ticks > 0 ? Math.Clamp(1 - _remaining / _total, 0, 1) : 0;
    }

    static Visibility Vis(bool v) => v ? Visibility.Visible : Visibility.Collapsed;

    static string Format(TimeSpan t)
    {
        if (t < TimeSpan.Zero) t = TimeSpan.Zero;
        var r = TimeSpan.FromSeconds(Math.Ceiling(t.TotalSeconds)); // 00:01 até o fim, nunca 00:00 antes da hora
        return r.TotalHours >= 1 ? r.ToString(@"h\:mm\:ss") : r.ToString(@"mm\:ss");
    }

    void Start(int minutes)
    {
        _total = _remaining = TimeSpan.FromMinutes(minutes);
        _endsAt = DateTime.UtcNow + _total;
        _state = State.Running;
        Custom.Text = "";
        Keyboard.ClearFocus();
        _tick.Start();
        Render();
    }

    void Tick()
    {
        if (_state != State.Running) return;
        _remaining = _endsAt - DateTime.UtcNow;   // pelo relógio: não acumula atraso do timer
        if (_remaining <= TimeSpan.Zero) Finish();
        else Render();
    }

    void Finish()
    {
        _state = State.Done;
        _remaining = TimeSpan.Zero;
        _tick.Stop();
        PlayChime();
        var pulse = new ColorAnimation(Colors.Transparent, _accent.Color, TimeSpan.FromMilliseconds(600))
        {
            AutoReverse = true,
            RepeatBehavior = new RepeatBehavior(5),
        };
        var border = new SolidColorBrush(Colors.Transparent);
        Root.BorderBrush = border;
        Root.BorderThickness = new Thickness(1.5);
        border.BeginAnimation(SolidColorBrush.ColorProperty, pulse);
        ApplyLook(animate: true);
        _autoClear.Start();
        Render();
    }

    void Reset()
    {
        _tick.Stop();
        _autoClear.Stop();
        _state = State.Idle;
        _total = _remaining = TimeSpan.Zero;
        Root.BorderBrush = (Brush)FindResource("Hairline");
        Root.BorderThickness = new Thickness(1);
        ApplyLook(animate: true);
        Render();
    }

    // ---------- Interação ----------

    void Preset_Click(object sender, RoutedEventArgs e) => Start(int.Parse((string)((Button)sender).Tag));

    void Custom_PreviewTextInput(object sender, TextCompositionEventArgs e) => e.Handled = !e.Text.All(char.IsDigit);

    void Custom_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter && int.TryParse(Custom.Text, out int min) && min is >= 1 and <= 600) Start(min);
        else if (e.Key == Key.Escape) { Custom.Text = ""; Keyboard.ClearFocus(); SetHover(IsMouseOver); }
    }

    void Pause_Click(object sender, RoutedEventArgs e)
    {
        if (_state == State.Running)
        {
            _remaining = _endsAt - DateTime.UtcNow;
            _state = State.Paused;
            _tick.Stop();
        }
        else if (_state == State.Paused)
        {
            _endsAt = DateTime.UtcNow + _remaining;
            _state = State.Running;
            _tick.Start();
        }
        Render();
    }

    void Cancel_Click(object sender, RoutedEventArgs e) => Reset();

    // ---------- Toque de fim (dois tons suaves, gerado em memória) ----------

    static byte[]? _chime;

    static void PlayChime()
    {
        try
        {
            _chime ??= BuildChime();
            new SoundPlayer(new MemoryStream(_chime)).Play();
        }
        catch { }
    }

    static byte[] BuildChime()
    {
        const int sr = 44100;
        int n = (int)(sr * 1.1);
        var pcm = new short[n];
        foreach (var (freq, start) in new[] { (880.0, 0.0), (1318.5, 0.18) })
        {
            int s0 = (int)(start * sr);
            for (int i = s0; i < n; i++)
            {
                double t = (i - s0) / (double)sr;
                double v = Math.Sin(2 * Math.PI * freq * t) * Math.Exp(-t / 0.28) * Math.Min(1, t / 0.005) * 0.22;
                pcm[i] = (short)Math.Clamp(pcm[i] + v * short.MaxValue, short.MinValue, short.MaxValue);
            }
        }
        using var ms = new MemoryStream();
        using var w = new BinaryWriter(ms);
        w.Write("RIFF"u8.ToArray()); w.Write(36 + n * 2); w.Write("WAVE"u8.ToArray());
        w.Write("fmt "u8.ToArray()); w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(sr); w.Write(sr * 2); w.Write((short)2); w.Write((short)16);
        w.Write("data"u8.ToArray()); w.Write(n * 2);
        foreach (var s in pcm) w.Write(s);
        return ms.ToArray();
    }
}
