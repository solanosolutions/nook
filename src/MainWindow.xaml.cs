using System;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using Windows.Media;
using Forms = System.Windows.Forms;

namespace Nook;

public partial class MainWindow : Window
{
    static readonly Color Solid = Color.FromArgb(0xF2, 0x16, 0x16, 0x16);   // hover: cor "normal"
    static readonly Color Glass = Color.FromArgb(0x50, 0x16, 0x16, 0x16);   // repouso com blur
    static readonly Color Dim = Color.FromArgb(0xD0, 0x16, 0x16, 0x16);     // repouso sem blur
    static readonly Duration Fade = TimeSpan.FromMilliseconds(220);

    readonly MediaService _media = new();
    readonly DispatcherTimer _tick = new() { Interval = TimeSpan.FromMilliseconds(250) };
    readonly AudioCapture _audio = new();
    readonly DispatcherTimer _vizTick = new(DispatcherPriority.Render) { Interval = TimeSpan.FromMilliseconds(33) };
    readonly System.Diagnostics.Stopwatch _vizClock = new();
    int _spotifyPid;
    readonly DispatcherTimer _fsTimer = new() { Interval = TimeSpan.FromMilliseconds(700) };
    readonly DispatcherTimer _idleTimer = new() { Interval = TimeSpan.FromSeconds(3) };
    readonly DispatcherTimer _cycleTimer = new() { Interval = TimeSpan.FromMilliseconds(Forms.SystemInformation.DoubleClickTime) };
    readonly DispatcherTimer _volumeTimer = new() { Interval = TimeSpan.FromMilliseconds(1200) };
    bool _userHidden, _fsHidden, _idleHidden, _autoOverride;
    bool _showingVolume;

    static readonly Color DefaultAccent = Color.FromRgb(0x1E, 0xD7, 0x60);
    readonly SolidColorBrush _accent = new(DefaultAccent);
    Color _accentTarget = DefaultAccent;
    string? _marqueeFor;
    SettingsWindow? _settingsWin;
    FocusWindow? _focus;
    bool _hover;

    static Settings S => App.Settings;

    public MainWindow()
    {
        InitializeComponent();

        SourceInitialized += (_, _) => Native.MakeToolWindow(this);
        SizeChanged += (_, _) => { Native.RoundCorners(this, 12); KeepOnScreen(); _focus?.Reposition(); };
        LocationChanged += (_, _) => _focus?.Reposition();
        Loaded += OnLoaded;

        MouseEnter += (_, _) => SetHover(true);
        MouseLeave += (_, _) => SetHover(false);
        MouseLeftButtonDown += OnDragOrDoubleClick;
        MouseRightButtonUp += (_, _) => OpenSettings();
        MouseWheel += OnWheel;

        ProgressFill.Background = _accent;
        Viz.Accent = _accent;

        _media.Changed += () => Dispatcher.InvokeAsync(Refresh);
        _tick.Tick += (_, _) => UpdateProgress();

        _vizTick.Tick += (_, _) =>
        {
            double dt = _vizClock.Elapsed.TotalSeconds;
            _vizClock.Restart();
            Viz.Step(_audio.Bands, dt);
        };
        _audio.FailedChanged += () => Dispatcher.InvokeAsync(UpdateViz);
        IsVisibleChanged += (_, _) => { UpdateViz(); UpdateTitleMotion(); SyncFocus(); };

        _fsTimer.Tick += (_, _) =>
        {
            bool fs = S.HideOnFullscreen && _settingsWin == null && Native.IsFullscreenOnMyMonitor(this);
            if (fs == _fsHidden) return;
            _fsHidden = fs;
            ApplyVisibility();
        };
        _idleTimer.Tick += (_, _) => { _idleTimer.Stop(); _idleHidden = true; ApplyVisibility(); };
        _cycleTimer.Tick += (_, _) => { _cycleTimer.Stop(); CycleVisual(); };
        _volumeTimer.Tick += (_, _) => { _volumeTimer.Stop(); _showingVolume = false; Refresh(); };
    }

    // ---------- Visibilidade: escondido por você (bandeja), pela tela cheia ou sem player ----------

    void ApplyVisibility()
    {
        if (!_fsHidden && !_idleHidden) _autoOverride = false; // a exceção da bandeja vale até a condição passar
        bool auto = (_fsHidden || _idleHidden) && !_autoOverride;
        bool show = !_userHidden && !auto;
        if (show && !IsVisible) Show();
        else if (!show && IsVisible) Hide();
    }

