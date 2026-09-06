import AppKit
import ApplicationServices
import Carbon

/// Global hotkey: NSEvent monitor (needs Accessibility) + Carbon fallback.
final class HotkeyMonitor {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let onFire: () -> Void
    private let config: AppConfig.Hotkey
    private static let signature: OSType = 0x4C545853 // 'LTXS'

    init(config: AppConfig.Hotkey, onFire: @escaping () -> Void) {
        self.config = config
        self.onFire = onFire
    }

    @discardableResult
    static func ensureAccessibility(prompt: Bool) -> Bool {
        if AXIsProcessTrusted() { return true }
        if prompt {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
        }
        return AXIsProcessTrusted()
    }

    private(set) var isActive = false

    func start() {
        stop()
        guard config.enabled else { return }
        guard let keyCode = Self.keyCode(for: config.keyEquivalent) else {
            NSLog("latex-snip: unsupported hotkey letter %@", config.keyEquivalent)
            return
        }

        var flags: NSEvent.ModifierFlags = []
        if config.command { flags.insert(.command) }
        if config.shift { flags.insert(.shift) }
        if config.option { flags.insert(.option) }
        if config.control { flags.insert(.control) }
        let wanted = flags.intersection([.command, .shift, .option, .control])

        let match: (NSEvent) -> Bool = { event in
            guard event.type == .keyDown else { return false }
            let got = event.modifierFlags.intersection([.command, .shift, .option, .control])
            return event.keyCode == UInt16(keyCode) && got == wanted
        }

        let ax = Self.ensureAccessibility(prompt: false)
        let logPath = "/tmp/latex-snip-hotkey.log"
        let logLine = "ax=\(ax) key=\(config.keyEquivalent) cmd=\(config.command) shift=\(config.shift) opt=\(config.option) ctrl=\(config.control)\n"
        if let data = logLine.data(using: .utf8) {
            if let fh = FileHandle(forWritingAtPath: logPath) {
                fh.seekToEndOfFile(); fh.write(data); try? fh.close()
            } else {
                try? data.write(to: URL(fileURLWithPath: logPath))
            }
        }

        // Local monitor works when our app is focused (Settings, etc.) without AX.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, match(event) else { return event }
            DispatchQueue.main.async { self.onFire() }
            return nil
        }

        // Always install the global monitor. Without Accessibility, macOS creates it
        // but does not deliver events — AXIsProcessTrusted must be true for this app
        // binary (re-toggle after every rebuild/re-sign).
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, match(event) else { return }
            DispatchQueue.main.async { self.onFire() }
        }
        NSLog("latex-snip: globalMonitor=%@ ax=%d", String(describing: globalMonitor != nil), ax ? 1 : 0)

        startCarbon(keyCode: keyCode)
        // Consider registered only when AX is trusted AND monitor exists.
        isActive = ax && (globalMonitor != nil)
    }

    private func startCarbon(keyCode: UInt32) {
        var modifiers: UInt32 = 0
        if config.command { modifiers |= UInt32(cmdKey) }
        if config.shift { modifiers |= UInt32(shiftKey) }
        if config.option { modifiers |= UInt32(optionKey) }
        if config.control { modifiers |= UInt32(controlKey) }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        var handlerSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData else { return noErr }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userData).takeUnretainedValue()
                var hk = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hk
                )
                if hk.signature == HotkeyMonitor.signature {
                    DispatchQueue.main.async { monitor.onFire() }
                }
                return noErr
            },
            1,
            &handlerSpec,
            userData,
            &handlerRef
        )
        if status != noErr {
            NSLog("latex-snip: InstallEventHandler failed: %d", status)
            return
        }
        let reg = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if reg != noErr {
            NSLog("latex-snip: RegisterEventHotKey failed: %d", reg)
            hotKeyRef = nil
        } else {
            NSLog("latex-snip: Carbon hotkey registered")
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = handlerRef {
            RemoveEventHandler(handler)
            handlerRef = nil
        }
        isActive = false
    }

    private static func keyCode(for letter: String) -> UInt32? {
        switch letter.lowercased() {
        case "a": return UInt32(kVK_ANSI_A)
        case "b": return UInt32(kVK_ANSI_B)
        case "c": return UInt32(kVK_ANSI_C)
        case "d": return UInt32(kVK_ANSI_D)
        case "e": return UInt32(kVK_ANSI_E)
        case "f": return UInt32(kVK_ANSI_F)
        case "g": return UInt32(kVK_ANSI_G)
        case "h": return UInt32(kVK_ANSI_H)
        case "i": return UInt32(kVK_ANSI_I)
        case "j": return UInt32(kVK_ANSI_J)
        case "k": return UInt32(kVK_ANSI_K)
        case "l": return UInt32(kVK_ANSI_L)
        case "m": return UInt32(kVK_ANSI_M)
        case "n": return UInt32(kVK_ANSI_N)
        case "o": return UInt32(kVK_ANSI_O)
        case "p": return UInt32(kVK_ANSI_P)
        case "q": return UInt32(kVK_ANSI_Q)
        case "r": return UInt32(kVK_ANSI_R)
        case "s": return UInt32(kVK_ANSI_S)
        case "t": return UInt32(kVK_ANSI_T)
        case "u": return UInt32(kVK_ANSI_U)
        case "v": return UInt32(kVK_ANSI_V)
        case "w": return UInt32(kVK_ANSI_W)
        case "x": return UInt32(kVK_ANSI_X)
        case "y": return UInt32(kVK_ANSI_Y)
        case "z": return UInt32(kVK_ANSI_Z)
        default: return nil
        }
    }

    deinit { stop() }
}
