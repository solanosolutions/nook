import AppKit

/// Extrai a cor marcante da capa (mesmo algoritmo da versão Windows).
enum CoverColor {
    /// Agrupa os pixels por matiz (36 faixas de 10°), pesando por saturação×brilho,
    /// e devolve a média da faixa dominante com saturação/brilho reforçados.
    static func vivid(_ image: NSImage) -> NSColor? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let side = 48
        var px = [UInt8](repeating: 0, count: side * side * 4)
        let drawn: Bool = px.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .low
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }

        var weight = [Double](repeating: 0, count: 36)
        var r = weight, g = weight, b = weight
        var samples = 0
        for i in stride(from: 0, to: px.count, by: 4) {
            samples += 1
            let pr = Double(px[i]), pg = Double(px[i + 1]), pb = Double(px[i + 2])
            let (hue, sat, val) = toHSV(pr, pg, pb)
            if sat < 0.25 || val < 0.2 { continue } // ignora cinzas e pretos
            let k = Int(hue / 10) % 36
            let w = sat * val
            weight[k] += w; r[k] += pr * w; g[k] += pg * w; b[k] += pb * w
        }

        var best = -1
        var bestW = 0.0
        for k in 0..<36 {
            let around = weight[(k + 35) % 36] + weight[k] + weight[(k + 1) % 36]
            if around > bestW && weight[k] > 0 { bestW = around; best = k }
        }
        if best < 0 || bestW < Double(samples) * 0.03 { return nil } // capa praticamente sem cor

        let (h, s, v) = toHSV(r[best] / weight[best], g[best] / weight[best], b[best] / weight[best])
        return NSColor(hue: h / 360, saturation: max(s, 0.55), brightness: max(v, 0.85), alpha: 1)
    }

    static func toHSV(_ r0: Double, _ g0: Double, _ b0: Double) -> (Double, Double, Double) {
        let r = r0 / 255, g = g0 / 255, b = b0 / 255
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        let v = mx
        let s = mx == 0 ? 0 : d / mx
        var h = 0.0
        if d != 0 {
            if mx == r { h = 60 * ((g - b) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == g { h = 60 * ((b - r) / d + 2) }
            else { h = 60 * ((r - g) / d + 4) }
            if h < 0 { h += 360 }
        }
        return (h, s, v)
    }
}
