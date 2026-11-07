import Foundation

/// Preferências do usuário, com as mesmas chaves do settings.json da versão Windows.
/// Fica em ~/Library/Application Support/Nook/settings.json.
final class Settings: Codable {
    // Elementos visíveis
    var ShowCover = true
    var ShowTitle = true
    var ShowShuffle = false
    var ShowPrev = true
    var ShowPlay = true
    var ShowNext = true
    var ShowRepeat = false
    var ShowProgress = true
    var ShowOpen = true
    var ShowGear = true
    var ShowHideBtn = true

    // Aparência
    var Scale = 1.0
    var IdleOpacity = 0.55
    var Blur = true
    /// "Frosted" (fosco), "Frozen" ou "Liquid".
    var GlassStyle = "Frosted"
    var CoverAccent = true
    /// "auto" (idioma do macOS), "en" ou "pt".
    var Language = "auto"

    // Comportamento
    var Topmost = true
    var HideWhenIdle = true
    /// Esconde após N minutos pausado (0 = nunca).
    var AutoHideMinutes = 5
    var LockPosition = false
    var StartAtLogin = false
    var TrayIcon = true
    var WheelVolume = true

    var Left: Double?
    var Top: Double?

    init() {}

    // Chaves que faltam no arquivo (versão antiga ou da versão Windows) ficam no padrão.
    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func v<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        ShowCover = v(.ShowCover, ShowCover)
        ShowTitle = v(.ShowTitle, ShowTitle)
        ShowShuffle = v(.ShowShuffle, ShowShuffle)
        ShowPrev = v(.ShowPrev, ShowPrev)
        ShowPlay = v(.ShowPlay, ShowPlay)
        ShowNext = v(.ShowNext, ShowNext)
        ShowRepeat = v(.ShowRepeat, ShowRepeat)
        ShowProgress = v(.ShowProgress, ShowProgress)
        ShowOpen = v(.ShowOpen, ShowOpen)
        ShowGear = v(.ShowGear, ShowGear)
        ShowHideBtn = v(.ShowHideBtn, ShowHideBtn)
        Scale = v(.Scale, Scale)
        IdleOpacity = v(.IdleOpacity, IdleOpacity)
        Blur = v(.Blur, Blur)
        GlassStyle = v(.GlassStyle, GlassStyle)
        CoverAccent = v(.CoverAccent, CoverAccent)
        Language = v(.Language, Language)
        Topmost = v(.Topmost, Topmost)
        HideWhenIdle = v(.HideWhenIdle, HideWhenIdle)
        AutoHideMinutes = v(.AutoHideMinutes, AutoHideMinutes)
        LockPosition = v(.LockPosition, LockPosition)
        StartAtLogin = v(.StartAtLogin, StartAtLogin)
        TrayIcon = v(.TrayIcon, TrayIcon)
        WheelVolume = v(.WheelVolume, WheelVolume)
        Left = v(.Left, Left)
        Top = v(.Top, Top)
    }

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Nook", isDirectory: true)
    }

    static var fileURL: URL { directory.appendingPathComponent("settings.json") }

    static func load() -> Settings {
        guard let data = try? Data(contentsOf: fileURL),
              let s = try? JSONDecoder().decode(Settings.self, from: data) else { return Settings() }
        return s
    }

    func save() {
        do {
            try FileManager.default.createDirectory(at: Settings.directory, withIntermediateDirectories: true)
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try enc.encode(self).write(to: Settings.fileURL, options: .atomic)
        } catch {}
    }
}
