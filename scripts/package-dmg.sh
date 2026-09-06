#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-0.4.0}"
DIST="$ROOT/dist"
STAGE="$DIST/dmg-stage"
DMG="$DIST/LaTeXSnip-${VERSION}.dmg"
VOL="LaTeX Snip"

"$ROOT/scripts/install-macos-app.sh"
# Also stage a copy for the DMG (don't rely only on /Applications)
rm -rf "$DIST"
mkdir -p "$STAGE"
# Re-copy app from /Applications into stage
ditto "/Applications/LaTeX Snip.app" "$STAGE/LaTeX Snip.app"
ln -s /Applications "$STAGE/Applications"

# Temporary RW dmg then convert to UDZO
TMP_DMG="$DIST/temp.dmg"
rm -f "$TMP_DMG" "$DMG"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDRW "$TMP_DMG" >/dev/null
# Optional: set window layout skipped for simplicity/reliability
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$TMP_DMG"
rm -rf "$STAGE"

shasum -a 256 "$DMG" | tee "$DMG.sha256"
ls -lh "$DMG"
echo "DMG_OK=$DMG"