    /// <summary>Some (após 3 s, para não piscar em troca de sessão) quando não há player aberto.</summary>
    void UpdateIdle()
    {
        bool idle = S.HideWhenIdle && !_media.HasSession;
        if (idle) { if (!_idleHidden && !_idleTimer.IsEnabled) _idleTimer.Start(); return; }
        _idleTimer.Stop();
        if (_idleHidden) { _idleHidden = false; ApplyVisibility(); }
    }

    async void OnLoaded(object? sender, RoutedEventArgs e)
    {
        ApplySettings();
        PlaceInitially();
        try { await _media.InitAsync(); } catch { }
        Refresh();
        _tick.Start();

        // Depois que tudo carregou (capa inclusa), solta o que só a abertura precisou.
        await System.Threading.Tasks.Task.Delay(TimeSpan.FromSeconds(8));
        Native.TrimMemory();
    }

    // ---------- Configurações ----------

    public void ApplySettings()
    {
        CoverBox.Visibility = Vis(S.ShowCover);
        InfoPanel.Visibility = Vis(S.ShowTitle);
        ShuffleBtn.Visibility = Vis(S.ShowShuffle);
        PrevBtn.Visibility = Vis(S.ShowPrev);
        PlayBtn.Visibility = Vis(S.ShowPlay);
        NextBtn.Visibility = Vis(S.ShowNext);
        RepeatBtn.Visibility = Vis(S.ShowRepeat);
        ProgressHost.Visibility = Vis(S.ShowProgress);
        OpenBtn.Visibility = Vis(S.ShowOpen);
        GearBtn.Visibility = Vis(S.ShowGear);
        Divider.Visibility = Vis(S.ShowOpen || S.ShowGear);

        ScaleXf.ScaleX = ScaleXf.ScaleY = S.Scale;
        Topmost = S.Topmost;
        Native.SetBlur(this, S.Blur);
        ApplyLook(animate: false);
        App.UpdateTray();
        _audio.Failed = false; // mudar configuração dá nova chance à captura
        UpdateViz();

        if (S.HideOnFullscreen) _fsTimer.Start();
        else { _fsTimer.Stop(); _fsHidden = false; ApplyVisibility(); }
        UpdateIdle();
        UpdateAccent();
        UpdateFocusWindow();
    }

    // ---------- Timer de foco ----------

    void UpdateFocusWindow()
    {
        if (S.FocusTimer && _focus == null) _focus = new FocusWindow(this, _accent);
        else if (!S.FocusTimer && _focus != null) { _focus.Close(); _focus = null; }
        _focus?.ApplySettings();
        SyncFocus();
    }

    /// <summary>O timer aparece junto com o player, e some enquanto o menu está aberto (ocuparia o mesmo lugar).</summary>
    void SyncFocus()
    {
        if (_focus == null) return;
        bool show = IsVisible && _settingsWin == null;
        if (show && !_focus.IsVisible) _focus.Show();
        else if (!show && _focus.IsVisible) _focus.Hide();
        _focus.Reposition();
    }

    public Rect WorkAreaRect() => WorkArea();

    // ---------- Cor de destaque (verde ou cor da capa) ----------

    void UpdateAccent()
    {
        var target = S.CoverAccent && _media.CoverColor is Color c ? c : DefaultAccent;
        if (target == _accentTarget) return;
        _accentTarget = target;
        _accent.BeginAnimation(SolidColorBrush.ColorProperty, new ColorAnimation(target, TimeSpan.FromMilliseconds(500)));
    }

    // ---------- Título: título longo rola sozinho; mouse em cima, ele para ----------

    const double TickerGap = 40, TickerSpeed = 30; // px entre as cópias, px/s

