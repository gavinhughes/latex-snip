# LaTeX Snip

Native **macOS menu-bar** app: hotkey → region screenshot → OpenAI-compatible vision LLM → delimited LaTeX on the clipboard.

Lightweight Mathpix-style snip. Works with **OpenRouter**, **Ollama**, **LM Studio**, or any chat-completions endpoint that accepts images.

## Features

- Menu bar icon (SF Symbol `function`)
- Global hotkey (default `⌘⇧L`) via Carbon
- Two model slots (**Online** / **Offline**): enable either or both, pick which to try first, automatic fallback
- Configurable `base_url` / `model` / API key per slot
- Keys from env or Emacs `~/.authinfo` (offline usually needs none)
- Delimiter presets: `$…$`, `$$…$$`, `\(…\)`, `\[…\]`, or none

## Requirements

- macOS 14+
- Swift 5.9+ / Xcode CLT
- **Accessibility** permission (global hotkey)
- **Screen Recording** permission (`screencapture`)

## Install

### DMG (recommended)

Download the latest `.dmg` from [Releases](https://github.com/gavinhughes/latex-snip/releases), open it, drag **LaTeX Snip** to Applications.

The release build is not notarized yet. If macOS says the app is **damaged**, it is Gatekeeper quarantine — clear it with:

```bash
xattr -cr "/Applications/LaTeX Snip.app"
```

### Homebrew

Homebrew 6+ requires trusting a third-party tap before its casks load:

```bash
brew tap gavinhughes/latex-snip https://github.com/gavinhughes/latex-snip
brew trust gavinhughes/latex-snip
brew install --cask latex-snip
```

(Or from a checkout: `brew install --cask ./Casks/latex-snip.rb`.)

### From source

```bash
git clone https://github.com/gavinhughes/latex-snip.git
cd latex-snip
./scripts/install-macos-app.sh
open "/Applications/LaTeX Snip.app"
```

Build a DMG locally: `./scripts/package-dmg.sh` → `dist/LaTeXSnip-*.dmg`.

Then:

1. Menu bar **ƒ** → **Enable Accessibility…** and allow **LaTeX Snip**
   (macOS forgets this after a Homebrew reinstall — grant it again, then quit and reopen if the hotkey still does not fire)
2. Allow **Screen Recording** when prompted (or System Settings → Privacy)
3. Press `⌘⇧L` or **Snip formula**

## Settings

Menu bar **ƒ** → **Settings…** (or `⌘,`):

- Hotkey modifiers + key (and an Accessibility warning if the hotkey is blocked)
- Delimiter preset / ask before or after
- Launch at login
- Show Dock icon (off by default; menu-bar icon stays either way)
- Models: enable Online and/or Offline, **Try first** order, base URL + model per slot

Changes save to `~/.config/latex-snip/config.yaml`. A snip tries the preferred enabled slot, then the other if it is on and the first fails.

## Config

`~/.config/latex-snip/config.yaml`:

```yaml
models:
  order: [online, offline]   # try Online first; Offline is backup
  online:
    enabled: true
    base_url: https://openrouter.ai/api/v1
    model: google/gemini-2.5-flash
    api_key_env: OPENROUTER_API_KEY
  offline:
    enabled: false
    base_url: http://127.0.0.1:11434/v1
    model: llama3.2-vision

hotkey:
  enabled: true
  flags: [cmd, shift]
  key: l

delimiters:
  preset: display_dollar
  ask: none

notify: true
show_dock_icon: false
```

An older `llm:` block still loads as **Online** (enabled). Saving Settings rewrites the file as `models:`.

### Authinfo

```
machine openrouter.ai login apikey password sk-or-…
```

Lookup is per slot: `api_key` → `$api_key_env` / `$LATEX_SNIP_API_KEY` → `~/.authinfo` (when that slot has a key env or authinfo enabled). Offline defaults are keyless.

## License

MIT
