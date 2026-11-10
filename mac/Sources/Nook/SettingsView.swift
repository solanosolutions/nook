import SwiftUI
import AppKit

/// Menu de configurações, organizado como o da versão Windows: seções que abrem e fecham,
/// elementos em duas colunas, controles segmentados e botões em pílula no rodapé.
/// O que virou padrão fixo (sempre no topo, idioma, rolagem = volume, opacidade em repouso, vidro, blur)
/// não aparece mais aqui.
struct SettingsView: View {
    @ObservedObject var model: AppModel
    let close: () -> Void

    private var s: Settings { model.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon).resizable().interpolation(.high).frame(width: 18, height: 18)
                }
                Text("Nook").font(.system(size: 13, weight: .semibold)).foregroundColor(Glass.fg)
                Spacer()
                IconButton(symbol: "xmark", size: 10, box: 24, tip: "Close", action: close)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    section("Elements", "SecElements") {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())],
                                  alignment: .leading, spacing: 6) {
                            toggle("Cover", \.ShowCover)
                            toggle("Title", \.ShowTitle)
                            toggle("Shuffle", \.ShowShuffle)
                            toggle("Repeat", \.ShowRepeat)
                            toggle("Previous", \.ShowPrev)
                            toggle("Next", \.ShowNext)
                            toggle("Play", \.ShowPlay)
                            toggle("Progress", \.ShowProgress)
                            toggle("OpenSpotify", \.ShowOpen)
                            toggle("Gear", \.ShowGear)
                            toggle("HideBtnEl", \.ShowHideBtn)
                        }
                    }

                    section("Look", "SecLook") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                label("Style")
                                Segmented(options: Glass.styles.map { ($0, Glass.styleNames[$0] ?? $0) },
                                          selection: model.binding(\.Style), accent: model.accent)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    label("Size")
                                    Spacer()
                                    Text("\(Int((s.Scale * 100).rounded()))%")
                                        .font(.system(size: 12)).foregroundColor(Glass.fgDim)
                                }
                                Slider(value: model.binding(\.Scale), in: 0.8...1.6, step: 0.05).controlSize(.mini)
                            }
                            toggle("CoverAccent", \.CoverAccent)
                        }
                    }

                    section("Behavior", "SecBehavior") {
                        VStack(alignment: .leading, spacing: 6) {
                            toggle("HideIdle", \.HideWhenIdle)
                            toggle("Lock", \.LockPosition)
                            toggle("TrayIcon", \.TrayIcon)
                            toggle("Startup", \.StartAtLogin)
                            label("AutoHide").padding(.top, 6)
                            Segmented(options: [(0, Strings.get("Never")), (1, "1 min"), (5, "5 min"), (15, "15 min")],
                                      selection: model.binding(\.AutoHideMinutes), accent: model.accent)
                        }
                    }
                }
            }
            .frame(maxHeight: 420)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Pill(text: Strings.get("OpenSpotify"), filled: true, accent: model.accent) { SpotifyService.open() }
                Spacer()
                Pill(text: Strings.get("QuitNook"), filled: false, accent: model.accent) { NSApp.terminate(nil) }
            }
            .padding(.top, 14)

            Rectangle().fill(Glass.hairline).frame(height: 1).padding(.top, 12)
            HStack(spacing: 2) {
                IconButton(symbol: "chevron.left.forwardslash.chevron.right", size: 10, box: 26, color: Glass.fgDim,
                           tip: "GitHubTip") { NSWorkspace.shared.open(AppModel.gitHubURL) }
                IconButton(symbol: "camera", size: 10, box: 26, color: Glass.fgDim, tip: "InstagramTip") {
                    NSWorkspace.shared.open(AppModel.instagramURL)
                }
                Spacer()
                Text("v\(AppModel.version)").font(.system(size: 11)).foregroundColor(Glass.fgDim)
            }
            .padding(.top, 6)
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        .frame(width: 290)
        .background(GlassBackground(settings: s, hover: true, tint: model.accent, radius: 12))
        .tint(model.accent)
        .environment(\.colorScheme, .dark)
    }

    // ---------- Peças ----------

    /// Cabeçalho que abre/fecha a seção; o que fica aberto é lembrado (como no Windows).
    @ViewBuilder
    private func section<C: View>(_ id: String, _ key: String, @ViewBuilder content: () -> C) -> some View {
        let open = s.OpenSections.contains(id)
        Button {
            if open { s.OpenSections.removeAll { $0 == id } } else { s.OpenSections.append(id) }
            model.changed()
        } label: {
            HStack {
                Text(Strings.get(key))
                    .font(.system(size: 10, weight: .semibold)).tracking(0.8)
                    .foregroundColor(Glass.fgDim)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Glass.fgDim)
                    .rotationEffect(.degrees(open ? 0 : -90))
            }
            .padding(.top, 14).padding(.bottom, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        if open { content() }
    }

    private func label(_ key: String) -> some View {
        Text(Strings.get(key)).font(.system(size: 12)).foregroundColor(Glass.fg).lineLimit(1)
    }

    /// Nome à esquerda e chave à direita, alinhados na coluna (no beta a chave colava no texto).
    private func toggle(_ key: String, _ path: ReferenceWritableKeyPath<Settings, Bool>) -> some View {
        HStack(spacing: 6) {
            label(key).minimumScaleFactor(0.85)
            Spacer(minLength: 4)
            Toggle("", isOn: model.binding(path)).labelsHidden().toggleStyle(.switch).controlSize(.mini)
        }
    }
}

