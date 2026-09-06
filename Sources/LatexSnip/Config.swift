import Foundation
import Yams

struct AppConfig: Equatable {
    enum ModelSlotID: String, Equatable, CaseIterable, Identifiable {
        case online
        case offline

        var id: String { rawValue }

        /// Lowercase id for status text, e.g. "Copied (offline)".
        var label: String { rawValue }

        var displayName: String {
            switch self {
            case .online: return "Online"
            case .offline: return "Offline"
            }
        }
    }

    struct LLM: Equatable {
        var baseURL: String
        var model: String
        var apiKey: String?
        var apiKeyEnv: String
        var authinfoEnabled: Bool
        var authinfoMachine: String?
        var authinfoLogin: String
        var timeout: TimeInterval
        var temperature: Double
        var systemPrompt: String

        static let defaultSystemPrompt =
            "You convert images of mathematical expressions into LaTeX. Return ONLY the LaTeX for the expression(s). Do not wrap in markdown fences. Do not add $ \\( \\[ delimiters. Do not explain."

        static var onlineDefault: LLM {
            .init(
                baseURL: "https://openrouter.ai/api/v1",
                model: "google/gemini-2.5-flash",
                apiKey: nil,
                apiKeyEnv: "OPENROUTER_API_KEY",
                authinfoEnabled: true,
                authinfoMachine: nil,
                authinfoLogin: "apikey",
                timeout: 120,
                temperature: 0,
                systemPrompt: defaultSystemPrompt
            )
        }

        /// Local OpenAI-compatible default (Ollama). Disabled until the user opts in.
        static var offlineDefault: LLM {
            .init(
                baseURL: "http://127.0.0.1:11434/v1",
                model: "llama3.2-vision",
                apiKey: nil,
                apiKeyEnv: "",
                authinfoEnabled: false,
                authinfoMachine: nil,
                authinfoLogin: "apikey",
                timeout: 120,
                temperature: 0,
                systemPrompt: defaultSystemPrompt
            )
        }
    }

    struct ModelSlot: Equatable {
        var enabled: Bool
        var llm: LLM
    }

    struct Models: Equatable {
        var online: ModelSlot
        var offline: ModelSlot
        /// Which slot to try first; the other enabled slot is backup.
        var preferred: ModelSlotID

        static var `default`: Models {
            Models(
                online: ModelSlot(enabled: true, llm: .onlineDefault),
                offline: ModelSlot(enabled: false, llm: .offlineDefault),
                preferred: .online
            )
        }

        var order: [ModelSlotID] {
            preferred == .online ? [.online, .offline] : [.offline, .online]
        }

        var anyEnabled: Bool {
            online.enabled || offline.enabled
        }

        func enabledInOrder() -> [(id: ModelSlotID, llm: LLM)] {
            order.compactMap { id in
                let slot = self[id]
                guard slot.enabled else { return nil }
                return (id, slot.llm)
            }
        }

        subscript(id: ModelSlotID) -> ModelSlot {
            get {
                switch id {
                case .online: return online
                case .offline: return offline
                }
            }
            set {
                switch id {
                case .online: online = newValue
                case .offline: offline = newValue
                }
            }
        }
    }

    struct Hotkey: Equatable {
        var enabled: Bool
        var keyEquivalent: String
        var command: Bool
        var shift: Bool
        var option: Bool
        var control: Bool

        var summary: String {
            var parts: [String] = []
            if control { parts.append("⌃") }
            if option { parts.append("⌥") }
            if shift { parts.append("⇧") }
            if command { parts.append("⌘") }
            parts.append(keyEquivalent.uppercased())
            return parts.joined()
        }

        var flags: [String] {
            var f: [String] = []
            if command { f.append("cmd") }
            if shift { f.append("shift") }
            if option { f.append("option") }
            if control { f.append("ctrl") }
            return f
        }
    }

    struct DelimiterSettings: Equatable {
        var preset: DelimiterPreset
        var open: String
        var close: String
        var ask: AskMode
    }

