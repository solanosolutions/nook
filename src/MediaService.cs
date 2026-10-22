using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Windows.Media;
using Windows.Media.Control;
using Windows.Storage.Streams;

namespace Nook;

/// <summary>
/// Lê e controla a mídia pelo SMTC do Windows (o mesmo canal do painel de mídia do sistema).
/// Prioriza o Spotify; se ele não estiver aberto, usa a sessão de mídia atual.
/// </summary>
public sealed class MediaService
{
    GlobalSystemMediaTransportControlsSessionManager? _mgr;
    GlobalSystemMediaTransportControlsSession? _session;
    readonly object _lock = new();
    int _mediaVersion;

    TimeSpan _pos, _dur;
    DateTimeOffset _updated = DateTimeOffset.Now;

    /// <summary>Disparado (em thread de fundo) sempre que algo muda.</summary>
    public event Action? Changed;

    public bool HasSession => _session != null;
    public bool IsSpotify => _session?.SourceAppUserModelId?.Contains("spotify", StringComparison.OrdinalIgnoreCase) == true;
    public string Title { get; private set; } = "";
    public string Artist { get; private set; } = "";
    public ImageSource? Cover { get; private set; }
    /// <summary>Cor marcante da capa (ajustada para ficar viva no tema escuro); null se a capa for cinza/sem cor.</summary>
    public Color? CoverColor { get; private set; }
    public bool IsPlaying { get; private set; }
    public bool ShuffleOn { get; private set; }
    public MediaPlaybackAutoRepeatMode Repeat { get; private set; }
    public bool CanShuffle { get; private set; }
    public bool CanRepeat { get; private set; }
    public bool CanSeek { get; private set; }
    public bool CanPrev { get; private set; }
    public bool CanNext { get; private set; }
    public TimeSpan Duration => _dur;

    public TimeSpan Position
    {
        get
        {
            var p = _pos;
            if (IsPlaying) p += DateTimeOffset.Now - _updated;
            if (_dur > TimeSpan.Zero && p > _dur) p = _dur;
            return p < TimeSpan.Zero ? TimeSpan.Zero : p;
        }
    }

    public async Task InitAsync()
    {
        _mgr = await GlobalSystemMediaTransportControlsSessionManager.RequestAsync();
        _mgr.SessionsChanged += (_, _) => Pick();
        _mgr.CurrentSessionChanged += (_, _) => Pick();
        Pick();
    }

    void Pick()
    {
        if (_mgr == null) return;
        GlobalSystemMediaTransportControlsSession? s;
        try
        {
            s = _mgr.GetSessions().FirstOrDefault(x =>
                    x.SourceAppUserModelId?.Contains("spotify", StringComparison.OrdinalIgnoreCase) == true)
                ?? _mgr.GetCurrentSession();
        }
        catch { s = null; }

        lock (_lock)
        {
            if (ReferenceEquals(s, _session)) return;
            if (_session != null)
            {
                _session.MediaPropertiesChanged -= OnMedia;
                _session.PlaybackInfoChanged -= OnPlayback;
                _session.TimelinePropertiesChanged -= OnTimeline;
            }
            _session = s;
            if (s != null)
            {
                s.MediaPropertiesChanged += OnMedia;
                s.PlaybackInfoChanged += OnPlayback;
                s.TimelinePropertiesChanged += OnTimeline;
            }
        }

        if (s == null)
        {
            Title = ""; Artist = ""; Cover = null; CoverColor = null; IsPlaying = false; _pos = _dur = TimeSpan.Zero;
            Changed?.Invoke();
            return;
        }
        ReadPlayback(s);
        ReadTimeline(s);
        Changed?.Invoke();
        _ = ReadMediaAsync(s);
    }

    void OnMedia(GlobalSystemMediaTransportControlsSession s, MediaPropertiesChangedEventArgs e) => _ = ReadMediaAsync(s);
    void OnPlayback(GlobalSystemMediaTransportControlsSession s, PlaybackInfoChangedEventArgs e) { ReadPlayback(s); Changed?.Invoke(); }
    void OnTimeline(GlobalSystemMediaTransportControlsSession s, TimelinePropertiesChangedEventArgs e) { ReadTimeline(s); Changed?.Invoke(); }

    async Task ReadMediaAsync(GlobalSystemMediaTransportControlsSession s)
    {
        int v = System.Threading.Interlocked.Increment(ref _mediaVersion);
        try
        {
            var p = await s.TryGetMediaPropertiesAsync();
            if (p == null || v != _mediaVersion) return;
            Title = p.Title ?? "";
            Artist = p.Artist ?? "";
            Changed?.Invoke();

            var img = await LoadThumbAsync(p.Thumbnail);
            if (v != _mediaVersion) return;
            Cover = img;
            CoverColor = img is BitmapSource bs ? VividColor(bs) : null;
            Changed?.Invoke();
        }
        catch { }
    }

    static async Task<ImageSource?> LoadThumbAsync(IRandomAccessStreamReference? thumb)
    {
        if (thumb == null) return null;
        using var ras = await thumb.OpenReadAsync();
        using var src = ras.AsStreamForRead();
        var ms = new MemoryStream();
        await src.CopyToAsync(ms);
        ms.Position = 0;
        var bmp = new BitmapImage();
        bmp.BeginInit();
        bmp.CacheOption = BitmapCacheOption.OnLoad;
        bmp.DecodePixelWidth = 128;
        bmp.StreamSource = ms;
        bmp.EndInit();
        bmp.Freeze();
        return bmp;
    }