    /// <summary>Rola só quando precisa: título maior que o espaço, música tocando, player visível e sem mouse em cima.</summary>
    void UpdateTitleMotion()
    {
        string text = TitleText.Text;
        double room = TitleClip.Width;
        bool scroll = !_hover && _media.IsPlaying && IsVisible && TextWidth(text) > room + 1;

        if (!scroll) { StopTicker(); return; }
        if (_marqueeFor == text) return; // já rolando este título

        StopTicker();
        _marqueeFor = text;
        double full = TextWidth(text), cycle = full + TickerGap;
        TitleText.Width = double.NaN;
        TitleText.TextTrimming = TextTrimming.None;
        TitleCopy.Text = text;
        TitleCopy.Visibility = Visibility.Visible;

        var anim = new DoubleAnimation(0, -cycle, TimeSpan.FromSeconds(cycle / TickerSpeed))
        {
            BeginTime = TimeSpan.FromSeconds(1.5),       // deixa ler o começo antes de andar
            RepeatBehavior = RepeatBehavior.Forever,      // a cópia ocupa o lugar do original: loop sem pulo
        };
        Timeline.SetDesiredFrameRate(anim, 30);           // 30 fps basta para texto e corta o custo pela metade
        TitleShift.BeginAnimation(TranslateTransform.XProperty, anim);
    }

    void StopTicker()
    {
        if (_marqueeFor == null && TitleCopy.Visibility != Visibility.Visible) return;
        _marqueeFor = null;
        TitleShift.BeginAnimation(TranslateTransform.XProperty, null);
        TitleShift.X = 0;
        TitleCopy.Visibility = Visibility.Collapsed;
        TitleText.Width = TitleClip.Width;
        TitleText.TextTrimming = TextTrimming.CharacterEllipsis;
    }

    double TextWidth(string s) => new FormattedText(s, System.Globalization.CultureInfo.CurrentUICulture,
            FlowDirection.LeftToRight,
            new Typeface(TitleText.FontFamily, TitleText.FontStyle, TitleText.FontWeight, TitleText.FontStretch),
            TitleText.FontSize, Brushes.White, VisualTreeHelper.GetDpi(this).PixelsPerDip)
        .WidthIncludingTrailingWhitespace;

    // ---------- Clique na capa: Capa → Barras → Ondas ----------

    void CycleVisual()
    {
        if (!_media.IsPlaying) return; // pausado a capa sempre aparece; trocar não teria efeito visível
        S.Visual = S.Visual switch { "Cover" => "Bars", "Bars" => "Waves", _ => "Cover" };
        S.Save();
        UpdateViz();
    }

    // ---------- Roda do mouse: volume do Spotify (ou do Windows para outros players) ----------

    void OnWheel(object sender, MouseWheelEventArgs e)
    {
        if (!S.WheelVolume) return;
        bool up = e.Delta > 0;
        try
        {
            if (_media.IsSpotify && SpotifyVolume.TryStep(up ? 0.04f : -0.04f, out int pct))
            {
                ShowVolume(pct);
                return;
            }
        }
        catch { }
        Native.VolumeStep(up);
    }

    /// <summary>Reaplica os textos do player depois de trocar o idioma.</summary>
    public void ApplyLanguage()
    {
        ShuffleBtn.ToolTip = Strings.Get("Shuffle");
        PrevBtn.ToolTip = Strings.Get("Previous");
        PlayBtn.ToolTip = Strings.Get("PlayPause");
        NextBtn.ToolTip = Strings.Get("Next");
        RepeatBtn.ToolTip = Strings.Get("Repeat");
        OpenBtn.ToolTip = Strings.Get("OpenSpotify");
        GearBtn.ToolTip = Strings.Get("SettingsTip");
        _focus?.ApplyLanguage();
        Refresh();
    }

    void ShowVolume(int pct)
    {
        _showingVolume = true;
        ArtistText.Text = $"{Strings.Get("SpotifyVolume")}  {pct}%";
        _volumeTimer.Stop();
        _volumeTimer.Start();
    }

    // ---------- Visualizador (barras / ondas no quadrado da capa) ----------

    /// <summary>Liga a captura só quando faz sentido: modo visual, música tocando e player visível.</summary>
    void UpdateViz()
    {
        bool want = S.Visual != "Cover" && S.ShowCover && _media.HasSession && _media.IsPlaying
                    && IsVisible && !_audio.Failed;
        if (!want)
        {
            if (_audio.Running) _audio.Stop();
            _vizTick.Stop();
            Viz.Visibility = Visibility.Collapsed;
            CoverLayer.Opacity = 1;
            return;
        }

        _audio.Start(_media.IsSpotify ? SpotifyPid() : 0);
        Viz.Waves = S.Visual == "Waves";
        Viz.Visibility = Visibility.Visible;
        CoverLayer.Opacity = 0.2;
        if (!_vizTick.IsEnabled) { _vizClock.Restart(); _vizTick.Start(); }
    }

