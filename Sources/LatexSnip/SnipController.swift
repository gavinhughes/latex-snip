import Foundation
import AppKit

@MainActor
final class SnipController: ObservableObject {
    @Published var status: String = "Ready"
    @Published var isBusy = false
    @Published var config: AppConfig
    @Published var lastError: String?

    private var hotkey: HotkeyMonitor?

    init() {
        self.config = (try? AppConfig.load()) ?? .default
        // Defer hotkey until after AppKit is up
        DispatchQueue.main.async { [weak self] in
            self?.installHotkey()
        }
    }

    func reloadConfig() {
        do {
            config = try AppConfig.load()
            status = "Config reloaded"
            installHotkey()
        } catch {
            lastError = error.localizedDescription
            status = "Config error"
        }
    }

    func installHotkey() {
        hotkey?.stop()
        hotkey = HotkeyMonitor(config: config.hotkey) { [weak self] in
            Task { @MainActor in self?.snip() }
        }
        hotkey?.start()
    }

    func setPreset(_ preset: DelimiterPreset) {
        config.delimiters.preset = preset
        let pair = Delimiters.resolve(preset: preset, open: nil, close: nil)
        config.delimiters.open = pair.0
        config.delimiters.close = pair.1
    }

    func snip() {
        guard !isBusy else { return }
        isBusy = true
        status = "Select region…"
        lastError = nil
        let cfg = config

        Task {
            let imageURL = await Task.detached(priority: .userInitiated) {
                Capture.selection()
            }.value

            guard let imageURL else {
                status = "Cancelled"
                isBusy = false
                return
            }
            defer { try? FileManager.default.removeItem(at: imageURL) }

            status = "Recognizing…"
            do {
                let latex = try await LLMClient.recognize(imageURL: imageURL, config: cfg.llm)
                let out = Delimiters.wrap(latex, open: cfg.delimiters.open, close: cfg.delimiters.close)
                Notifier.copyToPasteboard(out)
                if cfg.notify {
                    let preview = out.count > 120 ? String(out.prefix(117)) + "…" : out
                    Notifier.post(title: "LaTeX Snip", body: preview)
                }
                status = "Copied"
            } catch {
                lastError = error.localizedDescription
                status = "Error"
                if cfg.notify {
                    Notifier.post(title: "LaTeX Snip error", body: error.localizedDescription)
                }
            }
            isBusy = false
        }
    }
}
