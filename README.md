# LaTeX Snip

Native **macOS menu-bar** app: hotkey → region screenshot → OpenAI-compatible vision LLM → delimited LaTeX on the clipboard.

Lightweight Mathpix-style snip. Works with **OpenRouter**, **Ollama**, **LM Studio**, or any chat-completions endpoint that accepts images.

## Features

- Menu bar icon (SF Symbol `function`)
- Global hotkey (default `⌘⇧L`) via Carbon
- Configurable `base_url` / `model` / API key
- Keys from env or Emacs `~/.authinfo`
- Delimiter presets: `$…$`, `$$…$$`, `\(…\)`, `\[…\]`, or none

## Requirements

- macOS 14+
- Swift 5.9+ / Xcode CLT
- **Accessibility** permission (global hotkey)
- **Screen Recording** permission (`screencapture`)

## Install

```bash
git clone https://github.com/gavinhughes/latex-snip.git
cd latex-snip
swift build -c release
./scripts/install-macos-app.sh
open "/Applications/LaTeX Snip.app"
```

Then:

1. Menu bar **ƒ** → **Enable Accessibility…** and allow **LaTeX Snip**
2. Allow **Screen Recording** when prompted (or System Settings → Privacy)
3. Press `⌘⇧L` or **Snip formula**

## Settings

Menu bar **ƒ** → **Settings…** (or `⌘,`):

- Hotkey modifiers + key
- Delimiter preset / ask before or after
- Launch at login
- LLM base URL + model

Changes save to `~/.config/latex-snip/config.yaml`.

## Config


`~/.config/latex-snip/config.yaml`:

```yaml
llm:
  base_url: https://openrouter.ai/api/v1
  model: google/gemini-2.5-flash
  api_key_env: OPENROUTER_API_KEY

hotkey:
  enabled: true
  flags: [cmd, shift]
  key: l

delimiters:
  preset: display_dollar
  ask: none

notify: true
```

### Authinfo

```
machine openrouter.ai login apikey password sk-or-…
```

Lookup order: `llm.api_key` → `$OPENROUTER_API_KEY` / `$LATEX_SNIP_API_KEY` → `~/.authinfo`.

## License

MIT
