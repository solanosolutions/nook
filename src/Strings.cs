using System;
using System.Collections.Generic;
using System.Globalization;
using System.Windows.Markup;

namespace Nook;

/// <summary>
/// Textos da interface em inglês e português. "auto" segue o idioma do Windows:
/// português se o sistema estiver em português, inglês para qualquer outro.
/// </summary>
public static class Strings
{
    public static string Lang { get; private set; } = "en";

    public static void Init(string setting) => Lang = setting switch
    {
        "pt" => "pt",
        "en" => "en",
        _ => CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "pt" ? "pt" : "en",
    };

    public static string Get(string key) =>
        Table.TryGetValue(key, out var t) ? (Lang == "pt" ? t.pt : t.en) : key;

    static readonly Dictionary<string, (string en, string pt)> Table = new()
    {
        // Player
        ["NothingPlaying"] = ("Nothing playing", "Nada tocando"),
        ["ClickToOpen"] = ("Click ▶ to open Spotify", "Clique ▶ para abrir o Spotify"),
        ["SpotifyVolume"] = ("Spotify volume", "Volume do Spotify"),
        ["Shuffle"] = ("Shuffle", "Aleatório"),
        ["Previous"] = ("Previous", "Anterior"),
        ["PlayPause"] = ("Play / pause", "Tocar / pausar"),
        ["Next"] = ("Next", "Próxima"),
        ["Repeat"] = ("Repeat", "Repetir"),
        ["OpenSpotify"] = ("Open Spotify", "Abrir Spotify"),
        ["SettingsTip"] = ("Settings (or double-click)", "Configurações (ou duplo clique)"),

        // Bandeja
        ["ShowHide"] = ("Show / hide", "Mostrar / esconder"),
        ["Settings"] = ("Settings", "Configurações"),
        ["Quit"] = ("Quit", "Sair"),

        // Menu de configurações
        ["Close"] = ("Close", "Fechar"),
        ["SecElements"] = ("ELEMENTS", "ELEMENTOS"),
        ["Cover"] = ("Cover", "Capa"),
        ["Title"] = ("Title", "Título"),
        ["Play"] = ("Play", "Play"),
        ["Progress"] = ("Progress", "Progresso"),
        ["Gear"] = ("Gear", "Engrenagem"),
        ["SecLook"] = ("LOOK", "APARÊNCIA"),
        ["Visual"] = ("Visual", "Visual"),
        ["Bars"] = ("Bars", "Barras"),
        ["Waves"] = ("Waves", "Ondas"),
        ["Size"] = ("Size", "Tamanho"),
        ["IdleOpacity"] = ("Idle opacity", "Opacidade em repouso"),
        ["Blur"] = ("Blur (glass) at rest", "Blur (vidro) em repouso"),
        ["CoverAccent"] = ("Album-art accent color", "Cor da capa no destaque"),
        ["SecBehavior"] = ("BEHAVIOR", "COMPORTAMENTO"),
        ["Topmost"] = ("Always on top", "Sempre no topo"),
        ["HideFullscreen"] = ("Hide in fullscreen", "Esconder em tela cheia"),
        ["HideIdle"] = ("Hide when no player is open", "Esconder sem player aberto"),
        ["CoverClick"] = ("Click cover to switch visual", "Clique na capa troca o visual"),
        ["Lock"] = ("Lock position", "Travar posição"),
        ["Wheel"] = ("Mouse wheel = Spotify volume", "Roda do mouse = volume do Spotify"),
        ["TrayIcon"] = ("Tray icon", "Ícone na bandeja"),
        ["Startup"] = ("Start with Windows", "Iniciar com o Windows"),
        ["Language"] = ("Language", "Idioma"),
        ["QuitNook"] = ("Quit Nook", "Sair do Nook"),
    };
}

/// <summary>Uso no XAML: Content="{local:Tr Cover}".</summary>
public sealed class TrExtension : MarkupExtension
{
    public string Key { get; set; } = "";
    public TrExtension() { }
    public TrExtension(string key) => Key = key;
    public override object ProvideValue(IServiceProvider serviceProvider) => Strings.Get(Key);
}
