import AppKit
import SwiftUI

/// Menu-bar (LSUIElement) apps often can't show SwiftUI `Settings`.
/// Open a real NSWindow instead and briefly activate the app.
enum SettingsWindow {
    private static var window: NSWindow?

    @MainActor
    static func show(controller: SnipController) {
        if let window, window.isVisible {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let view = SettingsView(controller: controller)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "LaTeX Snip Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 480, height: 560))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = CloseDelegate.shared
        Self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @MainActor
    static func handleDidClose() {
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }

    private final class CloseDelegate: NSObject, NSWindowDelegate {
        static let shared = CloseDelegate()
        func windowWillClose(_ notification: Notification) {
            Task { @MainActor in
                SettingsWindow.handleDidClose()
            }
        }
    }
}
