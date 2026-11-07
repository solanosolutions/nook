import SwiftUI
import AppKit

/// Menu de configurações: painel de vidro aberto ao lado do player.
struct SettingsView: View {
    @ObservedObject var model: AppModel
    let close: () -> Void

    private var s: Settings { model.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Nook").font(.system(size: 13, weight: .semibold)).foregroundColor(Glass.fg)
                Spacer()
                IconButton(symbol: "xmark", size: 10, box: 22, tip: "Close", action: close)
            }
            .padding(.bottom, 6)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    section("SecElements")
                    toggle("Cover", \.ShowCover)
                    toggle("Title", \.ShowTitle)
                    toggle("Shuffle", \.ShowShuffle)
                    toggle("Previous", \.ShowPrev)
                    toggle("Play", \.ShowPlay)
                    toggle("Next", \.ShowNext)
                    toggle("Repeat", \.ShowRepeat)
                    toggle("Progress", \.ShowProgress)
                    toggle("OpenSpotify", \.ShowOpen)
                    toggle("Gear", \.ShowGear)
                    toggle("HideBtnEl", \.ShowHideBtn)

                    section("SecLook")
                    label("GlassStyle")
                    Picker("", selection: model.binding(\.GlassStyle)) {
                        Text(Strings.get("Frosted")).tag(Glass.frosted)
                        Text(Strings.get("Frozen")).tag(Glass.frozen)
                        Text(Strings.get("Liquid")).tag(Glass.liquid)
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    .padding(.bottom, 4)
                    slider("Size", \.Scale, 0.8...1.6)
                    slider("IdleOpacity", \.IdleOpacity, 0.2...1)
                    toggle("Blur", \.Blur)
                    toggle("CoverAccent", \.CoverAccent)

                    section("SecBehavior")
                    toggle("Topmost", \.Topmost)
                    toggle("HideIdle", \.HideWhenIdle)
                    HStack {
                        label("AutoHide")
                        Spacer()
                        Picker("", selection: model.binding(\.AutoHideMinutes)) {
                            Text(Strings.get("Never")).tag(0)
                            ForEach([1, 5, 15, 30], id: \.self) { Text("\($0) min").tag($0) }
                        }
                        .labelsHidden().frame(width: 90)
                    }
                    toggle("Lock", \.LockPosition)
                    toggle("Wheel", \.WheelVolume)
                    toggle("TrayIcon", \.TrayIcon)
                    toggle("Startup", \.StartAtLogin)
                    HStack {
                        label("Language")
                        Spacer()
                        Picker("", selection: model.binding(\.Language)) {
                            Text("Auto").tag("auto")
                            Text("English").tag("en")
                            Text("Português").tag("pt")
                        }
                        .labelsHidden().frame(width: 110)
                    }
                }
            }
            .frame(maxHeight: 440)

            Divider().overlay(Glass.hairline).padding(.vertical, 8)
            HStack(spacing: 4) {
                IconButton(symbol: "chevron.left.forwardslash.chevron.right", size: 10, box: 24, tip: "GitHubTip") {
                    NSWorkspace.shared.open(AppModel.gitHubURL)
                }
                IconButton(symbol: "camera", size: 10, box: 24, tip: "InstagramTip") {
                    NSWorkspace.shared.open(AppModel.instagramURL)
                }
                Text("v\(AppModel.version)").font(.system(size: 10, design: .monospaced)).foregroundColor(Glass.fgDim)
                Spacer()
                Button(Strings.get("QuitNook")) { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(Glass.fgDim)
            }
        }
        .padding(12)
        .frame(width: 270)
        .background(GlassBackground(settings: s, hover: true, tint: model.accent, radius: 12))
        .tint(model.accent)
        .environment(\.colorScheme, .dark)
    }

    private func section(_ key: String) -> some View {
        Text(Strings.get(key))
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(Glass.fgDim)
            .padding(.top, 10).padding(.bottom, 2)
    }

    private func label(_ key: String) -> some View {
        Text(Strings.get(key)).font(.system(size: 12)).foregroundColor(Glass.fg)
    }

    private func toggle(_ key: String, _ path: ReferenceWritableKeyPath<Settings, Bool>) -> some View {
        Toggle(isOn: model.binding(path)) { label(key) }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func slider(_ key: String, _ path: ReferenceWritableKeyPath<Settings, Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            label(key)
            Slider(value: model.binding(path), in: range).controlSize(.mini)
        }
        .padding(.vertical, 2)
    }
}

/// Janela do menu: vidro, sem borda, aberta perto do player.
final class SettingsPanel: NSPanel {
    init(model: AppModel, close: @escaping () -> Void) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 270, height: 500),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let root = NSView()
        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.maskImage = NSImage(size: NSSize(width: 25, height: 25), flipped: false) { r in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: r, xRadius: 12, yRadius: 12).fill()
            return true
        }
        blur.maskImage?.capInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        blur.autoresizingMask = [.width, .height]
        root.addSubview(blur)

        let hosting = FirstMouseHostingView(rootView: SettingsView(model: model, close: close))
        hosting.autoresizingMask = [.width, .height]
        root.addSubview(hosting)
        contentView = root

        let size = hosting.fittingSize
        setContentSize(size)
        blur.frame = root.bounds
        hosting.frame = root.bounds
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
