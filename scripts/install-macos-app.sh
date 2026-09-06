#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/LatexSnip"
APP="/Applications/LaTeX Snip.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/LaTeX Snip"
chmod +x "$APP/Contents/MacOS/LaTeX Snip"
cat > "$APP/Contents/Info.plist" <<'PLIST'
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
  <string>0.3.0</string>
  <key>CFBundleShortVersionString</key>
  <string>0.3.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>LaTeX Snip</string>
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
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
echo "Installed $APP"
