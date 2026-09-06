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
        LoginItem.syncFromConfig(config.launchAtLogin)
        DispatchQueue.main.async { [weak self] in
            self?.installHotkey()
        }
    }

    func applyConfig(_ newConfig: AppConfig) {
        let hotkeyChanged = newConfig.hotkey != config.hotkey
        config = newConfig
        if hotkeyChanged {
            installHotkey()
        }
        status = "Settings saved"
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

    func pauseHotkey() {
        hotkey?.stop()
    }

    func resumeHotkeyIfUnchanged(_ draftHotkey: AppConfig.Hotkey) {
        // If user cancelled recording without Save, restore active hotkey
        if draftHotkey == config.hotkey {
            installHotkey()
        }
    }

    func setPreset(_ preset: DelimiterPreset) {
        config.delimiters.preset = preset
        let pair = Delimiters.resolve(preset: preset, open: nil, close: nil)
        config.delimiters.open = pair.0
        config.delimiters.close = pair.1
        try? config.save()
    }

    private func chooseDelimiterInteractively() -> (String, String)? {
        let options: [(String, DelimiterPreset)] = [
            ("$$ … $$", .displayDollar),
            ("$ … $", .inlineDollar),
            ("\\[ … \\]", .displayBracket),
            ("\\( … \\)", .inlineParen),
            ("none", .none)
        ]
        let alert = NSAlert()
        alert.messageText = "Delimiter"
        alert.informativeText = "Choose how to wrap the LaTeX."
        for (label, _) in options {
            alert.addButton(withTitle: label)
        }
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        let idx = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        guard idx >= 0, idx < options.count else { return nil }
        return Delimiters.resolve(preset: options[idx].1, open: nil, close: nil)
    }

    func snip() {
        guard !isBusy else { return }
        isBusy = true
        status = "Select region…"
        lastError = nil
        var cfg = config

        Task {
            if cfg.delimiters.ask == .before {
                guard let pair = chooseDelimiterInteractively() else {
                    status = "Cancelled"
                    isBusy = false
                    return
                }
                cfg.delimiters.open = pair.0
                cfg.delimiters.close = pair.1
            }

            let imageURL = await Task.detached(priority: .userInitiated) {
                Capture.selection()
            }.value

            guard let imageURL else {
                status = "Cancelled"
                isBusy = false
                return
            }
            defer { try? FileManager.default.removeItem(at: imageURL) }

            if cfg.delimiters.ask == .after {
                guard let pair = chooseDelimiterInteractively() else {
                    status = "Cancelled"
                    isBusy = false
                    return
                }
                cfg.delimiters.open = pair.0
                cfg.delimiters.close = pair.1
            }

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
