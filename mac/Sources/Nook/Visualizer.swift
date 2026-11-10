import SwiftUI

/// Barras (Minimalist) ou ondas (Refined) no quadrado da capa, com o mesmo desenho da versão Windows.
///
/// No Mac, por enquanto, o movimento é gerado aqui (cinco faixas com ritmos diferentes) enquanto a música toca.
/// Reagir ao áudio de verdade exige captar o som do Spotify (Core Audio tap, macOS 14.2+), que pede uma
/// permissão extra de gravação de áudio; isso fica para a fase do visualizador com áudio.
struct VisualizerView: View {
    let waves: Bool
    let accent: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { gc, size in
                let levels = Self.levels(t)
                if waves { Self.drawWaves(gc, size, levels, t, accent) } else { Self.drawBars(gc, size, levels, accent) }
            }
        }
        .allowsHitTesting(false)
    }

    static let bandCount = 5

    /// Níveis de 0 a 1 por faixa: graves mais lentos e fortes, agudos mais rápidos e leves.
    static func levels(_ t: Double) -> [Double] {
        (0..<bandCount).map { i in
            let f = Double(i)
            let speed = 2.1 + f * 0.9
            let a = sin(t * speed + f * 1.7)
            let b = sin(t * speed * 1.93 + f * 0.6)
            let c = sin(t * (speed * 0.47) + f * 2.9)
            let v = 0.5 + 0.25 * a + 0.15 * b + 0.1 * c
            return min(max(v * (1.0 - f * 0.08), 0.08), 1)
        }
    }

    static func drawBars(_ gc: GraphicsContext, _ size: CGSize, _ levels: [Double], _ accent: Color) {
        let n = CGFloat(levels.count)
        let pad = size.width * 0.17, gap = size.width * 0.06
        let bw = (size.width - 2 * pad - gap * (n - 1)) / n
        for (i, l) in levels.enumerated() {
            let h = max(bw, CGFloat(l) * (size.height - 2 * pad))
            let r = CGRect(x: pad + CGFloat(i) * (bw + gap), y: (size.height - h) / 2, width: bw, height: h)
            gc.fill(Path(roundedRect: r, cornerRadius: bw / 2), with: .color(accent))
        }
    }

    static func drawWaves(_ gc: GraphicsContext, _ size: CGSize, _ levels: [Double], _ t: Double, _ accent: Color) {
        let low = (levels[0] + levels[1]) / 2, mid = levels[2], high = (levels[3] + levels[4]) / 2
        let amps = [high, mid, low]
        let freq = [2.6, 1.8, 1.1], speed = [4.2, 3.0, 2.1]
        let colors: [Color] = [.white.opacity(0.38), .white.opacity(0.69), accent]
        let widths: [CGFloat] = [1.2, 1.4, 1.8]
        let w = Double(size.width), cy = Double(size.height) / 2, maxA = Double(size.height) / 2 - 5
        let steps = 28
        for k in 0..<3 {
            let a = max(0.6, amps[k] * maxA)
            var p = Path()
            for s in 0...steps {
                let u = Double(s) / Double(steps)
                let env = sin(Double.pi * u) // afina nas pontas
                let pt = CGPoint(x: 4 + u * (w - 8),
                                 y: cy + sin(u * freq[k] * 2 * .pi + t * speed[k]) * a * env)
                if s == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            gc.stroke(p, with: .color(colors[k]), style: StrokeStyle(lineWidth: widths[k], lineCap: .round, lineJoin: .round))
        }
    }
}
