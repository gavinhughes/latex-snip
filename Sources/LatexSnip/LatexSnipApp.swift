import SwiftUI
import AppKit
import ApplicationServices

@main
struct LatexSnipApp: App {
    @StateObject private var controller = SnipController()

    init() {
        // Hidden until SnipController applies `show_dock_icon` from config.
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

            Text("Hotkey \(controller.config.hotkey.summary)")
                .foregroundStyle(.secondary)
                .onAppear { controller.refreshHotkeyStatus() }
            if controller.config.hotkey.enabled && !controller.accessibilityTrusted {
                Text("Needs Accessibility permission")
                    .foregroundStyle(.orange)
            } else if controller.config.hotkey.enabled && !controller.hotkeyRegistered {
                Text("Hotkey not registered")
                    .foregroundStyle(.orange)
            }
            Text(controller.status)
                .foregroundStyle(.secondary)
            if let err = controller.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            Divider()

            Button("Settings…") {
                SettingsWindow.show(controller: controller)
            }

            Button("Enable Accessibility…") {
                HotkeyMonitor.ensureAccessibility(prompt: true)
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
                controller.installHotkey()
            }

            Button("Reload config") { controller.reloadConfig() }

            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "function")
        }
        .menuBarExtraStyle(.menu)
    }
}
