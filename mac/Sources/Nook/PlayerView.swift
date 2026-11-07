import SwiftUI
import AppKit

/// O player: capa, título/artista, controles e barra de progresso, no mesmo arranjo da versão Windows.
struct PlayerView: View {
    @ObservedObject var model: AppModel
    /// Largura medida da linha de cima; a barra de progresso acompanha.
    @State private var rowWidth: CGFloat = 0

    private var s: Settings { model.settings }
    private var sp: SpotifyService { model.spotify }
    private var k: CGFloat { CGFloat(min(max(s.Scale, 0.7), 2)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4 * k) {
            row
                .background(GeometryReader { g in
                    Color.clear.preference(key: WidthKey.self, value: g.size.width)
                })
            if s.ShowProgress {
                ProgressBar(model: model, height: 9 * k)
                    .frame(width: rowWidth)
            }
        }
        .onPreferenceChange(WidthKey.self) { rowWidth = $0 }
        .padding(EdgeInsets(top: 7 * k, leading: 8 * k, bottom: 5 * k, trailing: 8 * k))
        .background(
            ZStack {
                // Clique duplo abre o menu, arrastar move, botão direito abre o menu.
                DragArea(model: model)
                GlassBackground(settings: s, hover: model.hover || model.settingsOpen, tint: model.accent, radius: 12)
            }
        )
        .fixedSize()
        .animation(.easeInOut(duration: 0.5), value: model.spotify.coverColor)
        .environment(\.colorScheme, .dark)
    }

    private var title: String {
        if sp.notAuthorized { return Strings.get("AllowAutomation") }
        return sp.hasTrack && !sp.title.isEmpty ? sp.title : Strings.get("NothingPlaying")
    }

    private var subtitle: String {
        if let f = model.flash { return f }
        if sp.notAuthorized { return Strings.get("AllowAutomationHint") }
        if sp.hasTrack { return sp.artist }
        return sp.isRunning ? "" : Strings.get("ClickToOpen")
    }

    private var showDivider: Bool { s.ShowOpen || s.ShowGear || s.ShowHideBtn }

    private var row: some View {
        HStack(spacing: 0) {
            if s.ShowCover {
                CoverView(image: sp.cover, size: 36 * k, radius: 7 * k)
                    .padding(.trailing, 10 * k)
            }
            if s.ShowTitle {
                VStack(alignment: .leading, spacing: 1 * k) {
                    Text(title)
                        .font(.system(size: 12.5 * k, weight: .semibold))
                        .foregroundColor(Glass.fg)
                    Text(subtitle)
                        .font(.system(size: 11 * k))
                        .foregroundColor(Glass.fgDim)
                }
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 170 * k, alignment: .leading)
                .padding(.trailing, 8 * k)
                .contentShape(Rectangle())
                .onTapGesture { NookApp.openAutomationSettings() }
                // Só recebe clique quando falta a permissão; no resto, o texto deixa arrastar o player.
                .allowsHitTesting(sp.notAuthorized)
            }
            if s.ShowShuffle {
                IconButton(symbol: "shuffle", size: 12 * k, box: 28 * k,
                           color: sp.shuffle ? model.accent : Glass.fgDim, tip: "Shuffle") { sp.toggleShuffle() }
            }
            if s.ShowPrev {
                IconButton(symbol: "backward.fill", size: 12 * k, box: 28 * k, enabled: sp.hasTrack || !sp.isRunning,
                           tip: "Previous") { sp.previous() }
            }
            if s.ShowPlay {
                PlayButton(playing: sp.isPlaying, k: k) {
                    if sp.isRunning { sp.playPause() } else { SpotifyService.open() }
                }
                .padding(.horizontal, 3 * k)
            }
            if s.ShowNext {
                IconButton(symbol: "forward.fill", size: 12 * k, box: 28 * k, enabled: sp.hasTrack || !sp.isRunning,
                           tip: "Next") { sp.next() }
            }
            if s.ShowRepeat {
                IconButton(symbol: "repeat", size: 12 * k, box: 28 * k,
                           color: sp.repeating ? model.accent : Glass.fgDim, tip: "Repeat") { sp.toggleRepeat() }
            }
            if showDivider {
                Rectangle().fill(Glass.hairline)
                    .frame(width: 1, height: 18 * k)
                    .padding(.leading, 6 * k).padding(.trailing, 4 * k)
            }
            if s.ShowOpen {
                IconButton(symbol: "arrow.up.forward.app", size: 11 * k, box: 28 * k, tip: "OpenSpotify") { SpotifyService.open() }
            }
            if s.ShowGear {
                IconButton(symbol: "gearshape", size: 11 * k, box: 28 * k, tip: "SettingsTip") { model.onOpenSettings?() }
            }
            if s.ShowHideBtn {
                IconButton(symbol: "eye.slash", size: 10 * k, box: 28 * k, tip: "HideTip") { model.onHide?() }
            }
        }
    }
}

