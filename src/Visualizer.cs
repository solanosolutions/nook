using System;
using System.Windows;
using System.Windows.Media;

namespace Nook;

/// <summary>Desenha barras ou ondas a partir dos níveis do AudioCapture.</summary>
public sealed class Visualizer : FrameworkElement
{
    static readonly Pen[] WhitePens =
    {
        Freeze(new Pen(Freeze(new SolidColorBrush(Color.FromArgb(0x60, 0xFF, 0xFF, 0xFF))), 1.2)),
        Freeze(new Pen(Freeze(new SolidColorBrush(Color.FromArgb(0xB0, 0xFF, 0xFF, 0xFF))), 1.4)),
    };

    /// <summary>Cor de destaque (verde padrão ou a cor da capa); pode ser animada.</summary>
    public Brush Accent { get; set; } = Brushes.LimeGreen;

    readonly float[] _levels = new float[AudioCapture.BandCount];
    double _time;

    public bool Waves { get; set; }

    /// <summary>Avança um quadro: sobe rápido, desce devagar (sensação de "peso").</summary>
    public void Step(float[] target, double dt)
    {
        for (int i = 0; i < _levels.Length; i++)
        {
            float t = i < target.Length ? target[i] : 0;
            float k = t > _levels[i] ? 0.55f : 0.12f;
            _levels[i] += (t - _levels[i]) * k;
        }
        _time += dt;
        InvalidateVisual();
    }

    protected override void OnRender(DrawingContext dc)
    {
        double w = ActualWidth, h = ActualHeight;
        if (w <= 0 || h <= 0) return;
        if (Waves) DrawWaves(dc, w, h); else DrawBars(dc, w, h);
    }

    void DrawBars(DrawingContext dc, double w, double h)
    {
        int n = _levels.Length;
        const double pad = 6, gap = 2.2;
        double bw = (w - 2 * pad - gap * (n - 1)) / n;
        for (int i = 0; i < n; i++)
        {
            double lh = Math.Max(bw, _levels[i] * (h - 2 * pad));
            double x = pad + i * (bw + gap);
            dc.DrawRoundedRectangle(Accent, null, new Rect(x, (h - lh) / 2, bw, lh), bw / 2, bw / 2);
        }
    }

    void DrawWaves(DrawingContext dc, double w, double h)
    {
        float low = (_levels[0] + _levels[1]) / 2, mid = _levels[2], high = (_levels[3] + _levels[4]) / 2;
        float[] amps = { high, mid, low };
        double[] freq = { 2.6, 1.8, 1.1 };
        double[] speed = { 4.2, 3.0, 2.1 };
        double cy = h / 2, maxA = h / 2 - 5;
        const int steps = 28;
        var accentPen = new Pen(Accent, 1.8);

        for (int k = 0; k < 3; k++)
        {
            double a = Math.Max(0.6, amps[k] * maxA);
            var geo = new StreamGeometry();
            using (var g = geo.Open())
            {
                for (int s = 0; s <= steps; s++)
                {
                    double u = (double)s / steps;
                    double env = Math.Sin(Math.PI * u); // afina nas pontas
                    var p = new Point(4 + u * (w - 8), cy + Math.Sin(u * freq[k] * 2 * Math.PI + _time * speed[k]) * a * env);
                    if (s == 0) g.BeginFigure(p, false, false); else g.LineTo(p, true, true);
                }
            }
            geo.Freeze();
            dc.DrawGeometry(null, k < 2 ? WhitePens[k] : accentPen, geo);
        }
    }

    static T Freeze<T>(T f) where T : Freezable { f.Freeze(); return f; }
}