/// Controle segmentado no visual do Nook (o mesmo do menu do Windows): trilho claro e o escolhido em destaque.
struct Segmented<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    let accent: Color

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { i in
                let value = options[i].0, text = options[i].1
                let on = value == selection
                Button { selection = value } label: {
                    Text(text)
                        .font(.system(size: 11, weight: on ? .semibold : .regular))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .foregroundColor(on ? Glass.fg : Glass.fgDim)
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(on ? Color.white.opacity(0.16) : Color.clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.08)))
        .animation(.easeOut(duration: 0.15), value: selection)
    }
}

/// Botão em pílula do rodapé.
struct Pill: View {
    let text: String
    let filled: Bool
    let accent: Color
    let action: () -> Void
    @State private var over = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12, weight: filled ? .semibold : .regular))
                .foregroundColor(filled ? Color(white: 0.07) : Glass.fg)
                .padding(.horizontal, 14).frame(height: 28)
                .background(Capsule().fill(filled ? accent : Color.white.opacity(over ? 0.16 : 0.1)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { over = $0 }
    }
}

/// Janela do menu: vidro, sem borda, aberta perto do player.
final class SettingsPanel: NSPanel {
    private let model: AppModel
    private var backdrop: Backdrop!
    private var hosting: FirstMouseHostingView<SettingsView>!

    init(model: AppModel, close: @escaping () -> Void) {
        self.model = model
        super.init(contentRect: NSRect(x: 0, y: 0, width: 270, height: 500),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let root = NSView()
        contentView = root
        hosting = FirstMouseHostingView(rootView: SettingsView(model: model, close: close))
        hosting.sizingOptions = [] // o tamanho é controlado aqui (ver refit)
        backdrop = Backdrop(content: hosting, radius: 12)
        backdrop.apply(model.settings)
        root.addSubview(backdrop.view)

        setContentSize(hosting.fittingSize)
        backdrop.setFrame(root.bounds)
    }

    /// Depois de uma mudança: vidro do estilo novo e altura nova (seção aberta/fechada), mantendo o topo no lugar.
    func refit() {
        backdrop.apply(model.settings)
        let size = hosting.fittingSize
        guard size.height > 1, size != frame.size else { return }
        var f = frame
        f.origin.y = f.maxY - size.height
        f.size = size
        if let wa = screen?.visibleFrame, f.minY < wa.minY + 8 { f.origin.y = wa.minY + 8 }
        setFrame(f, display: true)
        invalidateShadow()
    }

    override var canBecomeKey: Bool { true } // pickers e sliders funcionam melhor com foco

    /// Abre ao lado do player, do lado em que houver espaço.
    func show(near player: NSWindow) {
        guard let wa = (player.screen ?? NSScreen.main)?.visibleFrame else { return }
        let p = player.frame, gap: CGFloat = 8
        var x = p.maxX + gap
        if x + frame.width > wa.maxX { x = p.minX - frame.width - gap }
        if x < wa.minX { x = max(wa.minX + gap, p.midX - frame.width / 2) }
        var y = p.maxY - frame.height
        y = min(max(y, wa.minY + gap), wa.maxY - frame.height - gap)
        setFrameOrigin(NSPoint(x: x, y: y))
        orderFrontRegardless()
        makeKey()
    }
}
