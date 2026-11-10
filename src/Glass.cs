using System;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace Nook;

/// <summary>
/// Os três estilos fixos do Nook. Cada um junta um vidro e o que aparece no quadrado da capa:
/// Minimalist = vidro fosco + barras · Old School = vidro Frozen + só a capa · Refined = vidro Liquid + ondas.
/// </summary>
static class Look
{
    public const string Minimalist = "Minimalist", OldSchool = "OldSchool", Refined = "Refined";

    public static bool IsValid(string? s) => s is Minimalist or OldSchool or Refined;
    public static string Current => IsValid(App.Settings.Style) ? App.Settings.Style! : Minimalist;

    /// <summary>Vidro do estilo atual.</summary>
    public static string Glass => Current switch { OldSchool => Nook.Glass.Frozen, Refined => Nook.Glass.Liquid, _ => Nook.Glass.Frosted };

    /// <summary>Quadrado da capa: "Bars", "Waves" ou "Cover" (só a arte, sem visualizador).</summary>
    public static string Visual => Current switch { OldSchool => "Cover", Refined => "Waves", _ => "Bars" };
}

/// <summary>
/// Vidros: "Frosted" (fosco, o original), "Frozen" (gelo: mais opaco, frio e granulado)
/// e "Liquid" (vidro vivo: borda de luz, brilho especular no topo, sombra interna e reflexo da capa).
/// Tudo é desenhado uma vez (sem animação contínua), então o custo de CPU fica igual ao fosco.
/// O vidro vem do estilo (<see cref="Look"/>) e o blur fica sempre ligado.
/// </summary>
static class Glass
{
    public const string Frosted = "Frosted", Frozen = "Frozen", Liquid = "Liquid";

    public static string Style => Look.Glass;

    /// <summary>Opacidade em repouso: fixa no máximo de transparência (o menor valor do antigo slider). Hover = 100%.</summary>
    public const double IdleOpacity = 0.15;

    /// <summary>Cor de fundo do vidro: hover = nítido; repouso = translúcido sobre o blur.</summary>
    public static Color Fill(bool hover) => (Style, hover) switch
    {
        (Frozen, true) => Color.FromArgb(0xF2, 0x19, 0x20, 0x28),
        (Frozen, false) => Color.FromArgb(0x8C, 0x1B, 0x24, 0x2E),
        (Liquid, true) => Color.FromArgb(0xEB, 0x14, 0x15, 0x17),
        (Liquid, false) => Color.FromArgb(0x46, 0x12, 0x13, 0x16),
        (_, true) => Color.FromArgb(0xF2, 0x16, 0x16, 0x16),
        _ => Color.FromArgb(0x50, 0x16, 0x16, 0x16),
    };

    static readonly Brush FrozenRim = Frz(new SolidColorBrush(Color.FromArgb(0x38, 0xD6, 0xEB, 0xFF)));
    static readonly Brush LiquidRim = Frz(new LinearGradientBrush(new GradientStopCollection
    {
        new(Color.FromArgb(0x99, 0xFF, 0xFF, 0xFF), 0.0),
        new(Color.FromArgb(0x1A, 0xFF, 0xFF, 0xFF), 0.45),
        new(Color.FromArgb(0x14, 0xFF, 0xFF, 0xFF), 0.6),
        new(Color.FromArgb(0x59, 0xFF, 0xFF, 0xFF), 1.0),
    }, new Point(0, 0), new Point(1, 1)));

    /// <summary>Borda da janela. Liquid ganha a "borda de luz" em gradiente.</summary>
    public static Brush Rim(FrameworkElement owner) => Style switch
    {
        Frozen => FrozenRim,
        Liquid => LiquidRim,
        _ => (Brush)owner.FindResource("Hairline"),
    };

    /// <summary>Blur do sistema. Frozen usa o acrylic (desfoque mais forte) com tinta fria.</summary>
    public static void ApplyNative(Window w) =>
        Native.SetBlur(w, true, acrylic: Style == Frozen, tint: Color.FromArgb(0x40, 0x1C, 0x25, 0x30));

    internal static T Frz<T>(T f) where T : Freezable { f.Freeze(); return f; }
}

/// <summary>Camada desenhada por cima do fundo e por baixo do conteúdo (não recebe clique).</summary>
public sealed class GlassOverlay : FrameworkElement
{
    public static readonly DependencyProperty StyleNameProperty = DependencyProperty.Register(
        nameof(StyleName), typeof(string), typeof(GlassOverlay),
        new FrameworkPropertyMetadata(Glass.Frosted, FrameworkPropertyMetadataOptions.AffectsRender));
    public static readonly DependencyProperty RadiusProperty = DependencyProperty.Register(
        nameof(Radius), typeof(double), typeof(GlassOverlay),
        new FrameworkPropertyMetadata(11.0, FrameworkPropertyMetadataOptions.AffectsRender));
    /// <summary>Cor do reflexo do Liquid (acompanha a cor da capa).</summary>
    public static readonly DependencyProperty TintProperty = DependencyProperty.Register(
        nameof(Tint), typeof(Color), typeof(GlassOverlay),
        new FrameworkPropertyMetadata(Color.FromRgb(0x1E, 0xD7, 0x60), FrameworkPropertyMetadataOptions.AffectsRender));
    /// <summary>0 em repouso, 1 no hover: o brilho do Liquid "incha" um pouco.</summary>
    public static readonly DependencyProperty LiftProperty = DependencyProperty.Register(
        nameof(Lift), typeof(double), typeof(GlassOverlay),
        new FrameworkPropertyMetadata(0.0, FrameworkPropertyMetadataOptions.AffectsRender));

