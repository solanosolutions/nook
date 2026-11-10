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
    static readonly Duration Fade = TimeSpan.FromMilliseconds(220);

    readonly MediaService _media = new();
    readonly DispatcherTimer _tick = new() { Interval = TimeSpan.FromMilliseconds(250) };
    readonly AudioCapture _audio = new();
    readonly DispatcherTimer _vizTick = new(DispatcherPriority.Render) { Interval = TimeSpan.FromMilliseconds(33) };
    readonly System.Diagnostics.Stopwatch _vizClock = new();
    int _spotifyPid;
    readonly DispatcherTimer _fsTimer = new() { Interval = TimeSpan.FromMilliseconds(700) };
    readonly DispatcherTimer _idleTimer = new() { Interval = TimeSpan.FromSeconds(3) };
    readonly DispatcherTimer _volumeTimer = new() { Interval = TimeSpan.FromMilliseconds(1200) };
    readonly DispatcherTimer _pauseTimer = new();
    bool _userHidden, _fsHidden, _idleHidden, _pausedHidden, _manualHidden, _autoOverride;
    bool _wasPlaying, _vertical, _compact, _layoutApplied;
    bool _peek; // modo recolhido aberto pelo mouse
    readonly DispatcherTimer _peekTimer = new() { Interval = TimeSpan.FromMilliseconds(200) };
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
        SizeChanged += (_, e) => { Native.RoundCorners(this, 12); KeepAnchor(e.PreviousSize); KeepOnScreen(); _focus?.Reposition();
            if (IsLoaded && Compact) SavePosition(); // guarda onde a pílula ficou depois de recolher
        };
        LocationChanged += (_, _) => _focus?.Reposition();
        Loaded += OnLoaded;

        MouseEnter += (_, _) => { SetHover(true); UpdatePeek(); };
        MouseLeave += (_, _) => { SetHover(false); UpdatePeek(); };
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
        _pauseTimer.Tick += (_, _) => { _pauseTimer.Stop(); _pausedHidden = true; ApplyVisibility(); };
        _volumeTimer.Tick += (_, _) => { _volumeTimer.Stop(); _showingVolume = false; Refresh(); };
        _peekTimer.Tick += (_, _) => ForceCollapseCheck();
    }

    // ---------- Pin: fixado = player completo; solto = só capa e play, abre ao passar o mouse ----------

    /// <summary>Recolhido de fato agora: pin solto, sem mouse em cima e sem menu aberto.</summary>
    bool Compact => S.Collapsed && !_peek && _settingsWin == null;

    /// <summary>Mouse entra: abre na hora. Mouse sai: espera um pouco antes de recolher, para não piscar.</summary>
    void UpdatePeek()
    {
        bool over = IsMouseOver || _settingsWin != null;
        if (over) { _peekTimer.Stop(); SetPeek(true); }
        else if (_peek && !_peekTimer.IsEnabled) _peekTimer.Start();
    }

    void SetPeek(bool peek)
    {
        if (peek == _peek) return;
        _peek = peek;
        ApplyElements();
        UpdateLayout();
    }

    void ForceCollapseCheck()
    {
        _peekTimer.Stop();
        if (!IsMouseOver && _settingsWin == null) SetPeek(false);
    }

    void Collapse_Click(object s, RoutedEventArgs e)
    {
        S.Collapsed = !S.Collapsed;
        S.Save();
        ApplyElements();
    }

    /// <summary>
    /// Mudou de tamanho (recolher, abrir, layout, escala): mantém fixo o canto mais perto da borda da tela,
    /// para o player crescer "para dentro" em vez de pular de lugar.
    /// </summary>
    void KeepAnchor(Size before)
    {
        if (!IsLoaded || before.Width <= 0 || before.Height <= 0) return;
        var wa = WorkArea();
        if (Left + before.Width / 2 > wa.Left + wa.Width / 2) Left -= ActualWidth - before.Width;
        if (Top + before.Height / 2 > wa.Top + wa.Height / 2) Top -= ActualHeight - before.Height;
    }

    // ---------- Visibilidade: escondido por você (bandeja), pela tela cheia ou sem player ----------

    void ApplyVisibility()
    {
        if (!_fsHidden && !_idleHidden && !_pausedHidden) _autoOverride = false; // a exceção da bandeja vale até a condição passar
        bool auto = (_fsHidden || _idleHidden || _pausedHidden) && !_autoOverride;
        bool show = !_userHidden && !_manualHidden && !auto;
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

    /// <summary>
    /// Pausado por N minutos (com player aberto) → some. Qualquer play (Spotify, teclas de mídia, Nook) traz de volta,
    /// inclusive quando foi escondido pelo botão.
    /// </summary>
    void UpdatePauseHide()
    {
        bool playing = _media.IsPlaying;
        if (playing && !_wasPlaying) _manualHidden = false;
        _wasPlaying = playing;

        bool paused = S.AutoHideMinutes > 0 && _media.HasSession && !playing;
        if (paused)
        {
            if (!_pausedHidden && !_pauseTimer.IsEnabled)
            {
                _pauseTimer.Interval = TimeSpan.FromMinutes(S.AutoHideMinutes);
                _pauseTimer.Start();
            }
        }
        else
        {
            _pauseTimer.Stop();
            _pausedHidden = false;
        }
        ApplyVisibility();
    }

    void Hide_Click(object s, RoutedEventArgs e)
    {
        _manualHidden = true;
        ApplyVisibility();
    }

    // ---------- Layout: horizontal (padrão) ou vertical ----------

    static void Detach(FrameworkElement el)
    {
        if (el.Parent is System.Windows.Controls.Panel p) p.Children.Remove(el);
    }

    /// <summary>Move os mesmos elementos entre os dois arranjos e ajusta tamanhos (capa grande e texto centralizado no vertical).</summary>
    void ApplyLayout()
    {
        bool compact = Compact;
        bool v = S.Layout == "V" && !compact; // recolhido é sempre a pílula horizontal
        if (_layoutApplied && v == _vertical && compact == _compact) return;
        _vertical = v;
        _compact = compact;
        _layoutApplied = true;
        StopTicker();

        FrameworkElement[] all = { CoverBox, InfoPanel, ShuffleBtn, PrevBtn, PlayBtn, NextBtn, RepeatBtn, Divider, OpenBtn, GearBtn, HideBtn, CollapseBtn };
        foreach (var el in all) Detach(el);

        if (v)
        {
            VCover.Children.Add(CoverBox);
            VInfo.Children.Add(InfoPanel);
            foreach (var el in new FrameworkElement[] { PrevBtn, PlayBtn, NextBtn }) VMain.Children.Add(el);
            foreach (var el in new FrameworkElement[] { ShuffleBtn, RepeatBtn, Divider, OpenBtn, GearBtn, HideBtn, CollapseBtn }) VExtras.Children.Add(el);
        }
        else
        {
            foreach (var el in all) HHost.Children.Add(el);
        }

        double cover = v ? 156 : 36, info = v ? 156 : 170;
        CoverBox.Width = CoverBox.Height = cover;
        CoverBox.CornerRadius = CoverLayer.CornerRadius = new CornerRadius(v ? 10 : 7);
        CoverBox.Margin = v ? new Thickness(0, 2, 0, 0) : new Thickness(0, 0, compact ? 4 : 10, 0);
        CoverPlaceholder.FontSize = v ? 40 : 15;
        InfoPanel.Width = TitleClip.Width = info;
        InfoPanel.Margin = v ? new Thickness(0, 10, 0, 4) : new Thickness(0, 0, 8, 0);
        TitleText.Width = info;
        TitleText.TextAlignment = ArtistText.TextAlignment = v ? TextAlignment.Center : TextAlignment.Left;
        PlayBtn.Margin = v ? new Thickness(10, 0, 10, 0) : new Thickness(3, 0, 3, 0);
        HHost.Visibility = Vis(!v);
        VHost.Visibility = Vis(v);
        UpdateTitleMotion();
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

    /// <summary>O que aparece no player. Recolhido: só capa e play, independente das outras escolhas.</summary>
    void ApplyElements()
    {
        bool full = !Compact;
        CoverBox.Visibility = Vis(S.ShowCover || !full);
        InfoPanel.Visibility = Vis(S.ShowTitle && full);
        ShuffleBtn.Visibility = Vis(S.ShowShuffle && full);
        PrevBtn.Visibility = Vis(S.ShowPrev && full);
        PlayBtn.Visibility = Vis(S.ShowPlay || !full);
        NextBtn.Visibility = Vis(S.ShowNext && full);
        RepeatBtn.Visibility = Vis(S.ShowRepeat && full);
        ProgressHost.Visibility = Vis(S.ShowProgress && full);
        OpenBtn.Visibility = Vis(S.ShowOpen && full);
        GearBtn.Visibility = Vis(S.ShowGear && full);
        HideBtn.Visibility = Vis(S.ShowHideBtn && full);
        CollapseBtn.Visibility = Vis(full); // o pin sempre aparece no player aberto
        // Pin preenchido = fixado (completo); vazado = solto (recolhe e abre no mouse).
        CollapseBtn.Content = S.Collapsed ? "\uE718" : "\uE842";
        CollapseBtn.ToolTip = Strings.Get(S.Collapsed ? "PinTip" : "UnpinTip");
        ApplyLayout();
        Divider.Visibility = Vis(!_vertical && full);
        UpdateViz();
    }

    public void ApplySettings()
    {
        ApplyElements();

        ScaleXf.ScaleX = ScaleXf.ScaleY = S.Scale;
        Topmost = true; // sempre no topo
        ApplyGlass();
        ApplyLook(animate: false);
        App.UpdateTray();
        _audio.Failed = false; // mudar configuração dá nova chance à captura
        UpdateViz();

        if (S.HideOnFullscreen) _fsTimer.Start();
        else { _fsTimer.Stop(); _fsHidden = false; ApplyVisibility(); }
        UpdateIdle();
        _pauseTimer.Stop(); // novo tempo de "esconder pausado" vale a partir de agora
        UpdatePauseHide();
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
        Overlay.BeginAnimation(GlassOverlay.TintProperty, new ColorAnimation(target, TimeSpan.FromMilliseconds(500)));
    }

    // ---------- Estilo do vidro (Fosco · Frozen · Liquid) ----------

    void ApplyGlass()
    {
        Glass.ApplyNative(this);
        Root.BorderBrush = Glass.Rim(this);
        Overlay.StyleName = Glass.Style;
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

    // ---------- Roda do mouse: volume do player que está tocando (do Windows só se não achar o app) ----------

    void OnWheel(object sender, MouseWheelEventArgs e)
    {
        bool up = e.Delta > 0;
        try
        {
            if (AppVolume.TryStep(_media.SourceProcessName, up ? 0.04f : -0.04f, out int pct))
            {
                ShowVolume(pct);
                return;
            }
        }
        catch { }
        Native.VolumeStep(up);
    }

    void ShowVolume(int pct)
    {
        _showingVolume = true;
        ArtistText.Text = $"{Strings.Get(_media.IsSpotify ? "SpotifyVolume" : "Volume")}  {pct}%";
        _volumeTimer.Stop();
        _volumeTimer.Start();
    }

    // ---------- Visualizador (barras / ondas no quadrado da capa) ----------

    /// <summary>Liga a captura só quando faz sentido: modo visual, música tocando e player visível.</summary>
    void UpdateViz()
    {
        string visual = Look.Visual;
        bool want = visual != "Cover" && (S.ShowCover || Compact) && _media.HasSession && _media.IsPlaying
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
        Viz.Waves = visual == "Waves";
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

    // ---------- Hover: vidro em repouso, cor normal no mouse (opacidade sempre máxima) ----------

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
        var color = Glass.Fill(_hover);
        if (animate)
        {
            RootBrush.BeginAnimation(SolidColorBrush.ColorProperty, new ColorAnimation(color, Fade));
            Overlay.BeginAnimation(GlassOverlay.LiftProperty, new DoubleAnimation(_hover ? 1 : 0, Fade));
        }
        else
        {
            RootBrush.BeginAnimation(SolidColorBrush.ColorProperty, null);
            Overlay.BeginAnimation(GlassOverlay.LiftProperty, null);
            RootBrush.Color = color;
            Overlay.Lift = _hover ? 1 : 0;
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
            e.Handled = true;
            Dispatcher.BeginInvoke(OpenSettings, DispatcherPriority.Input);
            return;
        }

        if (!S.LockPosition)
        {
            try { DragMove(); } catch { }
            SnapToEdges();
            SavePosition();
        }
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

    /// <summary>No modo recolhido guarda a posição da pílula, que é como o Nook abre da próxima vez.</summary>
    void SavePosition()
    {
        if (S.Collapsed && !Compact) return;
        S.Left = Left; S.Top = Top; S.Save();
    }

    public void ToggleVisible()
    {
        _userHidden = IsVisible;
        if (!_userHidden)
        {
            _manualHidden = false;
            if (_fsHidden || _idleHidden || _pausedHidden) _autoOverride = true; // pediu para mostrar: respeita
        }
        ApplyVisibility();
        if (IsVisible) Activate();
    }

    public void OpenSettings()
    {
        if (_settingsWin != null) { _settingsWin.Activate(); return; }
        _settingsWin = new SettingsWindow(this);
        ApplyElements(); // recolhido: abre o player inteiro antes de posicionar o menu
        UpdateLayout();
        SyncFocus();
        _settingsWin.Closed += (_, _) =>
        {
            _settingsWin = null;
            SetHover(IsMouseOver);
            ForceCollapseCheck();
            ApplyElements();
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
        UpdatePauseHide();
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
