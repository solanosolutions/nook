# Nook for macOS

Native macOS version of Nook (AppKit + SwiftUI, no third-party dependencies). Requires macOS 13 Ventura or later.

## Build

On a Mac with Xcode 15+ (or the Command Line Tools):

```sh
mac/scripts/bundle.sh          # version defaults to the one in src/Nook.csproj
open mac/dist/Nook.app
```

The output is `mac/dist/Nook.app` (universal: Apple Silicon + Intel) and `mac/dist/Nook-<version>.dmg`.
Every push that touches `mac/` also builds the `.dmg` on GitHub Actions (artifact `Nook-macOS`).

On first launch macOS asks for permission to let Nook control Spotify. If it was denied, enable it in
System Settings > Privacy & Security > Automation > Nook > Spotify.

## Signing and notarization

Without signing, the app runs on the Mac that built it, but Gatekeeper blocks it on other Macs. On macOS 15+ right-click > Open no longer bypasses this: users click Open Anyway in System Settings > Privacy & Security, or run `xattr -dr com.apple.quarantine /Applications/Nook.app`.
For public releases (Apple Developer Program):

```sh
SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" mac/scripts/bundle.sh 1.6.0
xcrun notarytool submit mac/dist/Nook-1.6.0.dmg --keychain-profile nook --wait
xcrun stapler staple mac/dist/Nook-1.6.0.dmg
```

## How it maps to the Windows version

| Windows (WPF) | macOS |
|---|---|
| SMTC media session | Spotify AppleScript + `com.spotify.client.PlaybackStateChanged` notification |
| Core Audio session volume | Spotify `sound volume` (AppleScript) |
| `SetWindowCompositionAttribute` blur | `NSVisualEffectView` behind the window |
| Tool window, topmost | Borderless `NSPanel`, floating level, all Spaces, no Dock icon |
| Tray icon | Menu bar item |
| Registry Run key | `SMAppService` (open at login) |
| `%AppData%\Nook\settings.json` | `~/Library/Application Support/Nook/settings.json` |

## Status

Done (phase 1): player with cover, title/artist, shuffle, previous, play/pause, next, repeat, progress with seek,
open Spotify, settings, hide button; hover glass with idle opacity; Frosted, Frozen and Liquid styles;
album-art accent color; drag with edge snapping; scroll for Spotify volume; menu bar item; settings panel;
hide when Spotify is closed or paused; open at login; English and Portuguese.

Next:
- Phase 2: vertical layout, collapsed mode, scrolling title, collapsible settings sections, hide in fullscreen.
- Phase 3: bars and waves visualizer (Spotify-only audio tap, macOS 14.2+), focus timer.
- Phase 4: signed and notarized `.dmg`, README and release.
