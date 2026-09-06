import AppKit

/// Runtime Dock visibility. `LSUIElement` starts the app as a menu-bar extra;
/// `setActivationPolicy` can still show or hide the Dock icon afterwards.
enum ActivationPolicy {
    @MainActor
    static func apply(showDockIcon: Bool) {
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }
}