    /// <summary>Processo raiz do Spotify (o mais antigo); a captura inclui os filhos dele.</summary>
    int SpotifyPid()
    {
        try
        {
            if (_spotifyPid != 0 && !System.Diagnostics.Process.GetProcessById(_spotifyPid).HasExited)
                return _spotifyPid;
        }
        catch { }
        _spotifyPid = 0;
        DateTime oldest = DateTime.MaxValue;
        foreach (var p in System.Diagnostics.Process.GetProcessesByName("Spotify"))
        {
            try { if (p.StartTime < oldest) { oldest = p.StartTime; _spotifyPid = p.Id; } } catch { }
            p.Dispose();
        }
        return _spotifyPid;
    }

    static Visibility Vis(bool v) => v ? Visibility.Visible : Visibility.Collapsed;

    // ---------- Hover: vidro em repouso, cor normal no mouse ----------

    void SetHover(bool hover)
    {
        hover |= _settingsWin != null; // enquanto o menu está aberto, fica nítido
        if (hover == _hover) return;
        _hover = hover;
        ApplyLook(animate: true);
        UpdateTitleMotion();
    }

    void ApplyLook(bool animate)
    {
        var color = _hover ? Solid : (S.Blur ? Glass : Dim);
        double opacity = _hover ? 1.0 : S.IdleOpacity;
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

    // ---------- Arrastar, ímã nas bordas, duplo clique ----------

    int _lastDownTick;
    Point _lastDownPos;

    void OnDragOrDoubleClick(object sender, MouseButtonEventArgs e)
    {
        // DragMove engole o clique, então o WPF não conta ClickCount; medimos nós mesmos.
        int now = Environment.TickCount;
        var pos = PointToScreen(e.GetPosition(this));
        bool isDouble = now - _lastDownTick <= Forms.SystemInformation.DoubleClickTime
                        && (pos - _lastDownPos).Length < 6;
        _lastDownTick = isDouble ? 0 : now;
        _lastDownPos = pos;

        if (isDouble)
        {
            _cycleTimer.Stop(); // era duplo clique, não clique na capa
            e.Handled = true;
            Dispatcher.BeginInvoke(OpenSettings, DispatcherPriority.Input);
            return;
        }

        bool onCover = S.CoverClickCycles && CoverBox.IsMouseOver;
        double left = Left, top = Top;
        if (!S.LockPosition)
        {
            try { DragMove(); } catch { }
            SnapToEdges();
            SavePosition();
        }
        // Clique (sem arrastar) na capa: espera o tempo do duplo clique antes de trocar o visual.
        if (onCover && Math.Abs(Left - left) < 1 && Math.Abs(Top - top) < 1) _cycleTimer.Start();
    }

    Rect WorkArea()
    {
        var hwnd = new WindowInteropHelper(this).Handle;
        var wa = Forms.Screen.FromHandle(hwnd).WorkingArea;
        double dpi = VisualTreeHelper.GetDpi(this).DpiScaleX;
        return new Rect(wa.Left / dpi, wa.Top / dpi, wa.Width / dpi, wa.Height / dpi);
    }

    void SnapToEdges()
    {
        const double magnet = 20, gap = 10;
        var wa = WorkArea();
        if (Math.Abs(Left - wa.Left) < magnet) Left = wa.Left + gap;
        if (Math.Abs(wa.Right - (Left + ActualWidth)) < magnet) Left = wa.Right - ActualWidth - gap;
        if (Math.Abs(Top - wa.Top) < magnet) Top = wa.Top + gap;
        if (Math.Abs(wa.Bottom - (Top + ActualHeight)) < magnet) Top = wa.Bottom - ActualHeight - gap;
    }

    void KeepOnScreen()
    {
        if (!IsLoaded) return;
        var wa = WorkArea();
        if (Left + ActualWidth > wa.Right) Left = Math.Max(wa.Left, wa.Right - ActualWidth - 10);
        if (Top + ActualHeight > wa.Bottom) Top = Math.Max(wa.Top, wa.Bottom - ActualHeight - 10);
    }

    void PlaceInitially()
    {
        UpdateLayout();
        double vl = SystemParameters.VirtualScreenLeft, vt = SystemParameters.VirtualScreenTop;
        double vw = SystemParameters.VirtualScreenWidth, vh = SystemParameters.VirtualScreenHeight;
        if (S.Left is double l && S.Top is double t && l >= vl && t >= vt && l < vl + vw - 40 && t < vt + vh - 20)
        {
            Left = l; Top = t;
        }
        else
        {
            var wa = SystemParameters.WorkArea;
            Left = wa.Right - ActualWidth - 16;
            Top = wa.Bottom - ActualHeight - 16;
        }
    }

    void SavePosition() { S.Left = Left; S.Top = Top; S.Save(); }

    public void ToggleVisible()
    {
        _userHidden = IsVisible;
        if (!_userHidden && (_fsHidden || _idleHidden)) _autoOverride = true; // pediu para mostrar: respeita
        ApplyVisibility();
        if (IsVisible) Activate();
    }

    public void OpenSettings()
    {
        if (_settingsWin != null) { _settingsWin.Activate(); return; }
        _settingsWin = new SettingsWindow(this);
        SyncFocus();
        _settingsWin.Closed += (_, _) =>
        {
            _settingsWin = null;
            SetHover(IsMouseOver);
            SyncFocus();
            Dispatcher.BeginInvoke(Native.TrimMemory, DispatcherPriority.ApplicationIdle);
        };
        SetHover(true);
        _settingsWin.ShowNear(this, WorkArea());
    }

    // ---------- Estado da música ----------

    void Refresh()
    {
        if (!_media.HasSession || string.IsNullOrEmpty(_media.Title))
        {
            TitleText.Text = Strings.Get("NothingPlaying");
            if (!_showingVolume) ArtistText.Text = _media.HasSession ? "" : Strings.Get("ClickToOpen");
            CoverBrush.ImageSource = null;
        }
        else
        {
            TitleText.Text = _media.Title;
            if (!_showingVolume) ArtistText.Text = _media.Artist;
            CoverBrush.ImageSource = _media.Cover;
        }
        UpdateTitleMotion();
        CoverPlaceholder.Visibility = Vis(CoverBrush.ImageSource == null);
        InfoPanel.ToolTip = _media.HasSession ? $"{_media.Title}\n{_media.Artist}" : null;

        PlayBtn.Content = _media.IsPlaying ? "" : "";
        PrevBtn.IsEnabled = !_media.HasSession || _media.CanPrev;
        NextBtn.IsEnabled = !_media.HasSession || _media.CanNext;

        ShuffleBtn.Foreground = _media.ShuffleOn ? _accent : (Brush)FindResource("FgDim");
        RepeatBtn.Content = _media.Repeat == MediaPlaybackAutoRepeatMode.Track ? "" : "";
        RepeatBtn.Foreground = _media.Repeat == MediaPlaybackAutoRepeatMode.None
            ? (Brush)FindResource("FgDim") : _accent;

        UpdateProgress();
        UpdateViz();
        UpdateAccent();
        UpdateIdle();
    }

    void UpdateProgress()
    {
        if (!IsVisible || !S.ShowProgress) return;
        var dur = _media.Duration;
        var pos = _media.Position;
        ProgressScale.ScaleX = dur > TimeSpan.Zero ? Math.Clamp(pos / dur, 0, 1) : 0;
        ProgressHost.ToolTip = dur > TimeSpan.Zero ? $"{Fmt(pos)} / {Fmt(dur)}" : null;
    }

    static string Fmt(TimeSpan t) => t.TotalHours >= 1 ? t.ToString(@"h\:mm\:ss") : t.ToString(@"m\:ss");

    // ---------- Botões ----------

    async void Play_Click(object s, RoutedEventArgs e)
    {
        if (!_media.HasSession) { App.OpenSpotify(); return; }
        try { await _media.PlayPauseAsync(); } catch { }
    }
    async void Next_Click(object s, RoutedEventArgs e) { try { await _media.NextAsync(); } catch { } }
    async void Prev_Click(object s, RoutedEventArgs e) { try { await _media.PrevAsync(); } catch { } }
    async void Shuffle_Click(object s, RoutedEventArgs e) { try { await _media.ShuffleAsync(); } catch { } }
    async void Repeat_Click(object s, RoutedEventArgs e) { try { await _media.RepeatAsync(); } catch { } }
    void Open_Click(object s, RoutedEventArgs e) => App.OpenSpotify();
    void Gear_Click(object s, RoutedEventArgs e) => OpenSettings();

    async void Progress_MouseDown(object sender, MouseButtonEventArgs e)
    {
        e.Handled = true; // não inicia arraste
        double f = e.GetPosition(ProgressHost).X / ProgressHost.ActualWidth;
        try { await _media.SeekAsync(f); } catch { }
    }
}
