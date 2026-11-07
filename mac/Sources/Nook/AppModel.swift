import SwiftUI
import Combine

/// Estado compartilhado entre o player, o menu de configurações e a barra de menus.
final class AppModel: ObservableObject {
    let settings: Settings
    let spotify = SpotifyService()

    @Published var hover = false
    /// Texto temporário no lugar do artista (ex.: "Volume do Spotify 40%").
    @Published var flash: String?
    @Published var settingsOpen = false

    /// Chamado depois de qualquer mudança de configuração (o AppDelegate reaplica janela, barra de menus etc.).
    var onSettingsChanged: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onHide: (() -> Void)?

    private var flashWork: DispatchWorkItem?
    private var bag = Set<AnyCancellable>()

    init(settings: Settings) {
        self.settings = settings
        // Mudanças do Spotify redesenham o player.
        spotify.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &bag)
    }

    /// Verde do Spotify ou a cor da capa.
    var accent: Color {
        if settings.CoverAccent, let c = spotify.coverColor { return Color(nsColor: c) }
        return Glass.spotifyGreen
    }

    func binding<T>(_ key: ReferenceWritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(get: { self.settings[keyPath: key] },
                set: { self.settings[keyPath: key] = $0; self.changed() })
    }

    func changed() {
        objectWillChange.send()
        settings.save()
        onSettingsChanged?()
    }

    func showFlash(_ text: String) {
        flash = text
        flashWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.flash = nil }
        flashWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: w)
    }

    /// Roda do mouse / trackpad: volume só do Spotify.
    func wheel(up: Bool) {
        guard settings.WheelVolume, spotify.isRunning, let v = spotify.stepVolume(up ? 4 : -4) else { return }
        showFlash("\(Strings.get("SpotifyVolume"))  \(v)%")
    }

    static let gitHubURL = URL(string: "https://github.com/solanosolutions/nook")!
    static let instagramURL = URL(string: "https://www.instagram.com/solano.ai/")!

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
