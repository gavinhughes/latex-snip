# Contributing

PRs welcome.

## Dev

```bash
git clone https://github.com/gavinhughes/latex-snip.git
cd latex-snip
swift build -c release
./scripts/install-macos-app.sh
```

## Guidelines

- Keep the core small: capture → LLM → delimiters → clipboard.
- LLM access must stay OpenAI-compatible (`/chat/completions` + vision).
- Do not commit API keys or personal `config.yaml`.
- Prefer small, focused PRs.
