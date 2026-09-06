import AppKit
import SwiftUI

/// Menu-bar (LSUIElement) apps often can't show SwiftUI `Settings`.
/// Open a real NSWindow instead. Stay `.accessory` unless the user wants a Dock icon —
/// flipping to `.regular` just to show this window is what made the Dock icon appear.
enum SettingsWindow {
    private static var window: NSWindow?
    private static weak var controller: SnipController?
    /// Last *saved* Dock preference; used to revert a live preview on close.
    private static var savedShowDockIcon = false

    @MainActor
    static func show(controller: SnipController) {
        Self.controller = controller
        savedShowDockIcon = controller.config.showDockIcon

        if let window, window.isVisible {
            present(window)
            return
        }

        let view = SettingsView(controller: controller)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "LaTeX Snip Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 500, height: 720))
        window.minSize = NSSize(width: 480, height: 420)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = CloseDelegate.shared
        Self.window = window
        present(window)
    }

    /// Preview Dock visibility while Settings is open (Save persists it).
    @MainActor
    static func previewDockVisibility(_ showDockIcon: Bool) {
        ActivationPolicy.apply(showDockIcon: showDockIcon)
    }

    @MainActor
    static func commitDockVisibility(_ showDockIcon: Bool) {
        savedShowDockIcon = showDockIcon
        ActivationPolicy.apply(showDockIcon: showDockIcon)
    }

    @MainActor
    static func handleDidClose() {
        window = nil
        ActivationPolicy.apply(showDockIcon: savedShowDockIcon)
        // Recorder may have paused the hotkey; restore the saved shortcut.
        controller?.resumeHotkey()
        controller = nil
    }

    @MainActor
    private static func present(_ window: NSWindow) {
        ActivationPolicy.apply(showDockIcon: savedShowDockIcon)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
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
