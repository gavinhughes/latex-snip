import AppKit
import SwiftUI
import Carbon

/// Click the field, then press the desired shortcut (e.g. ⌘⇧L).
struct HotkeyRecorder: NSViewRepresentable {
    @Binding var hotkey: AppConfig.Hotkey
    var onRecordingChange: ((Bool) -> Void)?
    /// Called with the new shortcut as soon as one is captured (before Save).
    var onCommit: ((AppConfig.Hotkey) -> Void)?

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.hotkey = hotkey
        view.onChange = { hotkey = $0 }
        view.onRecordingChange = onRecordingChange
        view.onCommit = onCommit
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.hotkey = hotkey
        nsView.onChange = { hotkey = $0 }
        nsView.onRecordingChange = onRecordingChange
        nsView.onCommit = onCommit
        nsView.refreshTitle()
    }

    final class RecorderView: NSView {
        var hotkey = AppConfig.Hotkey(
            enabled: true, keyEquivalent: "l",
            command: true, shift: true, option: false, control: false
        )
        var onChange: ((AppConfig.Hotkey) -> Void)?
        var onRecordingChange: ((Bool) -> Void)?
        var onCommit: ((AppConfig.Hotkey) -> Void)?

        private var recording = false
        private let button = NSButton()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            button.title = hotkey.summary
            button.bezelStyle = .rounded
            button.setButtonType(.momentaryPushIn)
            button.target = self
            button.action = #selector(beginRecording)
            button.translatesAutoresizingMaskIntoConstraints = false
            addSubview(button)
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: leadingAnchor),
                button.trailingAnchor.constraint(equalTo: trailingAnchor),
                button.topAnchor.constraint(equalTo: topAnchor),
                button.bottomAnchor.constraint(equalTo: bottomAnchor),
                heightAnchor.constraint(greaterThanOrEqualToConstant: 28)
            ])
        }

        required init?(coder: NSCoder) { fatalError("init(coder:)") }

        override var acceptsFirstResponder: Bool { true }

        func refreshTitle() {
            if !recording {
                button.title = hotkey.enabled ? hotkey.summary : "Disabled"
            }
        }

        @objc private func beginRecording() {
            recording = true
            onRecordingChange?(true)
            button.title = "Press shortcut…"
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            guard recording else {
                super.keyDown(with: event)
                return
            }
            if event.keyCode == UInt16(kVK_Escape) {
                endRecording(committed: nil)
                return
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let command = flags.contains(.command)
            let shift = flags.contains(.shift)
            let option = flags.contains(.option)
            let control = flags.contains(.control)

            guard let letter = Self.letter(forKeyCode: Int(event.keyCode)) else {
                NSSound.beep()
                return
            }
            guard command || shift || option || control else {
                NSSound.beep()
                return
            }

            var next = hotkey
            next.keyEquivalent = letter
            next.command = command
            next.shift = shift
            next.option = option
            next.control = control
            next.enabled = true
            hotkey = next
            onChange?(next)
            endRecording(committed: next)
        }

        override func resignFirstResponder() -> Bool {
            if recording { endRecording(committed: nil) }
            return super.resignFirstResponder()
        }

        private func endRecording(committed: AppConfig.Hotkey?) {
            recording = false
            if let committed {
                onCommit?(committed)
            }
            onRecordingChange?(false)
            refreshTitle()
            window?.makeFirstResponder(nil)
        }

        private static func letter(forKeyCode code: Int) -> String? {
            let map: [Int: String] = [
                kVK_ANSI_A: "a", kVK_ANSI_B: "b", kVK_ANSI_C: "c", kVK_ANSI_D: "d",
                kVK_ANSI_E: "e", kVK_ANSI_F: "f", kVK_ANSI_G: "g", kVK_ANSI_H: "h",
                kVK_ANSI_I: "i", kVK_ANSI_J: "j", kVK_ANSI_K: "k", kVK_ANSI_L: "l",
                kVK_ANSI_M: "m", kVK_ANSI_N: "n", kVK_ANSI_O: "o", kVK_ANSI_P: "p",
                kVK_ANSI_Q: "q", kVK_ANSI_R: "r", kVK_ANSI_S: "s", kVK_ANSI_T: "t",
                kVK_ANSI_U: "u", kVK_ANSI_V: "v", kVK_ANSI_W: "w", kVK_ANSI_X: "x",
                kVK_ANSI_Y: "y", kVK_ANSI_Z: "z"
            ]
            return map[code]
        }
    }
}
