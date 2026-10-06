#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="${VERSION:-0.4.0}"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/LatexSnip"
APP="/Applications/LaTeX Snip.app"
ICNS="$ROOT/Assets/AppIcon.icns"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/LaTeX Snip"
chmod +x "$APP/Contents/MacOS/LaTeX Snip"
if [[ -f "$ICNS" ]]; then
  cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>LaTeX Snip</string>
  <key>CFBundleDisplayName</key>
  <string>LaTeX Snip</string>
  <key>CFBundleIdentifier</key>
  <string>com.gavinhughes.latex-snip</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>LaTeX Snip</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSScreenCaptureUsageDescription</key>
  <string>LaTeX Snip captures a screen region to convert math into LaTeX.</string>
</dict>
</plist>
PLIST
echo -n 'APPL????' > "$APP/Contents/PkgInfo"
# Sign with a stable certificate so TCC (Screen Recording, Accessibility)
# grants survive rebuilds. Ad-hoc signatures are keyed to the binary's hash,
# so every rebuild looks like a new app and needs permissions granted again.
SIGN_IDENTITY="${SIGN_IDENTITY:-LaTeX Snip Local Signing}"
if security find-identity -p codesigning | grep -qF "\"$SIGN_IDENTITY\""; then
  codesign --force --deep --sign "$SIGN_IDENTITY" --identifier "com.gavinhughes.latex-snip" "$APP"
else
  echo "warning: signing identity '$SIGN_IDENTITY' not found; signing ad-hoc." >&2
  echo "warning: permissions will need re-granting after every rebuild." >&2
  codesign --force --deep --sign - --identifier "com.gavinhughes.latex-snip" "$APP"
fi
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
echo "Installed $APP ($VERSION)"
codesign -dv "$APP" 2>&1 | grep -E 'Identifier|Info.plist|Signature' || true
