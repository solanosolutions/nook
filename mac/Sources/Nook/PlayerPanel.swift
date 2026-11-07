import AppKit
import SwiftUI

/// Hosting que aceita o primeiro clique (a janela nunca vira "ativa", então sem isso o 1º clique se perderia).
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Janela do player: sem borda, flutuante, fora do Dock e do Cmd+Tab, em todas as mesas (Spaces),
/// com o desfoque do sistema atrás e cantos arredondados.
final class PlayerPanel: NSPanel {
    let model: AppModel
    private let blur = NSVisualEffectView()
    private var hosting: FirstMouseHostingView<PlayerView>!
    private var snapWork: DispatchWorkItem?
    private var scrollAccum: CGFloat = 0
    private var monitors: [Any] = []
    private var placed = false
    static let radius: CGFloat = 12

    init(model: AppModel) {
        self.model = model
        super.init(contentRect: NSRect(x: 0, y: 0, width: 360, height: 60),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        animationBehavior = .utilityWindow

        let root = TrackingView()
        root.onHover = { [weak self] in self?.setHover($0) }
        root.wantsLayer = true
        contentView = root

        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active // sempre ativo: a janela nunca é a principal
        blur.maskImage = Self.mask(radius: Self.radius)
        blur.autoresizingMask = [.width, .height]
        blur.frame = root.bounds
        root.addSubview(blur)

        hosting = FirstMouseHostingView(rootView: PlayerView(model: model))
        hosting.sizingOptions = [] // o tamanho da janela é controlado aqui (ver fitToContent)
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = root.bounds
        root.addSubview(hosting)

        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: self, queue: .main) { [weak self] _ in
            self?.scheduleSnap()
        }
        installMonitors()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // ---------- Aparência ----------

    func applySettings() {
        let s = model.settings
        level = s.Topmost ? .floating : .normal
        blur.isHidden = !s.Blur
        applyAlpha(animated: false)
        fitToContent()
    }

    private func setHover(_ hover: Bool) {
        guard model.hover != hover else { return }
        model.hover = hover
        applyAlpha(animated: true)
    }

    func applyAlpha(animated: Bool) {
        let target = model.hover || model.settingsOpen ? 1.0 : CGFloat(model.settings.IdleOpacity)
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                animator().alphaValue = target
            }
        } else {
            alphaValue = target
        }
    }

    /// Ajusta a janela ao conteúdo, mantendo fixo o canto mais perto da borda da tela,
    /// para o player crescer "para dentro" em vez de pular de lugar.
    func fitToContent() {
        let size = hosting.fittingSize
        guard size.width > 1, size.height > 1 else { return }
        var f = frame
        if f.size == size { return }
        if placed, let wa = (screen ?? NSScreen.main)?.visibleFrame {
            if f.midX > wa.midX { f.origin.x = f.maxX - size.width }
            if f.midY >= wa.midY { f.origin.y = f.maxY - size.height } // metade de cima: segura o topo
        }
        f.size = size
        setFrame(f, display: true)
        invalidateShadow()
    }

    private static func mask(radius: CGFloat) -> NSImage {
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

    // ---------- Posição: começa no canto inferior direito, ímã nas bordas, salva onde ficou ----------

    func placeInitially() {
        fitToContent()
        let s = model.settings
        let screens = NSScreen.screens.map(\.visibleFrame)
        if let x = s.Left, let top = s.Top {
            let p = NSPoint(x: x, y: top - frame.height)
            if screens.contains(where: { $0.insetBy(dx: -4, dy: -4).contains(NSRect(origin: p, size: frame.size)) }) {
                setFrameOrigin(p)
                placed = true
                return
            }
        }
        if let wa = NSScreen.main?.visibleFrame {
            setFrameOrigin(NSPoint(x: wa.maxX - frame.width - 16, y: wa.minY + 16))
        }
        placed = true
    }

    /// Ao terminar de arrastar: encosta na borda se ficou perto dela e guarda a posição.
    private func scheduleSnap() {
        snapWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if NSEvent.pressedMouseButtons != 0 { self.scheduleSnap(); return } // ainda arrastando
            self.snapToEdges()
            self.model.settings.Left = self.frame.minX
            self.model.settings.Top = self.frame.maxY
            self.model.settings.save()
        }
        snapWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: w)
    }

    private func snapToEdges() {
        guard let wa = (screen ?? NSScreen.main)?.visibleFrame else { return }
        let magnet: CGFloat = 20, gap: CGFloat = 10
        var o = frame.origin
        if abs(o.x - wa.minX) < magnet { o.x = wa.minX + gap }
        if abs(wa.maxX - frame.maxX) < magnet { o.x = wa.maxX - frame.width - gap }
        if abs(o.y - wa.minY) < magnet { o.y = wa.minY + gap }
        if abs(wa.maxY - frame.maxY) < magnet { o.y = wa.maxY - frame.height - gap }
        if o != frame.origin { setFrameOrigin(o) }
    }

    // ---------- Rolagem = volume do Spotify ----------

    private func installMonitors() {
        let m = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] e in
            guard let self, e.window === self else { return e }
            self.handleScroll(e)
            return nil
        }
        if let m { monitors.append(m) }
    }

    private func handleScroll(_ e: NSEvent) {
        // Trackpad manda muitos eventos pequenos: acumula até dar um "degrau".
        let dy = e.hasPreciseScrollingDeltas ? e.scrollingDeltaY / 12 : e.scrollingDeltaY
        scrollAccum += e.isDirectionInvertedFromDevice ? -dy : dy
        while abs(scrollAccum) >= 1 {
            let up = scrollAccum > 0
            scrollAccum += up ? -1 : 1
            model.wheel(up: up)
        }
        if e.phase == .ended || e.momentumPhase == .ended { scrollAccum = 0 }
    }
}

/// Avisa quando o mouse entra/sai da janela, mesmo com o app inativo.
final class TrackingView: NSView {
    var onHover: ((Bool) -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
}