    enum AskMode: String, Equatable, CaseIterable, Identifiable {
        case none, before, after
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none: return "Always use preset"
            case .before: return "Ask before capture"
            case .after: return "Ask after capture"
            }
        }
    }

    var models: Models
    var hotkey: Hotkey
    var delimiters: DelimiterSettings
    var notify: Bool
    var launchAtLogin: Bool
    /// When false (default), stay a menu-bar extra with no Dock icon.
    var showDockIcon: Bool

    static var configDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/latex-snip")
    }

    static var configURL: URL { configDir.appendingPathComponent("config.yaml") }

    static var `default`: AppConfig {
        AppConfig(
            models: .default,
            hotkey: .init(
                enabled: true,
                keyEquivalent: "l",
                command: true,
                shift: true,
                option: false,
                control: false
            ),
            delimiters: .init(
                preset: .displayDollar,
                open: "$$",
                close: "$$",
                ask: .none
            ),
            notify: true,
            launchAtLogin: false,
            showDockIcon: false
        )
    }

    static func load(from url: URL = configURL) throws -> AppConfig {
        var cfg = AppConfig.default
        if FileManager.default.fileExists(atPath: url.path) {
            let text = try String(contentsOf: url, encoding: .utf8)
            if let root = try Yams.load(yaml: text) as? [String: Any] {
                cfg = cfg.merging(yaml: root)
            }
        }
        cfg.resolveAPIKeys()
        let pair = Delimiters.resolve(
            preset: cfg.delimiters.preset,
            open: cfg.delimiters.open,
            close: cfg.delimiters.close
        )
        cfg.delimiters.open = pair.0
        cfg.delimiters.close = pair.1
        return cfg
    }

    func save(to url: URL = configURL) throws {
        try FileManager.default.createDirectory(at: AppConfig.configDir, withIntermediateDirectories: true)
        var root: [String: Any] = [:]
        root["models"] = [
            "order": models.order.map(\.rawValue),
            "online": slotYAML(models.online),
            "offline": slotYAML(models.offline)
        ] as [String: Any]
        root["hotkey"] = [
            "enabled": hotkey.enabled,
            "flags": hotkey.flags,
            "key": hotkey.keyEquivalent
        ] as [String: Any]
        root["delimiters"] = [
            "preset": delimiters.preset.rawValue,
            "open": delimiters.open,
            "close": delimiters.close,
            "ask": delimiters.ask.rawValue
        ] as [String: Any]
        root["notify"] = notify
        root["launch_at_login"] = launchAtLogin
        root["show_dock_icon"] = showDockIcon

        let yaml = try Yams.dump(object: root)
        try yaml.write(to: url, atomically: true, encoding: .utf8)
    }

    mutating func resolveAPIKeys() {
        Self.resolveAPIKey(into: &models.online.llm)
        Self.resolveAPIKey(into: &models.offline.llm)
    }

    /// Per-slot key lookup. Offline defaults have an empty `apiKeyEnv` and
    /// authinfo off, so they stay keyless (local Ollama/LM Studio).
    static func resolveAPIKey(into llm: inout LLM) {
        if let k = llm.apiKey, !k.isEmpty { return }
        let env = ProcessInfo.processInfo.environment
        if !llm.apiKeyEnv.isEmpty {
            if let v = env[llm.apiKeyEnv], !v.isEmpty {
                llm.apiKey = v
                return
            }
            if let v = env["LATEX_SNIP_API_KEY"], !v.isEmpty {
                llm.apiKey = v
                return
            }
        }
        guard llm.authinfoEnabled else { return }
        llm.apiKey = AuthInfo.lookupPassword(
            machine: llm.authinfoMachine,
            login: llm.authinfoLogin,
            baseURL: llm.baseURL
        )
    }

    private func slotYAML(_ slot: ModelSlot) -> [String: Any] {
        var d: [String: Any] = [
            "enabled": slot.enabled,
            "base_url": slot.llm.baseURL,
            "model": slot.llm.model,
            "timeout_s": Int(slot.llm.timeout),
            "temperature": slot.llm.temperature
        ]
        // Don't write api_key into yaml.
        if !slot.llm.apiKeyEnv.isEmpty {
            d["api_key_env"] = slot.llm.apiKeyEnv
        }
        return d
    }

    private func merging(yaml root: [String: Any]) -> AppConfig {
        var c = self
        if let models = root["models"] as? [String: Any] {
            if let online = models["online"] as? [String: Any] {
                Self.mergeSlot(&c.models.online, yaml: online)
            }
            if let offline = models["offline"] as? [String: Any] {
                Self.mergeSlot(&c.models.offline, yaml: offline)
            }
            if let first = Self.firstSlot(inOrder: models["order"]) {
                c.models.preferred = first
            } else if let pref = models["preferred"] as? String,
                      let id = ModelSlotID(rawValue: pref) {
                c.models.preferred = id
            }
        } else if let llm = root["llm"] as? [String: Any] {
            // Legacy single `llm:` block → Online, enabled.
            c.models.online.enabled = true
            Self.mergeLLM(&c.models.online.llm, yaml: llm)
        }
        if let hk = root["hotkey"] as? [String: Any] {
            if let v = hk["enabled"] as? Bool { c.hotkey.enabled = v }
            if let v = hk["key"] as? String { c.hotkey.keyEquivalent = v.lowercased() }
            if let flags = hk["flags"] as? [String] {
                let set = Set(flags.map { $0.lowercased() })
                c.hotkey.command = set.contains("cmd") || set.contains("command")
                c.hotkey.shift = set.contains("shift")
                c.hotkey.option = set.contains("alt") || set.contains("option")
                c.hotkey.control = set.contains("ctrl") || set.contains("control")
            }
        }
        if let d = root["delimiters"] as? [String: Any] {
            if let p = d["preset"] as? String, let preset = DelimiterPreset(rawValue: p) {
                c.delimiters.preset = preset
            }
            if let v = d["open"] as? String { c.delimiters.open = v }
            if let v = d["close"] as? String { c.delimiters.close = v }
            if let a = d["ask"] as? String, let mode = AskMode(rawValue: a) {
                c.delimiters.ask = mode
            }
        }
        if let n = root["notify"] as? Bool { c.notify = n }
        if let l = root["launch_at_login"] as? Bool { c.launchAtLogin = l }
        if let d = root["show_dock_icon"] as? Bool { c.showDockIcon = d }
        return c
    }

    private static func firstSlot(inOrder value: Any?) -> ModelSlotID? {
        if let order = value as? [String] {
            return order.compactMap(ModelSlotID.init(rawValue:)).first
        }
        if let order = value as? [Any] {
            return order.compactMap { $0 as? String }.compactMap(ModelSlotID.init(rawValue:)).first
        }
        return nil
    }

    private static func mergeSlot(_ slot: inout ModelSlot, yaml: [String: Any]) {
        if let v = yaml["enabled"] as? Bool { slot.enabled = v }
        mergeLLM(&slot.llm, yaml: yaml)
    }

    private static func mergeLLM(_ llm: inout LLM, yaml: [String: Any]) {
        if let v = yaml["base_url"] as? String { llm.baseURL = v }
        if let v = yaml["model"] as? String { llm.model = v }
        if let v = yaml["api_key"] as? String { llm.apiKey = v }
        if let v = yaml["api_key_env"] as? String { llm.apiKeyEnv = v }
        if let v = yaml["timeout_s"] as? Int { llm.timeout = TimeInterval(v) }
        if let v = yaml["timeout_s"] as? Double { llm.timeout = v }
        if let v = yaml["temperature"] as? Double { llm.temperature = v }
        if let v = yaml["temperature"] as? Int { llm.temperature = Double(v) }
        if let v = yaml["system_prompt"] as? String { llm.systemPrompt = v }
        if let auth = yaml["authinfo"] as? Bool {
            llm.authinfoEnabled = auth
        } else if let auth = yaml["authinfo"] as? [String: Any] {
            llm.authinfoEnabled = true
            if let m = auth["machine"] as? String { llm.authinfoMachine = m }
            if let l = auth["login"] as? String { llm.authinfoLogin = l }
        }
    }
}
