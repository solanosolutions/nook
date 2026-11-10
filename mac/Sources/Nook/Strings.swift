import Foundation

/// Textos da interface em inglês e português, sempre no idioma do macOS (sem opção no menu).
enum Strings {
    static private(set) var lang = "en"

    static func setup() {
        let first = Locale.preferredLanguages.first ?? "en"
        lang = first.hasPrefix("pt") ? "pt" : "en"
    }

    static func get(_ key: String) -> String {
        guard let t = table[key] else { return key }
        return lang == "pt" ? t.1 : t.0
    }

    private static let table: [String: (String, String)] = [
        // Player
        "NothingPlaying": ("Nothing playing", "Nada tocando"),
        "ClickToOpen": ("Click ▶ to open Spotify", "Clique ▶ para abrir o Spotify"),
        "SpotifyVolume": ("Spotify volume", "Volume do Spotify"),
        "Shuffle": ("Shuffle", "Aleatório"),
        "Previous": ("Previous", "Anterior"),
        "PlayPause": ("Play / pause", "Tocar / pausar"),
        "Next": ("Next", "Próxima"),
        "Repeat": ("Repeat", "Repetir"),
        "OpenSpotify": ("Open Spotify", "Abrir Spotify"),
        "SettingsTip": ("Settings (or double-click)", "Configurações (ou duplo clique)"),
        "HideTip": ("Hide (comes back on next play)", "Esconder (volta no próximo play)"),
        "PinTip": ("Pinned: always full. Click to collapse", "Fixado: sempre completo. Clique para recolher"),
        "UnpinTip": ("Collapsed: opens on hover. Click to pin", "Recolhido: abre ao passar o mouse. Clique para fixar"),
        "AllowAutomation": ("Allow Nook to control Spotify", "Permita o Nook controlar o Spotify"),
        "AllowAutomationHint": ("System Settings › Privacy › Automation", "Ajustes › Privacidade › Automação"),

        // Barra de menus
        "ShowHide": ("Show / hide", "Mostrar / esconder"),
        "Settings": ("Settings", "Configurações"),
        "Quit": ("Quit", "Sair"),

        // Menu de configurações
        "Close": ("Close", "Fechar"),
        "SecElements": ("ELEMENTS", "ELEMENTOS"),
        "Cover": ("Cover", "Capa"),
        "Title": ("Title", "Título"),
        "Play": ("Play", "Play"),
        "Progress": ("Progress", "Progresso"),
        "Gear": ("Gear", "Engrenagem"),
        "HideBtnEl": ("Hide button", "Botão esconder"),
        "SecLook": ("LOOK", "APARÊNCIA"),
        "Size": ("Size", "Tamanho"),
        "Style": ("Style", "Estilo"),
        "CoverAccent": ("Album-art accent color", "Cor da capa no destaque"),
        "SecBehavior": ("BEHAVIOR", "COMPORTAMENTO"),
        "HideIdle": ("Hide when Spotify is closed", "Esconder com o Spotify fechado"),
        "AutoHide": ("Hide when paused", "Esconder pausado"),
        "Never": ("Never", "Nunca"),
        "Lock": ("Lock position", "Travar posição"),
        "TrayIcon": ("Menu bar icon", "Ícone na barra de menus"),
        "Startup": ("Open at login", "Abrir ao iniciar sessão"),
        "QuitNook": ("Quit Nook", "Sair do Nook"),
        "GitHubTip": ("Nook on GitHub", "Nook no GitHub"),
        "InstagramTip": ("Follow on Instagram", "Siga no Instagram"),
    ]
}
