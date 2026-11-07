import SwiftUI
import AppKit

/// Estilos de vidro: "Frosted" (fosco, o original), "Frozen" (gelo: mais opaco, frio e granulado)
/// e "Liquid" (vidro vivo: borda de luz, brilho especular no topo, sombra interna e reflexo da capa).
/// Mesmas cores da versão Windows; o desfoque de trás vem do NSVisualEffectView do sistema.
enum Glass {
    static let frosted = "Frosted", frozen = "Frozen", liquid = "Liquid"

    static func style(_ s: Settings) -> String {
        s.GlassStyle == frozen || s.GlassStyle == liquid ? s.GlassStyle : frosted
    }

    static func argb(_ a: Int, _ r: Int, _ g: Int, _ b: Int) -> Color {
        Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    /// Cor de fundo do vidro: hover = nítido; repouso com ou sem blur.
    static func fill(_ s: Settings, hover: Bool) -> Color {
        switch (style(s), hover, s.Blur) {
        case (frozen, true, _): return argb(0xF2, 0x19, 0x20, 0x28)
        case (frozen, false, true): return argb(0x8C, 0x1B, 0x24, 0x2E)
        case (frozen, false, false): return argb(0xDC, 0x1B, 0x23, 0x2C)
        case (liquid, true, _): return argb(0xEB, 0x14, 0x15, 0x17)
        case (liquid, false, true): return argb(0x46, 0x12, 0x13, 0x16)
        case (liquid, false, false): return argb(0xC8, 0x14, 0x15, 0x17)
        case (_, true, _): return argb(0xF2, 0x16, 0x16, 0x16)
        case (_, false, true): return argb(0x50, 0x16, 0x16, 0x16)
        default: return argb(0xD0, 0x16, 0x16, 0x16)
        }
    }

    static let hairline = argb(0x26, 0xFF, 0xFF, 0xFF)
    static let fg = argb(0xF2, 0xFF, 0xFF, 0xFF)
    static let fgDim = argb(0x99, 0xFF, 0xFF, 0xFF)
    static let spotifyGreen = Color(.sRGB, red: 0x1E / 255.0, green: 0xD7 / 255.0, blue: 0x60 / 255.0, opacity: 1)

    /// Borda da janela. Liquid ganha a "borda de luz" em gradiente.
    static func rim(_ s: Settings) -> AnyShapeStyle {
        switch style(s) {
        case frozen: return AnyShapeStyle(argb(0x38, 0xD6, 0xEB, 0xFF))
        case liquid:
            return AnyShapeStyle(LinearGradient(stops: [
                .init(color: argb(0x99, 0xFF, 0xFF, 0xFF), location: 0),
                .init(color: argb(0x1A, 0xFF, 0xFF, 0xFF), location: 0.45),
                .init(color: argb(0x14, 0xFF, 0xFF, 0xFF), location: 0.6),
                .init(color: argb(0x59, 0xFF, 0xFF, 0xFF), location: 1),
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
        default: return AnyShapeStyle(hairline)
        }
    }

    /// Granulado fino de gelo: um ladrilho de ruído claro/escuro em baixa opacidade.
    static let noise: NSImage = {
        let n = 96
        var px = [UInt8](repeating: 0, count: n * n * 4)
        var seed: UInt64 = 7
        func next() -> UInt64 { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return seed >> 33 }
        for i in 0..<(n * n) {
            let a = UInt8(next() % 26)
            let c: UInt8 = next() % 2 == 0 ? 0 : a // premultiplicado: branco = a, preto = 0
            px[i * 4] = c; px[i * 4 + 1] = c; px[i * 4 + 2] = c; px[i * 4 + 3] = a
        }
        let provider = CGDataProvider(data: Data(px) as CFData)!
        let cg = CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4,
                         space: CGColorSpaceCreateDeviceRGB(),
                         bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                         provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return NSImage(cgImage: cg, size: NSSize(width: n, height: n))
    }()
}

/// Fundo completo do player: cor do vidro, camada do estilo (Frozen/Liquid) e borda.
struct GlassBackground: View {
    let settings: Settings
    let hover: Bool
    let tint: Color
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            shape.fill(Glass.fill(settings, hover: hover))
            overlay.clipShape(shape)
            shape.strokeBorder(Glass.rim(settings), lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.22), value: hover)
        .allowsHitTesting(false)
    }

    @ViewBuilder var overlay: some View {
        switch Glass.style(settings) {
        case Glass.frozen:
            ZStack {
                Image(nsImage: Glass.noise).resizable(resizingMode: .tile).interpolation(.none)
                LinearGradient(stops: [
                    .init(color: Glass.argb(0x1C, 0xE6, 0xF4, 0xFF), location: 0),
                    .init(color: Glass.argb(0x06, 0xE6, 0xF4, 0xFF), location: 0.55),
                    .init(color: Glass.argb(0x10, 0xE6, 0xF4, 0xFF), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
        case Glass.liquid:
            let lift: Double = hover ? 1 : 0
            GeometryReader { geo in
                ZStack {
                    // Reflexo colorido da capa, vindo da esquerda (onde ela fica).
                    EllipticalGradient(colors: [tint.opacity((0x38 + 0x18 * lift) / 255), tint.opacity(0)],
                                       center: UnitPoint(x: 0.08, y: 0.6), startRadiusFraction: 0, endRadiusFraction: 0.55)
                        .frame(width: geo.size.width, height: geo.size.height)
                    // Brilho especular no topo, mais forte no hover.
                    LinearGradient(stops: [
                        .init(color: Color.white.opacity((0x2E + 0x16 * lift) / 255), location: 0),
                        .init(color: Color.white.opacity((0x0E + 0x06 * lift) / 255), location: 0.42),
                        .init(color: Color.white.opacity(0), location: 0.5),
                    ], startPoint: .top, endPoint: .bottom)
                    // Sombra interna embaixo: dá volume e ajuda a leitura sobre fundo claro.
                    LinearGradient(stops: [
                        .init(color: Color.black.opacity(0), location: 0.55),
                        .init(color: Color.black.opacity(0x38 / 255.0), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                    // Linha de luz logo abaixo da borda superior (o "fio" de vidro).
                    RoundedRectangle(cornerRadius: max(0, radius - 1.5), style: .continuous)
                        .strokeBorder(LinearGradient(stops: [
                            .init(color: Glass.argb(0x50, 0xFF, 0xFF, 0xFF), location: 0),
                            .init(color: Color.white.opacity(0), location: 0.35),
                            .init(color: Color.white.opacity(0), location: 0.8),
                            .init(color: Glass.argb(0x1C, 0xFF, 0xFF, 0xFF), location: 1),
                        ], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                        .padding(1)
                }
            }
        default:
            EmptyView()
        }
    }
}
