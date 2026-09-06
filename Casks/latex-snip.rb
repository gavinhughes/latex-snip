cask "latex-snip" do
  version "0.4.0"
  sha256 "b30bb8c991d27a852ad55789ecf63a31c9341a0841b99ba3da019b10f2c780d2"

  url "https://github.com/gavinhughes/latex-snip/releases/download/v#{version}/LaTeXSnip-#{version}.dmg"
  name "LaTeX Snip"
  desc "Menu-bar math screenshot to LaTeX via any OpenAI-compatible vision LLM"
  homepage "https://github.com/gavinhughes/latex-snip"

  depends_on macos: :sonoma

  app "LaTeX Snip.app"

  zap trash: [
    "~/.config/latex-snip",
  ]
end
