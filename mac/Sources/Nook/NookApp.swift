import AppKit
import Combine
import ServiceManagement

/// Ponto de entrada: app de barra de menus (sem ícone no Dock, ver LSUIElement no Info.plist).
@main
enum NookApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }

    static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var player: PlayerPanel!
    private var settingsPanel: SettingsPanel?
    private var resignToken: NSObjectProtocol?
    private var statusFor = "" // idioma/ícone com que a barra de menus foi montada
    private var statusItem: NSStatusItem?
    private var bag = Set<AnyCancellable>()

    // Motivos para o player estar escondido (iguais aos da versão Windows).
    private var userHidden = false      // pela barra de menus
    private var manualHidden = false    // botão esconder; volta no próximo play
    private var idleHidden = false      // Spotify fechado
    private var pausedHidden = false    // pausado há N minutos
    private var autoOverride = false    // pediu para mostrar pela barra de menus: respeita até a condição passar
    private var wasPlaying = false
    private var idleWork: DispatchWorkItem?
    private var pauseWork: DispatchWorkItem?

    private var S: Settings { model.settings }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Uma instância só.
        let me = NSRunningApplication.current
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0 != me }) {
            NSApp.terminate(nil)
            return
        }

        let settings = Settings.load()
        Strings.setup(settings.Language)
        model = AppModel(settings: settings)
        model.onOpenSettings = { [weak self] in self?.openSettings() }
        model.onHide = { [weak self] in self?.manualHidden = true; self?.applyVisibility() }
        model.onSettingsChanged = { [weak self] in self?.settingsChanged() }

        player = PlayerPanel(model: model)
        player.applySettings()
        player.placeInitially()
        player.orderFrontRegardless()

        model.spotify.$isRunning.removeDuplicates().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIdle() }.store(in: &bag)
        model.spotify.$isPlaying.removeDuplicates().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updatePauseHide() }.store(in: &bag)
        model.spotify.start()

        updateStatusItem()
        applyLoginItem()
    }

    // ---------- Configurações ----------

    private func settingsChanged() {
        Strings.setup(S.Language)
        player.applySettings()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.player.fitToContent() }
        rebuildStatusItem()
        applyLoginItem()
        updateIdle()
        pauseWork?.cancel(); pauseWork = nil // novo tempo de "esconder pausado" vale a partir de agora
        updatePauseHide()
    }

    func openSettings() {
        if let p = settingsPanel { p.makeKeyAndOrderFront(nil); return }
        let panel = SettingsPanel(model: model) { [weak self] in self?.closeSettings() }
        settingsPanel = panel
        model.settingsOpen = true
        player.applyAlpha(animated: true)
        NSApp.activate(ignoringOtherApps: true)
        panel.show(near: player)
        resignToken = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            // Clicou fora do menu (em outro app): fecha, como a versão Windows.
            if NSApp.keyWindow == nil { self?.closeSettings() }
        }
    }

    private func closeSettings() {
        guard let p = settingsPanel else { return }
        if let t = resignToken { NotificationCenter.default.removeObserver(t) }
        resignToken = nil
        settingsPanel = nil
        p.orderOut(nil)
        model.settingsOpen = false
        player.applyAlpha(animated: true)
    }

    private func applyLoginItem() {
        let service = SMAppService.mainApp
        do {
            if S.StartAtLogin, service.status != .enabled { try service.register() }
            else if !S.StartAtLogin, service.status == .enabled { try service.unregister() }
        } catch {}
    }

    // ---------- Visibilidade ----------

    private func applyVisibility() {
        if !idleHidden && !pausedHidden { autoOverride = false }
        let auto = (idleHidden || pausedHidden) && !autoOverride
        let show = !userHidden && !manualHidden && !auto
        if show && !player.isVisible { player.orderFrontRegardless() }
        else if !show && player.isVisible { player.orderOut(nil) }
    }

    /// Some (após 3 s, para não piscar ao reabrir) quando o Spotify está fechado.
    private func updateIdle() {
        let idle = S.HideWhenIdle && !model.spotify.isRunning
        if idle {
            if !idleHidden && idleWork == nil {
                let w = DispatchWorkItem { [weak self] in
                    self?.idleWork = nil; self?.idleHidden = true; self?.applyVisibility()
                }
                idleWork = w
                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: w)
            }
            return
        }
        idleWork?.cancel(); idleWork = nil
        if idleHidden { idleHidden = false; applyVisibility() }
    }

    /// Pausado por N minutos → some. Qualquer play traz de volta, inclusive depois do botão esconder.
    private func updatePauseHide() {
        let playing = model.spotify.isPlaying
        if playing && !wasPlaying { manualHidden = false }
        wasPlaying = playing

        let paused = S.AutoHideMinutes > 0 && model.spotify.isRunning && !playing
        if paused {
            if !pausedHidden && pauseWork == nil {
                let w = DispatchWorkItem { [weak self] in
                    self?.pauseWork = nil; self?.pausedHidden = true; self?.applyVisibility()
                }
                pauseWork = w
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(S.AutoHideMinutes * 60), execute: w)
            }
        } else {
            pauseWork?.cancel(); pauseWork = nil
            pausedHidden = false
        }
        applyVisibility()
    }

    @objc func toggleVisible() {
        userHidden = player.isVisible
        if !userHidden {
            manualHidden = false
            if idleHidden || pausedHidden { autoOverride = true }
        }
        applyVisibility()
    }

    // ---------- Barra de menus ----------

    private func rebuildStatusItem() {
        guard statusFor != "\(S.TrayIcon)\(Strings.lang)" else { return }
        if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
        statusItem = nil
        updateStatusItem()
    }

    private func updateStatusItem() {
        statusFor = "\(S.TrayIcon)\(Strings.lang)"
        guard S.TrayIcon else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Nook")
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(withTitle: Strings.get("ShowHide"), action: #selector(toggleVisible), keyEquivalent: "").target = self
        menu.addItem(withTitle: Strings.get("Settings"), action: #selector(menuSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: Strings.get("OpenSpotify"), action: #selector(menuOpenSpotify), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: Strings.get("Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func menuSettings() { openSettings() }
    @objc private func menuOpenSpotify() { SpotifyService.open() }

    func applicationWillTerminate(_ notification: Notification) {
        model?.settings.save()
    }
}
