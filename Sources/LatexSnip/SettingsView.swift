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
                    HotkeyRecorder(hotkey: $draft.hotkey) { recording in
                        recordingHotkey = recording
                        if recording {
                            controller.pauseHotkey()
                        } else {
                            // stay paused until Save reapplies, or resume old
                            controller.resumeHotkeyIfUnchanged(draft.hotkey)
                        }
                    }
                    .frame(maxWidth: 220)
                    Text("Click the box, then press the keys (e.g. ⌘⇧L). Esc cancels.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Open Accessibility Settings…") {
                    // Open settings only — do not force the system prompt every time
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
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

        controller.applyConfig(draft)
        savedFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { savedFlash = false }
    }
}
