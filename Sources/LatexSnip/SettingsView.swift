import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var controller: SnipController
    @State private var draft: AppConfig
    @State private var loginError: String?
    @State private var savedFlash = false
    @State private var recordingHotkey = false

    init(controller: SnipController) {
        self.controller = controller
        _draft = State(initialValue: controller.config)
    }

    var body: some View {
        Form {
            Section("Hotkey") {
                Toggle("Enable global hotkey", isOn: $draft.hotkey.enabled)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Shortcut")
                    HotkeyRecorder(
                        hotkey: $draft.hotkey,
                        onRecordingChange: { recording in
                            if recording {
                                recordingHotkey = true
                                controller.pauseHotkey()
                            } else if recordingHotkey {
                                // Esc/cancel (no onCommit). Restore previous live hotkey.
                                recordingHotkey = false
                                controller.resumeHotkey()
                            }
                        },
                        onCommit: { hk in
                            recordingHotkey = false
                            draft.hotkey = hk
                            controller.adoptRecordedHotkey(hk)
                        }
                    )
                    .frame(maxWidth: 220)
                    Text("Click the box, then press the keys (e.g. ⌘⇧L). Esc cancels.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if controller.config.hotkey.enabled && !controller.hotkeyRegistered {
                    Text("Hotkey inactive: after each app update, turn LaTeX Snip OFF then ON in Accessibility, then click Retry.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                HStack {
                    Button("Open Accessibility Settings…") {
                        let urls = [
                            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?path=Privacy_Accessibility",
                            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                        ]
                        for s in urls {
                            if let url = URL(string: s), NSWorkspace.shared.open(url) { break }
                        }
                    }
                    Button("Retry hotkey") {
                        controller.installHotkey()
                    }
                }
            }

            Section("Delimiters") {
                Picker("Preset", selection: $draft.delimiters.preset) {
                    ForEach([
                        DelimiterPreset.displayDollar,
                        .inlineDollar,
                        .displayBracket,
                        .inlineParen,
                        .none,
                        .custom
                    ]) { p in
                        Text(p.label).tag(p)
                    }
                }
                if draft.delimiters.preset == .custom {
                    TextField("Open", text: $draft.delimiters.open)
                    TextField("Close", text: $draft.delimiters.close)
                }
                Picker("When to apply", selection: $draft.delimiters.ask) {
                    ForEach(AppConfig.AskMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $draft.launchAtLogin)
                Toggle("Show notification after snip", isOn: $draft.notify)
                Toggle("Show Dock icon", isOn: $draft.showDockIcon)
                    .onChange(of: draft.showDockIcon) { _, show in
                        SettingsWindow.previewDockVisibility(show)
                    }
                Text("Off by default. The menu-bar icon stays available either way.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let loginError {
                    Text(loginError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section("LLM") {
                TextField("Base URL", text: $draft.llm.baseURL)
                TextField("Model", text: $draft.llm.model)
                Text("API key from \(draft.llm.apiKeyEnv) or ~/.authinfo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                if savedFlash {
                    Text("Saved")
                        .foregroundStyle(.secondary)
                }
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 460, minHeight: 520)
        .onAppear {
            draft = controller.config
            draft.launchAtLogin = LoginItem.isEnabled || draft.launchAtLogin
            controller.refreshHotkeyStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            controller.refreshHotkeyIfNeeded()
        }
    }

    private func save() {
        loginError = nil
        let pair = Delimiters.resolve(
            preset: draft.delimiters.preset,
            open: draft.delimiters.open,
            close: draft.delimiters.close
        )
        if draft.delimiters.preset != .custom {
            draft.delimiters.open = pair.0
            draft.delimiters.close = pair.1
        }

        do {
            try draft.save()
        } catch {
            loginError = error.localizedDescription
            return
        }

        do {
            try LoginItem.setEnabled(draft.launchAtLogin)
        } catch {
            loginError = "Launch at login: \(error.localizedDescription). Keep the app in /Applications."
        }

        SettingsWindow.commitDockVisibility(draft.showDockIcon)
        controller.applyConfig(draft)
        savedFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { savedFlash = false }
    }
}
