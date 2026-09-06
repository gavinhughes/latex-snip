#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?usage: release.sh 0.4.0}"
export VERSION
cd "$ROOT"
"$ROOT/scripts/package-dmg.sh"
DMG="$ROOT/dist/LaTeXSnip-${VERSION}.dmg"
SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
# Update cask sha
sed -i '' "s/version \".*\"/version \"${VERSION}\"/" "$ROOT/homebrew/Casks/latex-snip.rb"
sed -i '' "s/sha256 .*/sha256 \"${SHA}\"/" "$ROOT/homebrew/Casks/latex-snip.rb"
echo "Creating GitHub release v${VERSION}…"
gh release create "v${VERSION}" "$DMG" "$DMG.sha256" \
  --title "LaTeX Snip ${VERSION}" \
  --notes "macOS menu-bar math snip → LaTeX.

## Install
- **DMG:** open \`LaTeXSnip-${VERSION}.dmg\`, drag to Applications
- **Homebrew (after tap):** \`brew install --cask latex-snip\`

## First run
Grant Accessibility + Screen Recording; set hotkey in Settings.
"
echo "Release published. Cask sha256=${SHA}"
