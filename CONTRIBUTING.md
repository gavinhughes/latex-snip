# Contributing

PRs welcome. By contributing, you agree that your contributions are licensed under the [GNU AGPL v3.0 or later](LICENSE), the same license as the project.

## Dev

```bash
git clone https://github.com/gavinhughes/latex-snip.git
cd latex-snip
swift build
swift test
./scripts/create-signing-cert.sh   # once; keeps macOS permissions across rebuilds
./scripts/install-macos-app.sh
```

Layout:

- `Sources/LatexSnipCore`: pure logic (config, LLM client, delimiters, authinfo). No AppKit or SwiftUI.
- `Sources/LatexSnip`: the menu-bar app (UI, hotkey, capture, notifications).
- `Tests/LatexSnipCoreTests`: XCTest suite for the core.

CI (GitHub Actions, macOS) runs `swift build`, `swift test` and `swift build -c release` on every pull request and push to `main`.

## Guidelines

- Keep the core small: capture → LLM → delimiters → clipboard.
- LLM access must stay OpenAI-compatible (`/chat/completions` + vision).
- Do not commit API keys or personal `config.yaml`.
- Put testable logic in `LatexSnipCore` and add tests for it.
- Update README / CONTRIBUTING in the same PR when behaviour or setup changes.
- Prefer small, focused PRs.
