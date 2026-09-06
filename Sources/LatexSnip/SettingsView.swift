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

            Section("Models") {
                Picker("Try first", selection: $draft.models.preferred) {
                    Text("Online").tag(AppConfig.ModelSlotID.online)
                    Text("Offline").tag(AppConfig.ModelSlotID.offline)
                }
                .pickerStyle(.segmented)
                Text(tryFirstCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !draft.models.anyEnabled {
                    Text("Enable at least one model to snip.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Toggle("Enabled", isOn: $draft.models.online.enabled)
                TextField("Base URL", text: $draft.models.online.llm.baseURL)
                TextField("Model", text: $draft.models.online.llm.model)
                Text(onlineNotes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Online")
            }

            Section {
                Toggle("Enabled", isOn: $draft.models.offline.enabled)
                TextField("Base URL", text: $draft.models.offline.llm.baseURL)
                TextField("Model", text: $draft.models.offline.llm.model)
                Text("Local OpenAI-compatible server (Ollama, LM Studio). Usually no API key.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Offline")
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
        .frame(minWidth: 480, minHeight: 400)
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

    private var tryFirstCaption: String {
        let online = draft.models.online.enabled
        let offline = draft.models.offline.enabled
        switch (online, offline) {
        case (true, true):
            let first = draft.models.preferred.displayName
            let second = draft.models.preferred == .online ? "Offline" : "Online"
            return "Snip uses \(first) first, then \(second) if that fails."
        case (true, false):
            return "Only Online is on. Turn on Offline to use it as backup."
        case (false, true):
            return "Only Offline is on. Turn on Online to use it as backup."
        default:
            return "Turn on Online, Offline, or both."
        }
    }

    private var onlineNotes: String {
        let env = draft.models.online.llm.apiKeyEnv
        if env.isEmpty {
            return "Cloud / remote OpenAI-compatible API. Key from ~/.authinfo or $LATEX_SNIP_API_KEY."
        }
        return "Cloud / remote OpenAI-compatible API. Key from $\(env) or ~/.authinfo."
    }
}
