import SwiftUI
import AppKit

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

            if controller.config.hotkey.enabled && !controller.hotkeyRegistered {
                Button("Hotkey needs Accessibility — open Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                    controller.installHotkey()
                }
            }
            Button(controller.status) {
                controller.refreshHotkeyStatus()
            }

            Divider()

            Button("Settings…") {
                SettingsWindow.show(controller: controller)
            }

            Button("Open Accessibility Settings…") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
                controller.installHotkey()
            }

            Button("Reload config") { controller.reloadConfig() }

            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        } label: {
            // Put shortcut in the status-item label so it isn't a dimmed menu Text row.
            if controller.config.hotkey.enabled {
                Label(controller.config.hotkey.summary, systemImage: "function")
            } else {
                Image(systemName: "function")
            }
        }.menuBarExtraStyle(.menu)
    }
}
