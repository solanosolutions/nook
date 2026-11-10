import SwiftUI
import AppKit

/// Os três estilos fixos do Nook (iguais aos da versão Windows):
/// - Minimalist: vidro fosco + barras no quadrado da capa enquanto toca.
/// - Old School: vidro gelo (Frozen), só a capa, sem barras nem ondas.
/// - Refined: vidro líquido (Liquid) + ondas no quadrado da capa.
///
/// No macOS 26+ o vidro de trás é o Liquid Glass do sistema (NSGlassEffectView); antes disso,
/// o desfoque do NSVisualEffectView. Por cima, as camadas de cada estilo, com as cores da versão Windows.
enum Glass {
    static let minimalist = "Minimalist", oldSchool = "OldSchool", refined = "Refined"
    static let styles = [minimalist, oldSchool, refined]
    /// Nomes iguais nos dois idiomas.
    static let styleNames = [minimalist: "Minimalist", oldSchool: "Old School", refined: "Refined"]

    static let frosted = "Frosted", frozen = "Frozen", liquid = "Liquid"

    /// Vidro de cada estilo.
    static func style(_ s: Settings) -> String {
        switch s.Style {
        case oldSchool: return frozen
        case refined: return liquid
        default: return frosted
        }
    }

    /// O que aparece no quadrado da capa enquanto toca.
    enum Visual { case cover, bars, waves }
    static func visual(_ s: Settings) -> Visual {
        switch s.Style {
        case oldSchool: return .cover
        case refined: return .waves
        default: return .bars
        }
    }

    /// Liquid Glass nativo disponível (compilado com o SDK do macOS 26 e rodando no 26+).
    static var native: Bool {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) { return true }
        #endif
        return false
    }

    static func argb(_ a: Int, _ r: Int, _ g: Int, _ b: Int) -> Color {
        Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    /// Cor de fundo por cima do desfoque: hover = mais sólido; repouso = translúcido.
    /// Com o Liquid Glass nativo o próprio sistema já escurece e refrata, então a camada é mais leve.
    static func fill(_ s: Settings, hover: Bool) -> Color {
        if native {
            switch (style(s), hover) {
            case (frozen, true): return argb(0xB0, 0x19, 0x20, 0x28)
            case (frozen, false): return argb(0x60, 0x1B, 0x24, 0x2E)
            case (liquid, true): return argb(0x70, 0x10, 0x11, 0x14)
            case (liquid, false): return argb(0x20, 0x10, 0x11, 0x14)
            case (_, true): return argb(0xA8, 0x16, 0x16, 0x16)
            default: return argb(0x48, 0x16, 0x16, 0x16)
            }
        }
        switch (style(s), hover) {
        case (frozen, true): return argb(0xF2, 0x19, 0x20, 0x28)
        case (frozen, false): return argb(0x8C, 0x1B, 0x24, 0x2E)
        case (liquid, true): return argb(0xEB, 0x14, 0x15, 0x17)
        case (liquid, false): return argb(0x46, 0x12, 0x13, 0x16)
        case (_, true): return argb(0xF2, 0x16, 0x16, 0x16)
        default: return argb(0x50, 0x16, 0x16, 0x16)
        }
    }

    static let hairline = argb(0x26, 0xFF, 0xFF, 0xFF)
    static let fg = argb(0xF2, 0xFF, 0xFF, 0xFF)
    static let fgDim = argb(0x99, 0xFF, 0xFF, 0xFF)
    static let spotifyGreen = Color(.sRGB, red: 0x1E / 255.0, green: 0xD7 / 255.0, blue: 0x60 / 255.0, opacity: 1)

    /// Borda da janela. Liquid ganha a "borda de luz" em gradiente.
    static func rim(_ s: Settings) -> AnyShapeStyle {
        if native && style(s) != frozen { return AnyShapeStyle(Color.clear) } // a borda de luz vem do sistema
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
                    // No Liquid Glass nativo o brilho, a sombra e a borda de luz já vêm do sistema.
                    if !Glass.native { liquidHighlights(lift) }
                }
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder private func liquidHighlights(_ lift: Double) -> some View {
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

/// Fundo do sistema atrás do conteúdo de uma janela: Liquid Glass nativo no macOS 26+
/// (NSGlassEffectView, com refração e borda de luz do próprio sistema); no 13–15, o desfoque do NSVisualEffectView.
final class Backdrop {
    let view: NSView
    private var blur: NSVisualEffectView?

    init(content: NSView, radius: CGFloat) {
        content.autoresizingMask = [.width, .height]
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            let g = NSGlassEffectView()
            g.cornerRadius = radius
            g.contentView = content
            view = g
            return
        }
        #endif
        let box = NSView()
        let b = NSVisualEffectView()
        b.material = .hudWindow
        b.blendingMode = .behindWindow
        b.state = .active // sempre ativo: as janelas do Nook nunca são a principal
        b.maskImage = Backdrop.mask(radius: radius)
        b.autoresizingMask = [.width, .height]
        box.addSubview(b)
        box.addSubview(content)
        blur = b
        view = box
    }

    /// Põe o fundo (e o conteúdo) no tamanho da janela; depois acompanha sozinho.
    func setFrame(_ r: NSRect) {
        view.frame = r
        view.autoresizingMask = [.width, .height]
        if blur != nil { view.subviews.forEach { $0.frame = view.bounds } }
    }

    /// Ajusta o vidro ao estilo: Refined usa o vidro "clear" (mais transparente, o líquido de verdade);
    /// os outros, o "regular", escurecido para o texto branco ficar legível sobre qualquer fundo.
    func apply(_ s: Settings) {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *), let g = view as? NSGlassEffectView {
            switch Glass.style(s) {
            case Glass.liquid:
                g.style = .clear
                g.tintColor = NSColor(white: 0.05, alpha: 0.28)
            case Glass.frozen:
                g.style = .regular
                g.tintColor = NSColor(srgbRed: 0.10, green: 0.14, blue: 0.19, alpha: 0.55)
            default:
                g.style = .regular
                g.tintColor = NSColor(white: 0.07, alpha: 0.5)
            }
        }
        #endif
    }

    static func mask(radius: CGFloat) -> NSImage {
        let d = radius * 2 + 1
        let img = NSImage(size: NSSize(width: d, height: d), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        img.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        img.resizingMode = .stretch
        return img
    }
}
