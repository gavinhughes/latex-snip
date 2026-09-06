import SwiftUI
import AppKit
import ApplicationServices

@main
struct LatexSnipApp: App {
    @StateObject private var controller = SnipController()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        Notifier.requestPermission()
    }

    var body: some Scene {
        MenuBarExtra {
            Button(controller.isBusy ? "Working…" : "Snip formula") {
                controller.snip()
            }
            .disabled(controller.isBusy)

            Menu("Delimiter") {
                ForEach([
                    DelimiterPreset.displayDollar,
                    .inlineDollar,
                    .displayBracket,
                    .inlineParen,
                    .none
                ]) { preset in
                    Button {
                        controller.setPreset(preset)
                    } label: {
                        HStack {
                            Text(preset.label)
                            if controller.config.delimiters.preset == preset {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            Text(controller.status)
                .foregroundStyle(.secondary)
            if let err = controller.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            Divider()

            Button("Enable Accessibility…") {
                HotkeyMonitor.ensureAccessibility(prompt: true)
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
                controller.installHotkey()
            }

            Button("Reload config") { controller.reloadConfig() }
            Button("Open config folder") {
                let dir = AppConfig.configDir
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                NSWorkspace.shared.open(dir)
            }

            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "function")
        }
        .menuBarExtraStyle(.menu)
    }
}
