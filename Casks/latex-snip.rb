cask "latex-snip" do
  version "0.4.0"
  sha256 "b30bb8c991d27a852ad55789ecf63a31c9341a0841b99ba3da019b10f2c780d2"

  url "https://github.com/gavinhughes/latex-snip/releases/download/v#{version}/LaTeXSnip-#{version}.dmg"
  name "LaTeX Snip"
  desc "Menu-bar math screenshot to LaTeX via any OpenAI-compatible vision LLM"
  homepage "https://github.com/gavinhughes/latex-snip"

  depends_on macos: :sonoma

  app "LaTeX Snip.app"

  # Unsigned builds download with Gatekeeper quarantine; macOS then claims the
  # app is "damaged". Clear quarantine after install so it can launch.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/LaTeX Snip.app"]
  end

  caveats <<~EOS
    LaTeX Snip is not notarized yet. If macOS says the app is damaged after a
    manual DMG install, run:
      xattr -cr "/Applications/LaTeX Snip.app"
  EOS

  zap trash: [
    "~/.config/latex-snip",
  ]
end
