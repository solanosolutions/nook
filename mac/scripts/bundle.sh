#!/usr/bin/env bash
# Monta dist/Nook.app (universal: Apple Silicon + Intel) e dist/Nook-<versão>.dmg.
#
#   mac/scripts/bundle.sh [versão]
#
# Assinatura: se SIGN_IDENTITY estiver definido (ex.: "Developer ID Application: Nome (TEAMID)"),
# assina com hardened runtime; senão, assina ad-hoc (roda no Mac de quem compilou, mas o
# Gatekeeper bloqueia em outros Macs). Notarização: veja mac/README.md.
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${1:-$(sed -n 's:.*<Version>\(.*\)</Version>.*:\1:p' ../src/Nook.csproj)}"
BUILD="${BUILD_NUMBER:-1}"
OUT=dist
APP="$OUT/Nook.app"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Nook"

rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Nook"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Support/Info.plist > "$APP/Contents/Info.plist"

# Ícone a partir do PNG da versão Windows.
ICONSET="$OUT/Nook.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256; do
  sips -z $s $s ../src/Assets/nook.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d ../src/Assets/nook.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Nook.icns"
rm -rf "$ICONSET"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --entitlements Support/Nook.entitlements \
    --sign "$SIGN_IDENTITY" "$APP"
else
  codesign --force --sign - --entitlements Support/Nook.entitlements "$APP"
fi
codesign --verify --strict "$APP"

DMG="$OUT/Nook-$VERSION.dmg"
STAGE="$OUT/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Nook" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG"; fi

shasum -a 256 "$DMG"
echo "OK: $APP e $DMG"
