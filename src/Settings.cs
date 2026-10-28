using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using Microsoft.Win32;

namespace Nook;

public sealed class Settings
{
    // Elementos visíveis
    public bool ShowCover { get; set; } = true;
    public bool ShowTitle { get; set; } = true;
    public bool ShowShuffle { get; set; } = false;
    public bool ShowPrev { get; set; } = true;
    public bool ShowPlay { get; set; } = true;
    public bool ShowNext { get; set; } = true;
    public bool ShowRepeat { get; set; } = false;
    public bool ShowProgress { get; set; } = true;
    public bool ShowOpen { get; set; } = true;
    public bool ShowGear { get; set; } = true;

    // Aparência
    public double Scale { get; set; } = 1.0;
    public double IdleOpacity { get; set; } = 0.55;
    public bool Blur { get; set; } = true;
    /// <summary>O que aparece no quadrado da capa: "Cover", "Bars" ou "Waves".</summary>
    public string Visual { get; set; } = "Cover";
    public bool CoverAccent { get; set; } = true;       // barras/progresso na cor da capa
    public bool CoverClickCycles { get; set; } = true;  // clique na capa troca Capa → Barras → Ondas
    public bool HideWhenIdle { get; set; } = true;      // some quando não há player aberto
    /// <summary>Seções do menu de configurações abertas ("Elements", "Look", "Behavior").</summary>
    public List<string> OpenSections { get; set; } = new() { "Look" };
    /// <summary>"auto" (idioma do Windows), "en" ou "pt".</summary>
    public string Language { get; set; } = "auto";
    public bool FocusTimer { get; set; } = false;
    public bool ShowHideBtn { get; set; } = true;         // botão esconder no player
    public string Layout { get; set; } = "H";            // "H" horizontal, "V" vertical
    public int AutoHideMinutes { get; set; } = 5;       // esconde após N min pausado (0 = nunca)      // pílula de timer de foco colada ao player

    // Comportamento
    public bool Topmost { get; set; } = true;
    public bool HideOnFullscreen { get; set; } = true;
    public bool LockPosition { get; set; } = false;
    public bool StartWithWindows { get; set; } = false;
    public bool TrayIcon { get; set; } = true;
    public bool WheelVolume { get; set; } = true;

    public double? Left { get; set; }
    public double? Top { get; set; }

    static readonly string Dir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Nook");
    static readonly string FilePath = Path.Combine(Dir, "settings.json");

    public static Settings Load()
    {
        try
        {
            // Herda as preferências da época em que o app se chamava MiniPlayer.
            string legacy = Path.Combine(Path.GetDirectoryName(Dir)!, "MiniPlayer", "settings.json");
            string path = File.Exists(FilePath) ? FilePath : legacy;
            if (File.Exists(path))
                return JsonSerializer.Deserialize<Settings>(File.ReadAllText(path)) ?? new Settings();
        }
        catch { }
        return new Settings();
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(Dir);
            File.WriteAllText(FilePath, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { }
    }

    const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";

    public void ApplyStartup()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: true);
            if (key == null) return;
            key.DeleteValue("MiniPlayer", throwOnMissingValue: false);
            if (StartWithWindows && Environment.ProcessPath is string exe)
                key.SetValue("Nook", $"\"{exe}\"");
            else
                key.DeleteValue("Nook", throwOnMissingValue: false);
        }
        catch { }
    }
}