    /// <summary>
    /// Agrupa os pixels por matiz (36 faixas de 10°), pesando por saturação×brilho,
    /// e devolve a média da faixa dominante com saturação/brilho reforçados.
    /// </summary>
    static Color? VividColor(BitmapSource src)
    {
        var bmp = new FormatConvertedBitmap(src, PixelFormats.Bgra32, null, 0);
        int w = bmp.PixelWidth, h = bmp.PixelHeight, stride = w * 4;
        var px = new byte[stride * h];
        bmp.CopyPixels(px, stride, 0);

        var weight = new double[36];
        var r = new double[36]; var g = new double[36]; var b = new double[36];
        int samples = 0;
        for (int y = 0; y < h; y += 2)
            for (int x = 0; x < w; x += 2)
            {
                int i = y * stride + x * 4;
                samples++;
                ToHsv(px[i + 2], px[i + 1], px[i], out double hue, out double sat, out double val);
                if (sat < 0.25 || val < 0.2) continue; // ignora cinzas e pretos
                int k = (int)(hue / 10) % 36;
                double wgt = sat * val;
                weight[k] += wgt; r[k] += px[i + 2] * wgt; g[k] += px[i + 1] * wgt; b[k] += px[i] * wgt;
            }

        int best = -1; double bestW = 0;
        for (int k = 0; k < 36; k++)
        {
            double around = weight[(k + 35) % 36] + weight[k] + weight[(k + 1) % 36];
            if (around > bestW && weight[k] > 0) { bestW = around; best = k; }
        }
        if (best < 0 || bestW < samples * 0.03) return null; // capa praticamente sem cor

        ToHsv(r[best] / weight[best], g[best] / weight[best], b[best] / weight[best], out double hh, out double ss, out double vv);
        return FromHsv(hh, Math.Max(ss, 0.55), Math.Max(vv, 0.85));
    }

    static void ToHsv(double r, double g, double b, out double h, out double s, out double v)
    {
        r /= 255; g /= 255; b /= 255;
        double max = Math.Max(r, Math.Max(g, b)), min = Math.Min(r, Math.Min(g, b)), d = max - min;
        v = max; s = max == 0 ? 0 : d / max;
        if (d == 0) h = 0;
        else if (max == r) h = 60 * (((g - b) / d + 6) % 6);
        else if (max == g) h = 60 * ((b - r) / d + 2);
        else h = 60 * ((r - g) / d + 4);
    }

    static Color FromHsv(double h, double s, double v)
    {
        double c = v * s, x = c * (1 - Math.Abs(h / 60 % 2 - 1)), m = v - c;
        (double r, double g, double b) = (int)(h / 60) switch
        {
            0 => (c, x, 0.0), 1 => (x, c, 0.0), 2 => (0.0, c, x),
            3 => (0.0, x, c), 4 => (x, 0.0, c), _ => (c, 0.0, x),
        };
        return Color.FromRgb((byte)((r + m) * 255), (byte)((g + m) * 255), (byte)((b + m) * 255));
    }

    void ReadPlayback(GlobalSystemMediaTransportControlsSession s)
    {
        try
        {
            var pi = s.GetPlaybackInfo();
            bool playing = pi.PlaybackStatus == GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing;
            if (playing != IsPlaying) { _pos = Position; _updated = DateTimeOffset.Now; }
            IsPlaying = playing;
            ShuffleOn = pi.IsShuffleActive ?? false;
            Repeat = pi.AutoRepeatMode ?? MediaPlaybackAutoRepeatMode.None;
            var c = pi.Controls;
            CanShuffle = c.IsShuffleEnabled;
            CanRepeat = c.IsRepeatEnabled;
            CanSeek = c.IsPlaybackPositionEnabled;
            CanPrev = c.IsPreviousEnabled;
            CanNext = c.IsNextEnabled;
        }
        catch { }
    }

    void ReadTimeline(GlobalSystemMediaTransportControlsSession s)
    {
        try
        {
            var t = s.GetTimelineProperties();
            _dur = t.EndTime - t.StartTime;
            _pos = t.Position;
            _updated = t.LastUpdatedTime > DateTimeOffset.Now ? DateTimeOffset.Now : t.LastUpdatedTime;
        }
        catch { }
    }

    // ---- Comandos ----
    public async Task PlayPauseAsync() { if (_session != null) await _session.TryTogglePlayPauseAsync(); }
    public async Task NextAsync() { if (_session != null) await _session.TrySkipNextAsync(); }
    public async Task PrevAsync() { if (_session != null) await _session.TrySkipPreviousAsync(); }
    public async Task ShuffleAsync() { if (_session != null) await _session.TryChangeShuffleActiveAsync(!ShuffleOn); }

    public async Task RepeatAsync()
    {
        if (_session == null) return;
        var next = Repeat switch
        {
            MediaPlaybackAutoRepeatMode.None => MediaPlaybackAutoRepeatMode.List,
            MediaPlaybackAutoRepeatMode.List => MediaPlaybackAutoRepeatMode.Track,
            _ => MediaPlaybackAutoRepeatMode.None,
        };
        await _session.TryChangeAutoRepeatModeAsync(next);
    }

    public async Task SeekAsync(double fraction)
    {
        if (_session == null || _dur <= TimeSpan.Zero) return;
        var target = TimeSpan.FromTicks((long)(_dur.Ticks * Math.Clamp(fraction, 0, 1)));
        _pos = target; _updated = DateTimeOffset.Now;
        Changed?.Invoke();
        await _session.TryChangePlaybackPositionAsync(target.Ticks);
    }
}
