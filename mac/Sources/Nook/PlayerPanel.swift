import AppKit
import SwiftUI

/// Hosting que aceita o primeiro clique (a janela nunca vira "ativa", então sem isso o 1º clique se perderia).
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Janela do player: sem borda, sempre no topo, fora do Dock e do Cmd+Tab, em todas as mesas (Spaces),
/// com o vidro do sistema atrás (Liquid Glass no macOS 26+) e cantos arredondados.
final class PlayerPanel: NSPanel {
    let model: AppModel
    private var backdrop: Backdrop!
    private var hosting: FirstMouseHostingView<PlayerView>!
    private var snapWork: DispatchWorkItem?
    private var peekWork: DispatchWorkItem?
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

        hosting = FirstMouseHostingView(rootView: PlayerView(model: model))
        hosting.sizingOptions = [] // o tamanho da janela é controlado aqui (ver fit)
        backdrop = Backdrop(content: hosting, radius: Self.radius)
        root.addSubview(backdrop.view)
        backdrop.setFrame(root.bounds)

        // O SwiftUI avisa o tamanho real do conteúdo sempre que ele muda (capa, título, recolher...),
        // e a janela acompanha na hora. Antes o tamanho era lido uma vez só e o player saía cortado.
        model.onContentSize = { [weak self] size in DispatchQueue.main.async { self?.fit(size) } }

        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: self, queue: .main) { [weak self] _ in
            self?.scheduleSnap()
        }
        installMonitors()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // ---------- Aparência ----------

    func applySettings() {
        level = .floating // sempre no topo (fixo)
        alphaValue = 1    // opacidade máxima em repouso (fixo); repouso e hover mudam só o vidro
        backdrop.apply(model.settings)
        fitToContent()
    }

    /// Mouse entra: abre na hora (modo solto). Sai: espera 200 ms antes de recolher, para não piscar.
    private func setHover(_ hover: Bool) {
        guard model.hover != hover else { return }
        model.hover = hover
        peekWork?.cancel(); peekWork = nil
        if hover {
            model.peek = true
        } else if model.peek {
            let w = DispatchWorkItem { [weak self] in
                guard let self, !self.model.hover else { return }
                self.model.peek = false
            }
            peekWork = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: w)
        }
    }

    func fitToContent() { fit(hosting.fittingSize) }

    /// Ajusta a janela ao conteúdo, mantendo fixo o canto mais perto da borda da tela,
    /// para o player crescer "para dentro" em vez de pular de lugar.
    func fit(_ wanted: NSSize) {
        let size = NSSize(width: ceil(wanted.width), height: ceil(wanted.height))
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
            // Solto e aberto pelo mouse, guarda a posição da pílula recolhida só quando ela estiver recolhida.
            if self.model.settings.Collapsed && !self.model.compact { return }
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

    // ---------- Rolagem = volume do Spotify (fixo) ----------

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
