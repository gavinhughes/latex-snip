import Foundation
import AppKit

@MainActor
final class SnipController: ObservableObject {
    @Published var status: String = "Ready"
    @Published var isBusy = false
    @Published var config: AppConfig
    @Published var lastError: String?
    @Published var accessibilityTrusted = false
    @Published var hotkeyRegistered = false

    private var hotkey: HotkeyMonitor?
    /// True while the Settings recorder has stopped the live hotkey.
    private var hotkeyPausedForRecording = false
    private var observers: [NSObjectProtocol] = []

    init() {
        self.config = (try? AppConfig.load()) ?? .default
        LoginItem.syncFromConfig(config.launchAtLogin)
        DispatchQueue.main.async { [weak self] in
            self?.applyDockVisibility()
            self?.installHotkey()
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyDockVisibility()
                self?.installHotkey()
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshHotkeyIfNeeded()
            }
        })
    }

    func applyConfig(_ newConfig: AppConfig) {
        config = newConfig
        applyDockVisibility()
        // Always re-register — Save is also how a newly granted Accessibility
        // permission takes effect, and recording may have paused the hotkey.
        installHotkey()
        status = "Settings saved"
    }

    func applyDockVisibility() {
        ActivationPolicy.apply(showDockIcon: config.showDockIcon)
    }

    func reloadConfig() {
        do {
            config = try AppConfig.load()
            applyDockVisibility()
            status = "Config reloaded"
            installHotkey()
        } catch {
            lastError = error.localizedDescription
            status = "Config error"
        }
    }

    func installHotkey(using override: AppConfig.Hotkey? = nil) {
        hotkeyPausedForRecording = false
        let hk = override ?? config.hotkey
        if let override {
            config.hotkey = override
        }
        hotkey?.stop()
        hotkey = HotkeyMonitor(config: hk) { [weak self] in
            Task { @MainActor in self?.snip() }
        }
        hotkey?.start()
        refreshHotkeyStatus()
        if hk.enabled, !hotkeyRegistered {
            status = "Hotkey not registered"
        } else if hk.enabled, hotkeyRegistered {
            status = "Hotkey \(hk.summary)"
        }
    }

    /// Persist + activate a newly recorded shortcut immediately.
    func adoptRecordedHotkey(_ hk: AppConfig.Hotkey) {
        config.hotkey = hk
        try? config.save()
        installHotkey(using: hk)
        status = "Hotkey \(hk.summary)"
    }

    func refreshHotkeyStatus() {
        accessibilityTrusted = HotkeyMonitor.ensureAccessibility(prompt: false)
        hotkeyRegistered = hotkey?.isActive ?? false
    }

    /// Re-register if the hotkey should be live but is not (e.g. returning
    /// from System Settings after granting Accessibility).
    func refreshHotkeyIfNeeded() {
        guard !hotkeyPausedForRecording else { return }
        let wasTrusted = accessibilityTrusted
        refreshHotkeyStatus()
        guard config.hotkey.enabled else { return }
        if !hotkeyRegistered || (!wasTrusted && accessibilityTrusted) {
            installHotkey()
        }
    }

    func pauseHotkey() {
        hotkeyPausedForRecording = true
        hotkey?.stop()
    }

    /// Reinstall the current config hotkey after recording ends or cancels.
    func resumeHotkey() {
        installHotkey()
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
