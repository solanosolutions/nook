import Foundation

/// Preferências do usuário, com as mesmas chaves do settings.json da versão Windows.
/// Fica em ~/Library/Application Support/Nook/settings.json.
final class Settings: Codable {
    // Elementos opcionais. Capa, título, anterior, play, próxima, engrenagem, esconder e pin são fixos.
    var ShowShuffle = false
    var ShowRepeat = false
    var ShowProgress = true
    var ShowOpen = true

    // Aparência
    var Scale = 1.0
    /// Um dos três estilos fixos (iguais aos da versão Windows): "Minimalist", "OldSchool" ou "Refined".
    var Style = "Minimalist"
    var CoverAccent = true
    /// Player solto (sem o pin): recolhido em capa + play, abre ao passar o mouse. Padrão: fixado, completo.
    var Collapsed = false
    /// Seções do menu de configurações abertas ("Elements", "Look", "Behavior").
    var OpenSections = ["Look"]

    // Comportamento
    // Fixos, sem opção no menu: sempre no topo, idioma automático, rolagem = volume, transparência máxima em repouso (0.15).
    var HideWhenIdle = true
    /// Esconde após N minutos pausado (0 = nunca).
    var AutoHideMinutes = 5
    var LockPosition = false
    var StartAtLogin = false
    var TrayIcon = true

    var Left: Double?
    var Top: Double?

    init() {}

    // Chaves que faltam no arquivo (versão antiga ou da versão Windows) ficam no padrão.
    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func v<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        ShowShuffle = v(.ShowShuffle, ShowShuffle)
        ShowRepeat = v(.ShowRepeat, ShowRepeat)
        ShowProgress = v(.ShowProgress, ShowProgress)
        ShowOpen = v(.ShowOpen, ShowOpen)
        Scale = v(.Scale, Scale)
        CoverAccent = v(.CoverAccent, CoverAccent)
        Collapsed = v(.Collapsed, Collapsed)
        OpenSections = v(.OpenSections, OpenSections)
        HideWhenIdle = v(.HideWhenIdle, HideWhenIdle)
        AutoHideMinutes = v(.AutoHideMinutes, AutoHideMinutes)
        LockPosition = v(.LockPosition, LockPosition)
        StartAtLogin = v(.StartAtLogin, StartAtLogin)
        TrayIcon = v(.TrayIcon, TrayIcon)
        Left = v(.Left, Left)
        Top = v(.Top, Top)

        // Estilo: quem vem da versão antiga herda o mais parecido com o vidro que usava (mesma regra do Windows).
        if let st = try? c.decodeIfPresent(String.self, forKey: .Style), Glass.styles.contains(st) {
            Style = st
        } else {
            let old = try? decoder.container(keyedBy: LegacyKeys.self)
            let glass = (try? old?.decodeIfPresent(String.self, forKey: .GlassStyle)) ?? nil
            let visual = (try? old?.decodeIfPresent(String.self, forKey: .Visual)) ?? nil
            if glass == "Liquid" || visual == "Waves" { Style = Glass.refined }
            else if glass == "Frozen" || visual == "Cover" { Style = Glass.oldSchool }
            else { Style = Glass.minimalist }
        }
    }

    private enum LegacyKeys: String, CodingKey { case GlassStyle, Visual }

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