    public string StyleName { get => (string)GetValue(StyleNameProperty); set => SetValue(StyleNameProperty, value); }
    public double Radius { get => (double)GetValue(RadiusProperty); set => SetValue(RadiusProperty, value); }
    public Color Tint { get => (Color)GetValue(TintProperty); set => SetValue(TintProperty, value); }
    public double Lift { get => (double)GetValue(LiftProperty); set => SetValue(LiftProperty, value); }

    public GlassOverlay() { IsHitTestVisible = false; }

    protected override void OnRender(DrawingContext dc)
    {
        var r = new Rect(RenderSize);
        if (r.Width < 2 || r.Height < 2 || StyleName == Glass.Frosted) return;
        double rad = Math.Min(Radius, Math.Min(r.Width, r.Height) / 2);
        dc.PushClip(new RectangleGeometry(r, rad, rad));

        if (StyleName == Glass.Frozen)
        {
            dc.DrawRectangle(Noise, null, r);
            dc.DrawRectangle(FrostSheen, null, r);
        }
        else if (StyleName == Glass.Liquid)
        {
            double lift = Math.Clamp(Lift, 0, 1);

            // Reflexo colorido da capa, vindo da esquerda (onde ela fica).
            var glow = new RadialGradientBrush(
                Color.FromArgb((byte)(0x38 + 0x18 * lift), Tint.R, Tint.G, Tint.B),
                Color.FromArgb(0, Tint.R, Tint.G, Tint.B))
            { Center = new Point(0.08, 0.6), GradientOrigin = new Point(0.08, 0.6), RadiusX = 0.55, RadiusY = 1.3 };
            glow.Freeze();
            dc.DrawRectangle(glow, null, r);

            // Brilho especular no topo, mais forte no hover.
            var sheen = new LinearGradientBrush(new GradientStopCollection
            {
                new(Color.FromArgb((byte)(0x2E + 0x16 * lift), 0xFF, 0xFF, 0xFF), 0.0),
                new(Color.FromArgb((byte)(0x0E + 0x06 * lift), 0xFF, 0xFF, 0xFF), 0.42),
                new(Color.FromArgb(0, 0xFF, 0xFF, 0xFF), 0.5),
            }, new Point(0, 0), new Point(0, 1));
            sheen.Freeze();
            dc.DrawRectangle(sheen, null, r);

            // Sombra interna embaixo: dá volume e ajuda a leitura sobre fundo claro.
            dc.DrawRectangle(InnerShadow, null, r);

            // Linha de luz logo abaixo da borda superior (o "fio" de vidro).
            var inner = new Rect(r.X + 0.5, r.Y + 0.5, r.Width - 1, r.Height - 1);
            dc.DrawRoundedRectangle(null, InnerRim, inner, Math.Max(0, rad - 0.5), Math.Max(0, rad - 0.5));
        }
        dc.Pop();
    }

    static readonly Brush FrostSheen = Glass.Frz(new LinearGradientBrush(new GradientStopCollection
    {
        new(Color.FromArgb(0x1C, 0xE6, 0xF4, 0xFF), 0.0),
        new(Color.FromArgb(0x06, 0xE6, 0xF4, 0xFF), 0.55),
        new(Color.FromArgb(0x10, 0xE6, 0xF4, 0xFF), 1.0),
    }, new Point(0, 0), new Point(0, 1)));

    static readonly Brush InnerShadow = Glass.Frz(new LinearGradientBrush(new GradientStopCollection
    {
        new(Color.FromArgb(0, 0, 0, 0), 0.55),
        new(Color.FromArgb(0x38, 0, 0, 0), 1.0),
    }, new Point(0, 0), new Point(0, 1)));

    static readonly Pen InnerRim = Glass.Frz(new Pen(new LinearGradientBrush(new GradientStopCollection
    {
        new(Color.FromArgb(0x50, 0xFF, 0xFF, 0xFF), 0.0),
        new(Color.FromArgb(0, 0xFF, 0xFF, 0xFF), 0.35),
        new(Color.FromArgb(0, 0xFF, 0xFF, 0xFF), 0.8),
        new(Color.FromArgb(0x1C, 0xFF, 0xFF, 0xFF), 1.0),
    }, new Point(0, 0), new Point(0, 1)), 1));

    /// <summary>Granulado fino de gelo: um ladrilho de ruído claro/escuro em baixa opacidade.</summary>
    static readonly Brush Noise = MakeNoise();

    static Brush MakeNoise()
    {
        const int n = 96;
        var px = new byte[n * n * 4];
        var rnd = new Random(7);
        for (int i = 0; i < n * n; i++)
        {
            byte a = (byte)rnd.Next(0, 26);
            byte c = rnd.Next(2) == 0 ? (byte)0 : a; // premultiplicado: branco = a, preto = 0
            px[i * 4] = px[i * 4 + 1] = px[i * 4 + 2] = c;
            px[i * 4 + 3] = a;
        }
        var bmp = BitmapSource.Create(n, n, 96, 96, PixelFormats.Pbgra32, null, px, n * 4);
        bmp.Freeze();
        var brush = new ImageBrush(bmp)
        {
            TileMode = TileMode.Tile,
            Viewport = new Rect(0, 0, n, n),
            ViewportUnits = BrushMappingMode.Absolute,
            Stretch = Stretch.None,
        };
        RenderOptions.SetBitmapScalingMode(brush, BitmapScalingMode.NearestNeighbor);
        brush.Freeze();
        return brush;
    }
}
