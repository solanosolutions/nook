<div align="center">

<img src="src/Assets/nook.png" width="96" alt="Nook icon" />

# Nook

**A tiny, frosted-glass mini player for Spotify that lives in a corner of your screen.**

Pause, skip and see what's playing without ever opening Spotify again.

[![Download](https://img.shields.io/github/v/release/solanosolutions/nook?label=download&color=1ED760&style=for-the-badge)](https://github.com/solanosolutions/nook/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D4?style=for-the-badge&logo=windows)](#-download)
[![License](https://img.shields.io/github/license/solanosolutions/nook?style=for-the-badge&color=555)](LICENSE)
[![Stars](https://img.shields.io/github/stars/solanosolutions/nook?style=for-the-badge&color=f5c518)](https://github.com/solanosolutions/nook/stargazers)

<img src="docs/demo.gif" alt="Nook demo: frosted glass at rest, sharp on hover, live audio waves and bars" />

[**Download**](https://github.com/solanosolutions/nook/releases/latest) · [Features](#-features) · [How to use](#-how-to-use) · [FAQ](#-faq) · [Roadmap](#-roadmap) · [Português](README.pt-BR.md)

</div>

---

## Why Nook?

I listen to music all day while I work. Every time I wanted to pause or skip, I had to dig Spotify out of the taskbar, a whole app just to press one button. Other mini players felt clunky, heavy, or required logging in with API keys.

So I built the one I wanted: **minimal, beautiful, and invisible until you need it.**

- 🪶 **Featherweight.** ~30–60 MB of RAM and **under 1% CPU**, even with the live visualizer. Spotify itself uses 10× more.
- 🔑 **Zero setup.** No login, no API key, no Spotify account linking. Open it and it works.
- 🫥 **Out of your way.** No taskbar icon, no Alt+Tab entry, and it hides itself when you watch a movie in fullscreen.

## ✨ Features

| | |
|---|---|
| 🧊 **Frosted glass** | Translucent and blurred at rest, crisp and solid the moment your mouse arrives. |
| 🎵 **Live visualizer** | Bars or waves that react to the *real* audio, captured **only from Spotify** (notifications and videos don't interfere). |
| 🎨 **Album-art accent** | Progress bar and visualizer take the dominant color of the current cover. |
| 📜 **Scrolling titles** | Long song names scroll smoothly; hover to freeze them. |
| 🖱️ **Scroll for volume** | Mouse wheel over the player changes **Spotify's volume only**, not your whole PC. |
| 🎬 **Fullscreen-aware** | Hides automatically when a movie, game or presentation goes fullscreen on its monitor. |
| 🧲 **Drag anywhere** | Snaps to screen edges and remembers its position. |
| 🎛️ **Fully configurable** | Pick which buttons show, size, idle opacity, blur, visual style and more. |
| 🚀 **Starts with Windows** | Optional, one toggle. |

<div align="center">
<img src="docs/shot-hover.png" width="420" alt="Nook on hover" />&nbsp;&nbsp;<img src="docs/shot-bars.png" width="420" alt="Nook with live bars" />
</div>

## 📥 Download

1. Grab **`Nook.exe`** from the [latest release](https://github.com/solanosolutions/nook/releases/latest).
2. Put it in any folder (e.g. `Documents\Nook`) and double-click it.
3. That's it. Play something on Spotify and Nook shows up in the bottom-right corner.

No installer and no .NET to install: everything ships inside the single `.exe`.

> **"Windows protected your PC"?** Nook is a free, open-source app that isn't code-signed yet (certificates are expensive), so SmartScreen warns about any new unsigned app. Click **More info → Run anyway**. You can verify the file against the SHA-256 published in each release, or [build it yourself](#-build-from-source).

**Requirements:** Windows 10 (2004+) or Windows 11, x64. The live visualizer needs **Windows 11**; on Windows 10 Nook simply shows the album cover.

> 🍎🐧 **macOS and Linux are coming soon.** Nook is Windows-only today. [Star the repo](https://github.com/solanosolutions/nook/stargazers) or watch releases to know when they land.

## 🖱️ How to use

| Action | What it does |
|---|---|
| **Drag** | Move the player anywhere |
| **Double-click** or **right-click** | Open settings |
| **Click the cover** | Cycle visual: cover → bars → waves |
| **Mouse wheel** | Spotify volume up / down |
| **Click the progress bar** | Jump to that point of the song |
| **Tray icon** | Show / hide, settings, quit |

<details>
<summary><b>⚙️ See the settings menu</b></summary>
<br>
<img src="docs/shot-settings.png" width="300" alt="Nook settings menu" />

> The interface is currently in **Portuguese** 🇧🇷. English is next on the [roadmap](#-roadmap).
</details>

## 🔒 Privacy

- Nook talks **only to Windows**: it reads what's playing through the same media controls the Windows volume flyout uses.
- The visualizer analyzes audio **in memory, in real time**. Nothing is recorded, saved or sent anywhere.
- No telemetry, no accounts, no network requests. Settings live in `%AppData%\Nook\settings.json`.

## ❓ FAQ

<details>
<summary><b>Does it work with apps other than Spotify?</b></summary>

Yes. Nook prefers Spotify, but if Spotify isn't open it controls whatever is playing (YouTube in your browser, other players), using the system volume for the wheel.
</details>

<details>
<summary><b>Do I need Spotify Premium?</b></summary>

No. Nook only uses the standard Windows media controls, so it works with Spotify Free too.
</details>

<details>
<summary><b>The player disappeared!</b></summary>

It's probably auto-hiding: either something is fullscreen, or no player is open (Spotify closed). Use the tray icon to show it, or turn those options off in settings.
</details>

<details>
<summary><b>How do I uninstall it?</b></summary>

Turn off "Start with Windows" in settings, quit from the tray icon, and delete `Nook.exe` and the `%AppData%\Nook` folder. That's all; nothing else is touched.
</details>

## 🗺️ Roadmap

- [x] Frosted-glass widget, drag, edge snapping, tray
- [x] Live audio visualizer (Spotify-only capture)
- [x] Album-art accent color, scrolling titles, Spotify-only volume
- [x] Auto-hide on fullscreen / when nothing is open
- [ ] 🇺🇸 English interface (auto-detected from your system)
- [ ] ⏱️ Focus timer (5 / 10 / 25 min or custom), as discreet as the player, sitting right above it
- [ ] 🍎 macOS version
- [ ] 🐧 Linux version
- [ ] ❤️ "Like" button (optional Spotify login)
- [ ] Code-signed releases

Have an idea? [Open an issue](https://github.com/solanosolutions/nook/issues/new/choose). Feature requests are very welcome.

## 🛠️ Build from source

Requires the [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) on Windows.

```powershell
git clone https://github.com/solanosolutions/nook.git
cd nook
dotnet run --project src -c Release                                    # run it
powershell -ExecutionPolicy Bypass -File tools\publish.ps1             # build the standalone Nook.exe
```

**How it works:** WPF/.NET 8. Playback info and controls come from Windows' [System Media Transport Controls](https://learn.microsoft.com/uwp/api/windows.media.control); the visualizer uses WASAPI *process loopback* to capture only Spotify's audio and a small FFT; volume uses Core Audio sessions. No third-party dependencies.

## 🤝 Contributing

Issues and pull requests are welcome! Bug reports with steps to reproduce (and `%AppData%\Nook\error.log`, if it exists) help a lot.

## ⭐ Like it?

If Nook made your day a little quieter, **[give it a star](https://github.com/solanosolutions/nook/stargazers)**. It's free, takes one click, and helps other people find it. 🙏

---

<div align="center">
<sub>Made with ☕ and 🎧 by <a href="https://github.com/solanosolutions">Lucas Solano</a> · MIT License<br>
Nook is an independent project and is not affiliated with, endorsed by, or sponsored by Spotify AB. Spotify is a trademark of Spotify AB.</sub>
</div>
