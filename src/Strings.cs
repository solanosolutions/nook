using System;
using System.Collections.Generic;
using System.Globalization;
using System.Windows.Markup;

namespace Nook;

/// <summary>
/// Textos da interface em inglês e português. O idioma sempre segue o Windows:
/// português se o sistema estiver em português, inglês para qualquer outro.
/// </summary>
public static class Strings
{
    public static string Lang { get; private set; } = "en";

    public static void Init() =>
        Lang = CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "pt" ? "pt" : "en";

    public static string Get(string key) =>
        Table.TryGetValue(key, out var t) ? (Lang == "pt" ? t.pt : t.en) : key;

    static readonly Dictionary<string, (string en, string pt)> Table = new()
    {
        // Player
        ["NothingPlaying"] = ("Nothing playing", "Nada tocando"),
        ["ClickToOpen"] = ("Click ▶ to open Spotify", "Clique ▶ para abrir o Spotify"),
        ["SpotifyVolume"] = ("Spotify volume", "Volume do Spotify"),
        ["Volume"] = ("Volume", "Volume"),
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
        ["Style"] = ("Style", "Estilo"),
        ["Minimalist"] = ("Minimalist", "Minimalist"),
        ["OldSchool"] = ("Old School", "Old School"),
        ["Refined"] = ("Refined", "Refined"),
        ["Size"] = ("Size", "Tamanho"),
        ["CoverAccent"] = ("Album-art accent color", "Cor da capa no destaque"),
        ["SecBehavior"] = ("BEHAVIOR", "COMPORTAMENTO"),
        ["HideFullscreen"] = ("Hide in fullscreen", "Esconder em tela cheia"),
        ["HideIdle"] = ("Hide when no player is open", "Esconder sem player aberto"),
        ["Lock"] = ("Lock position", "Travar posição"),
        ["TrayIcon"] = ("Tray icon", "Ícone na bandeja"),
        ["Startup"] = ("Start with Windows", "Iniciar com o Windows"),
        ["QuitNook"] = ("Quit Nook", "Sair do Nook"),

        // Timer de foco
        ["FocusTimer"] = ("Focus timer", "Timer de foco"),
        ["Focus"] = ("Focus", "Foco"),
        ["TimesUp"] = ("Time's up!", "Tempo!"),
        ["Pause"] = ("Pause", "Pausar"),
        ["Resume"] = ("Resume", "Continuar"),
        ["Cancel"] = ("Cancel", "Cancelar"),
        ["CustomTip"] = ("Type minutes and press Enter", "Digite os minutos e aperte Enter"),

        // Esconder e layout
        ["HideTip"] = ("Hide (comes back on next play)", "Esconder (volta no próximo play)"),
        ["HideBtnEl"] = ("Hide button", "Botão esconder"),
        ["AutoHide"] = ("Hide when paused", "Esconder pausado"),
        ["Never"] = ("Never", "Nunca"),
        ["Layout"] = ("Layout", "Layout"),
        ["Horizontal"] = ("Horizontal", "Horizontal"),
        ["Vertical"] = ("Vertical", "Vertical"),

        // Pin: fixado (completo) ou solto (recolhido, abre no mouse)
        ["UnpinTip"] = ("Unpin (collapses, opens on hover)", "Soltar (recolhe e abre ao passar o mouse)"),
        ["PinTip"] = ("Pin open", "Fixar aberto"),

        // Rodapé do menu
        ["GitHubTip"] = ("Nook on GitHub", "Nook no GitHub"),
        ["InstagramTip"] = ("Follow on Instagram", "Siga no Instagram"),
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