private struct WidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct CoverView: View {
    let image: NSImage?
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Glass.argb(0x1F, 0xFF, 0xFF, 0xFF))
            if let image {
                Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note").font(.system(size: size * 0.4)).foregroundColor(Glass.fgDim)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .allowsHitTesting(false)
    }
}

/// Botão de ícone redondo, sem foco de teclado, com realce no hover.
struct IconButton: View {
    let symbol: String
    let size: CGFloat
    let box: CGFloat
    var enabled = true
    var color: Color = Glass.fg
    let tip: String
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(color)
                .frame(width: box, height: box)
                .background(Circle().fill(Color.white.opacity(over ? 0.12 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .onHover { over = $0 }
        .help(Strings.get(tip))
    }
}

struct PlayButton: View {
    let playing: Bool
    let k: CGFloat
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            Image(systemName: playing ? "pause.fill" : "play.fill")
                .font(.system(size: 13 * k, weight: .bold))
                .foregroundColor(Color(white: 0.07))
                .offset(x: playing ? 0 : 1 * k)
                .frame(width: 32 * k, height: 32 * k)
                .background(Circle().fill(Glass.fg))
                .contentShape(Circle())
                .scaleEffect(over ? 1.07 : 1)
                .animation(.easeOut(duration: 0.12), value: over)
        }
        .buttonStyle(PressStyle())
        .onHover { over = $0 }
        .help(Strings.get("PlayPause"))
    }
}

private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

/// Barra de progresso fina; clique pula para o ponto.
struct ProgressBar: View {
    @ObservedObject var model: AppModel
    let height: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let sp = model.spotify
            let f = sp.duration > 0 ? min(max(sp.position / sp.duration, 0), 1) : 0
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15)).frame(height: 3)
                    Capsule().fill(model.accent).frame(width: g.size.width * f, height: 3)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { p in
                    sp.seek(fraction: g.size.width > 0 ? p.x / g.size.width : 0)
                }
            }
            .help(sp.duration > 0 ? "\(Self.fmt(sp.position)) / \(Self.fmt(sp.duration))" : "")
        }
        .frame(height: height)
    }

    static func fmt(_ t: Double) -> String {
        let s = Int(t)
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
                         : String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Área de fundo que arrasta a janela, abre o menu no duplo clique e no botão direito.
struct DragArea: NSViewRepresentable {
    let model: AppModel

    func makeNSView(context: Context) -> DragNSView {
        let v = DragNSView()
        v.model = model
        return v
    }

    func updateNSView(_ nsView: DragNSView, context: Context) { nsView.model = model }
}

final class DragNSView: NSView {
    weak var model: AppModel?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false } // o arraste é feito aqui, para o duplo clique funcionar

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 { model?.onOpenSettings?(); return }
        guard let model, !model.settings.LockPosition, let w = window else { return }
        w.performDrag(with: event) // ímã e posição salva: PlayerPanel, ao terminar de mover
    }

    override func rightMouseUp(with event: NSEvent) { model?.onOpenSettings?() }
}
