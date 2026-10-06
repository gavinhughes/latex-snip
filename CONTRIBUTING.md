# Contributing

PRs welcome. By contributing, you agree that your contributions are licensed under the [GNU AGPL v3.0 or later](LICENSE), the same license as the project.

## Dev

```bash
git clone https://github.com/gavinhughes/latex-snip.git
cd latex-snip
./scripts/fetch-model.sh          # built-in Texo model → Models/Texo (gitignored)
swift build
swift test
./scripts/create-signing-cert.sh   # once; keeps macOS permissions across rebuilds
./scripts/install-macos-app.sh
```

Layout:

- `Sources/LatexSnipCore`: pure logic (config, built-in Texo model, LLM client, LaTeX cleanup, delimiters, authinfo). No AppKit or SwiftUI.
- `Sources/LatexSnip`: the menu-bar app (UI, hotkey, capture, notifications).
- `Tests/LatexSnipCoreTests`: XCTest suite for the core. `Fixtures/` holds a few small snips that run through the real model; those tests are skipped locally if `Models/Texo` is missing, and required in CI.

CI (GitHub Actions, macOS) fetches the model (cached), then runs `swift build`, `swift test` and `swift build -c release` on every pull request and push to `main`.

To run a debug build against the model: `LATEX_SNIP_TEXO_DIR=$PWD/Models/Texo swift run`. The installed app reads it from `Contents/Resources/Texo`.

## Guidelines

- Keep the core small: capture → recognizer (built-in model, then LLM backups) → delimiters → clipboard.
- LLM access must stay OpenAI-compatible (`/chat/completions` + vision).
- To update the built-in model, change the revision and SHA-256 values in `scripts/fetch-model.sh` and the revision in `THIRD_PARTY_NOTICES.md`, then update the fixture expectations in `TexoTests.swift`.
- Do not commit API keys or personal `config.yaml`.
- Put testable logic in `LatexSnipCore` and add tests for it.
- Update README / CONTRIBUTING in the same PR when behaviour or setup changes.
- Prefer small, focused PRs.
