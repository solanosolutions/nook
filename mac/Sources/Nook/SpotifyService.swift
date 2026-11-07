import AppKit

/// Lê e controla o Spotify pelo AppleScript dele (o MediaRemote do sistema ficou fechado a apps
/// de terceiros no macOS 15.4+). Atualiza na hora pela notificação que o Spotify publica a cada
/// mudança, e com uma leitura leve a cada 2 s para pegar aleatório/repetir e a posição.
/// Tudo roda na thread principal (o NSAppleScript não é thread-safe).
final class SpotifyService: ObservableObject {
    static let bundleID = "com.spotify.client"

    @Published private(set) var isRunning = false
    @Published private(set) var hasTrack = false
    @Published private(set) var title = ""
    @Published private(set) var artist = ""
    @Published private(set) var cover: NSImage?
    /// Cor marcante da capa (viva o bastante para o tema escuro); nil se a capa for cinza.
    @Published private(set) var coverColor: NSColor?
    @Published private(set) var isPlaying = false
    @Published private(set) var shuffle = false
    @Published private(set) var repeating = false
    /// Duração em segundos.
    @Published private(set) var duration: Double = 0
    /// O usuário negou (ou ainda não liberou) o controle do Spotify em Privacidade › Automação.
    @Published private(set) var notAuthorized = false

    private var basePosition: Double = 0
    private var baseTime = Date()
    private var artworkURL = ""
    private var poll: Timer?
    private var stateScript: NSAppleScript?

    /// Posição atual em segundos, andando sozinha entre as leituras.
    var position: Double {
        var p = basePosition
        if isPlaying { p += Date().timeIntervalSince(baseTime) }
        if duration > 0 { p = min(p, duration) }
        return max(0, p)
    }

    func start() {
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] n in
            if Self.isSpotify(n) { self?.setRunning(true) }
        }
        ws.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            if Self.isSpotify(n) { self?.setRunning(false) }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }

        setRunning(!NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty)
    }

    private static func isSpotify(_ n: Notification) -> Bool {
        (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == bundleID
    }

    private func setRunning(_ running: Bool) {
        isRunning = running
        poll?.invalidate()
        poll = nil
        if running {
            refresh()
            let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
            t.tolerance = 0.5
            RunLoop.main.add(t, forMode: .common)
            poll = t
        } else {
            clearTrack()
        }
    }

    private func clearTrack() {
        hasTrack = false
        title = ""; artist = ""; cover = nil; coverColor = nil; artworkURL = ""
        isPlaying = false; duration = 0; basePosition = 0
    }

    // ---------- Leitura ----------

    private static let stateSource = """
    tell application id "com.spotify.client"
        set st to (player state as string)
        if st is "stopped" then return {st}
        set t to current track
        return {st, (name of t), (artist of t), (duration of t), player position, (artwork url of t), shuffling, repeating}
    end tell
    """

    func refresh() {
        // "tell application" abriria o Spotify se ele estivesse fechado: só fala com ele se já estiver aberto.
        guard isRunning, !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty else { return }
        if stateScript == nil {
            let s = NSAppleScript(source: Self.stateSource)
            var err: NSDictionary?
            guard s?.compileAndReturnError(&err) == true else { return }
            stateScript = s
        }
        var err: NSDictionary?
        guard let r = stateScript?.executeAndReturnError(&err), err == nil else {
            handle(err)
            return
        }
        notAuthorized = false

        let state = r.atIndex(1)?.stringValue ?? "stopped"
        guard state != "stopped", r.numberOfItems >= 8 else { clearTrack(); return }

        let playing = state == "playing"
        let pos = r.atIndex(5)?.doubleValue ?? 0
        let newTitle = r.atIndex(2)?.stringValue ?? ""
        let newArtist = r.atIndex(3)?.stringValue ?? ""
        let dur = (r.atIndex(4)?.doubleValue ?? 0) / 1000 // o Spotify devolve em ms

        // Só reancora a posição quando ela de fato divergiu (evita o progresso "tremer" a cada leitura).
        if playing != isPlaying || abs(pos - position) > 1.5 || newTitle != title {
            basePosition = pos
            baseTime = Date()
        }
        if title != newTitle { title = newTitle }
        if artist != newArtist { artist = newArtist }
        if duration != dur { duration = dur }
        if isPlaying != playing { isPlaying = playing }
        let sh = r.atIndex(7)?.booleanValue ?? false
        let rp = r.atIndex(8)?.booleanValue ?? false
        if shuffle != sh { shuffle = sh }
        if repeating != rp { repeating = rp }
        if !hasTrack { hasTrack = true }

        let art = r.atIndex(6)?.stringValue ?? ""
        if art != artworkURL {
            artworkURL = art
            loadArtwork(art)
        }
    }

    private func handle(_ err: NSDictionary?) {
        let code = (err?[NSAppleScript.errorNumber] as? Int) ?? 0
        if code == -1743 { notAuthorized = true } // errAEEventNotPermitted
    }

    private func loadArtwork(_ urlString: String) {
        guard let url = URL(string: urlString), url.scheme == "https" else {
            cover = nil; coverColor = nil
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            let image = data.flatMap { NSImage(data: $0) }
            let color = image.flatMap(CoverColor.vivid)
            DispatchQueue.main.async {
                guard let self, self.artworkURL == urlString else { return }
                self.cover = image
                self.coverColor = color
            }
        }.resume()
    }

    // ---------- Comandos ----------

    @discardableResult
    private func run(_ body: String) -> NSAppleEventDescriptor? {
        guard isRunning else { return nil }
        let script = NSAppleScript(source: "tell application id \"\(Self.bundleID)\"\n\(body)\nend tell")
        var err: NSDictionary?
        let r = script?.executeAndReturnError(&err)
        if err != nil { handle(err); return nil }
        return r
    }

    func playPause() { run("playpause"); refreshSoon() }
    func next() { run("next track"); refreshSoon() }
    func previous() { run("previous track"); refreshSoon() }
    func toggleShuffle() { run("set shuffling to \(!shuffle)"); refreshSoon() }
    func toggleRepeat() { run("set repeating to \(!repeating)"); refreshSoon() }

    func seek(fraction: Double) {
        guard duration > 0 else { return }
        let target = duration * min(max(fraction, 0), 1)
        basePosition = target
        baseTime = Date()
        objectWillChange.send()
        run(String(format: "set player position to %.2f", locale: Locale(identifier: "en_US_POSIX"), target))
    }

    /// Soma delta (-100..100) ao volume do próprio Spotify (não mexe no volume do Mac). Devolve o novo volume.
    func stepVolume(_ delta: Int) -> Int? {
        let r = run("""
        set v to (sound volume) + (\(delta))
        if v > 100 then set v to 100
        if v < 0 then set v to 0
        set sound volume to v
        return v
        """)
        return r.map { Int($0.int32Value) }
    }

    private func refreshSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.refresh() }
    }

    static func open() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            if let web = URL(string: "https://open.spotify.com") { NSWorkspace.shared.open(web) }
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }
}
