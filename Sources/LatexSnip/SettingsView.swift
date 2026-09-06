import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var controller: SnipController
    @State private var draft: AppConfig
    @State private var loginError: String?
    @State private var savedFlash = false

    init(controller: SnipController) {
        self.controller = controller
        _draft = State(initialValue: controller.config)
    }

    private let keys = Array("abcdefghijklmnopqrstuvwxyz").map(String.init)

    var body: some View {
        Form {
            Section("Hotkey") {
                Toggle("Enable global hotkey", isOn: $draft.hotkey.enabled)
                HStack {
                    Toggle("⌘", isOn: $draft.hotkey.command)
                    Toggle("⇧", isOn: $draft.hotkey.shift)
                    Toggle("⌥", isOn: $draft.hotkey.option)
                    Toggle("⌃", isOn: $draft.hotkey.control)
                }
                Picker("Key", selection: $draft.hotkey.keyEquivalent) {
                    ForEach(keys, id: \.self) { k in
                        Text(k.uppercased()).tag(k)
                    }
                }
                .frame(maxWidth: 120)
                Text("Current: \(draft.hotkey.summary)")
                    .foregroundStyle(.secondary)
                Button("Enable Accessibility…") {
                    HotkeyMonitor.ensureAccessibility(prompt: true)
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
        .frame(minWidth: 460, minHeight: 480)
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
