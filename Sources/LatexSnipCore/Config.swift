import Foundation
import Yams

public struct AppConfig: Equatable, Codable {
    public enum ModelSlotID: String, Equatable, CaseIterable, Identifiable, Codable {
        case online
        case offline

        public var id: String { rawValue }

        /// Lowercase id for status text, e.g. "Copied (offline)".
        public var label: String { rawValue }

        public var displayName: String {
            switch self {
            case .online: return "Online"
            case .offline: return "Offline"
            }
        }
    }

    public struct LLM: Equatable, Encodable {
        public var baseURL: String
        public var model: String
        /// Only a key written explicitly in config.yaml. Keys from the
        /// environment or ~/.authinfo are resolved per request by LLMClient
        /// and never stored here.
        public var apiKey: String?
        public var apiKeyEnv: String
        public var authinfoEnabled: Bool
        public var authinfoMachine: String?
        public var authinfoLogin: String
        public var timeout: TimeInterval
        public var temperature: Double
        public var systemPrompt: String

        public static let defaultSystemPrompt =
            "You convert images of mathematical expressions into LaTeX. Return ONLY the LaTeX for the expression(s). Do not wrap in markdown fences. Do not add $ \\( \\[ delimiters. Do not explain."

        public static var onlineDefault: LLM {
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
        public static var offlineDefault: LLM {
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

        public init(
            baseURL: String,
            model: String,
            apiKey: String?,
            apiKeyEnv: String,
            authinfoEnabled: Bool,
            authinfoMachine: String?,
            authinfoLogin: String,
            timeout: TimeInterval,
            temperature: Double,
            systemPrompt: String
        ) {
            self.baseURL = baseURL
            self.model = model
            self.apiKey = apiKey
            self.apiKeyEnv = apiKeyEnv
            self.authinfoEnabled = authinfoEnabled
            self.authinfoMachine = authinfoMachine
            self.authinfoLogin = authinfoLogin
            self.timeout = timeout
            self.temperature = temperature
            self.systemPrompt = systemPrompt
        }

        /// Called when Settings changes the base URL. An explicit key, an env
        /// var name, or an authinfo machine override all belong to the old
        /// host; keeping them would send that host's key to the new one.
        /// After this, the key comes only from ~/.authinfo for the new host.
        public mutating func dropHostBoundCredentials(ifHostChangedFrom oldBaseURL: String) {
            func host(_ s: String) -> String? { URL(string: s)?.host?.lowercased() }
            let unchanged = host(oldBaseURL).map { $0 == host(baseURL) } ?? (oldBaseURL == baseURL)
            guard !unchanged else { return }
            apiKey = nil
            apiKeyEnv = ""
            authinfoMachine = nil
        }

        enum CodingKeys: String, CodingKey {
            case baseURL = "base_url"
            case model
            case apiKey = "api_key"
            case apiKeyEnv = "api_key_env"
            case authinfo
            case timeout = "timeout_s"
            case temperature
            case systemPrompt = "system_prompt"
        }

        /// `authinfo:` is either a bool or `{machine, login}`.
        struct AuthInfoBlock: Codable {
            var machine: String?
            var login: String?
        }

        /// Keys missing from YAML keep the values in `defaults`.
        init(from decoder: Decoder, defaults d: LLM) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            baseURL = try c.decodeIfPresent(String.self, forKey: .baseURL) ?? d.baseURL
            model = try c.decodeIfPresent(String.self, forKey: .model) ?? d.model
            apiKey = try c.decodeIfPresent(String.self, forKey: .apiKey) ?? d.apiKey
            apiKeyEnv = try c.decodeIfPresent(String.self, forKey: .apiKeyEnv) ?? d.apiKeyEnv
            timeout = try c.decodeIfPresent(Double.self, forKey: .timeout) ?? d.timeout
            temperature = try c.decodeIfPresent(Double.self, forKey: .temperature) ?? d.temperature
            systemPrompt = try c.decodeIfPresent(String.self, forKey: .systemPrompt) ?? d.systemPrompt
            authinfoEnabled = d.authinfoEnabled
            authinfoMachine = d.authinfoMachine
            authinfoLogin = d.authinfoLogin
            if c.contains(.authinfo) {
                if let flag = try? c.decode(Bool.self, forKey: .authinfo) {
                    authinfoEnabled = flag
                } else {
                    let block = try c.decode(AuthInfoBlock.self, forKey: .authinfo)
                    authinfoEnabled = true
                    authinfoMachine = block.machine ?? authinfoMachine
                    authinfoLogin = block.login ?? authinfoLogin
                }
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(baseURL, forKey: .baseURL)
            try c.encode(model, forKey: .model)
            try c.encodeIfPresent(apiKey, forKey: .apiKey)
            // Always written, even when empty, so "" survives a round trip
            // instead of reverting to the slot default.
            try c.encode(apiKeyEnv, forKey: .apiKeyEnv)
            if !authinfoEnabled {
                try c.encode(false, forKey: .authinfo)
            } else if authinfoMachine == nil && authinfoLogin == "apikey" {
                try c.encode(true, forKey: .authinfo)
            } else {
                try c.encode(AuthInfoBlock(machine: authinfoMachine, login: authinfoLogin), forKey: .authinfo)
            }
            if timeout == timeout.rounded() {
                try c.encode(Int(timeout), forKey: .timeout)
            } else {
                try c.encode(timeout, forKey: .timeout)
            }
            try c.encode(temperature, forKey: .temperature)
            // Only a custom prompt is written, so users keep getting
            // improvements to the built-in one.
            if systemPrompt != LLM.defaultSystemPrompt {
                try c.encode(systemPrompt, forKey: .systemPrompt)
            }
        }
    }

    public struct ModelSlot: Equatable, Encodable {
        public var enabled: Bool
        public var llm: LLM

        public init(enabled: Bool, llm: LLM) {
            self.enabled = enabled
            self.llm = llm
        }

        enum CodingKeys: String, CodingKey {
            case enabled
        }

        init(from decoder: Decoder, defaults d: ModelSlot) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? d.enabled
            llm = try LLM(from: decoder, defaults: d.llm)
        }

        /// Flat: `enabled` sits beside the LLM keys.
        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(enabled, forKey: .enabled)
            try llm.encode(to: encoder)
        }
    }

    public struct Models: Equatable, Codable {
        public var online: ModelSlot
        public var offline: ModelSlot
        /// Which slot to try first; the other enabled slot is backup.
        public var preferred: ModelSlotID

        public init(online: ModelSlot, offline: ModelSlot, preferred: ModelSlotID) {
            self.online = online
            self.offline = offline
            self.preferred = preferred
        }

        public static var `default`: Models {
            Models(
                online: ModelSlot(enabled: true, llm: .onlineDefault),
                offline: ModelSlot(enabled: false, llm: .offlineDefault),
                preferred: .online
            )
        }

        public var order: [ModelSlotID] {
            preferred == .online ? [.online, .offline] : [.offline, .online]
        }

        public var anyEnabled: Bool {
            online.enabled || offline.enabled
        }

        public func enabledInOrder() -> [(id: ModelSlotID, llm: LLM)] {
            order.compactMap { id in
                let slot = self[id]
                guard slot.enabled else { return nil }
                return (id, slot.llm)
            }
        }

        public subscript(id: ModelSlotID) -> ModelSlot {
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

        enum CodingKeys: String, CodingKey {
            case order, preferred, online, offline
        }

        public init(from decoder: Decoder) throws {
            let d = Models.default
            let c = try decoder.container(keyedBy: CodingKeys.self)
            online = c.contains(.online)
                ? try ModelSlot(from: c.superDecoder(forKey: .online), defaults: d.online)
                : d.online
            offline = c.contains(.offline)
                ? try ModelSlot(from: c.superDecoder(forKey: .offline), defaults: d.offline)
                : d.offline
            if let order = try c.decodeIfPresent([String].self, forKey: .order),
               let first = order.compactMap(ModelSlotID.init(rawValue:)).first {
                preferred = first
            } else {
                preferred = try c.decodeIfPresent(ModelSlotID.self, forKey: .preferred) ?? d.preferred
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(order, forKey: .order)
            try c.encode(online, forKey: .online)
            try c.encode(offline, forKey: .offline)
        }
    }

    public struct Hotkey: Equatable, Codable {
        public var enabled: Bool
        public var keyEquivalent: String
        public var command: Bool
        public var shift: Bool
        public var option: Bool
        public var control: Bool

        public init(enabled: Bool, keyEquivalent: String, command: Bool, shift: Bool, option: Bool, control: Bool) {
            self.enabled = enabled
            self.keyEquivalent = keyEquivalent
            self.command = command
            self.shift = shift
            self.option = option
            self.control = control
        }

        public static var `default`: Hotkey {
            .init(enabled: true, keyEquivalent: "l", command: true, shift: true, option: false, control: false)
        }

        public var summary: String {
            var parts: [String] = []
            if control { parts.append("⌃") }
            if option { parts.append("⌥") }
            if shift { parts.append("⇧") }
            if command { parts.append("⌘") }
            parts.append(keyEquivalent.uppercased())
            return parts.joined()
        }

        public var flags: [String] {
            var f: [String] = []
            if command { f.append("cmd") }
            if shift { f.append("shift") }
            if option { f.append("option") }
            if control { f.append("ctrl") }
            return f
        }

        enum CodingKeys: String, CodingKey {
            case enabled, key, flags
        }

        public init(from decoder: Decoder) throws {
            let d = Hotkey.default
            let c = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? d.enabled
            keyEquivalent = try c.decodeIfPresent(String.self, forKey: .key)?.lowercased() ?? d.keyEquivalent
            if let flags = try c.decodeIfPresent([String].self, forKey: .flags) {
                let set = Set(flags.map { $0.lowercased() })
                command = set.contains("cmd") || set.contains("command")
                shift = set.contains("shift")
                option = set.contains("alt") || set.contains("option")
                control = set.contains("ctrl") || set.contains("control")
            } else {
                command = d.command
                shift = d.shift
                option = d.option
                control = d.control
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(enabled, forKey: .enabled)
            try c.encode(flags, forKey: .flags)
            try c.encode(keyEquivalent, forKey: .key)
        }
    }

    public struct DelimiterSettings: Equatable, Codable {
        public var preset: DelimiterPreset
        public var open: String
        public var close: String
        public var ask: AskMode

        public init(preset: DelimiterPreset, open: String, close: String, ask: AskMode) {
            self.preset = preset
            self.open = open
            self.close = close
            self.ask = ask
        }

        public static var `default`: DelimiterSettings {
            .init(preset: .displayDollar, open: "$$", close: "$$", ask: .none)
        }

        public init(from decoder: Decoder) throws {
            let d = DelimiterSettings.default
            let c = try decoder.container(keyedBy: CodingKeys.self)
            preset = try c.decodeIfPresent(DelimiterPreset.self, forKey: .preset) ?? d.preset
            open = try c.decodeIfPresent(String.self, forKey: .open) ?? d.open
            close = try c.decodeIfPresent(String.self, forKey: .close) ?? d.close
            ask = try c.decodeIfPresent(AskMode.self, forKey: .ask) ?? d.ask
        }
    }

    public enum AskMode: String, Equatable, CaseIterable, Identifiable, Codable {
        case none, before, after
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .none: return "Always use preset"
            case .before: return "Ask before capture"
            case .after: return "Ask after capture"
            }
        }
    }

    public var models: Models
    public var hotkey: Hotkey
    public var delimiters: DelimiterSettings
    public var notify: Bool
    public var launchAtLogin: Bool
    /// When false (default), stay a menu-bar extra with no Dock icon.
    public var showDockIcon: Bool

    public init(
        models: Models,
        hotkey: Hotkey,
        delimiters: DelimiterSettings,
        notify: Bool,
        launchAtLogin: Bool,
        showDockIcon: Bool
    ) {
        self.models = models
        self.hotkey = hotkey
        self.delimiters = delimiters
        self.notify = notify
        self.launchAtLogin = launchAtLogin
        self.showDockIcon = showDockIcon
    }

    public static var configDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/latex-snip")
    }

    public static var configURL: URL { configDir.appendingPathComponent("config.yaml") }

    public static var `default`: AppConfig {
        AppConfig(
            models: .default,
            hotkey: .default,
            delimiters: .default,
            notify: true,
            launchAtLogin: false,
            showDockIcon: false
        )
    }

    enum CodingKeys: String, CodingKey {
        case models
        case llm
        case hotkey
        case delimiters
        case notify
        case launchAtLogin = "launch_at_login"
        case showDockIcon = "show_dock_icon"
    }

    public init(from decoder: Decoder) throws {
        let d = AppConfig.default
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let models = try c.decodeIfPresent(Models.self, forKey: .models) {
            self.models = models
        } else if c.contains(.llm) {
            // Legacy single `llm:` block → Online, enabled.
            models = d.models
            models.online = ModelSlot(
                enabled: true,
                llm: try LLM(from: c.superDecoder(forKey: .llm), defaults: d.models.online.llm)
            )
        } else {
            models = d.models
        }
        hotkey = try c.decodeIfPresent(Hotkey.self, forKey: .hotkey) ?? d.hotkey
        delimiters = try c.decodeIfPresent(DelimiterSettings.self, forKey: .delimiters) ?? d.delimiters
        notify = try c.decodeIfPresent(Bool.self, forKey: .notify) ?? d.notify
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
        showDockIcon = try c.decodeIfPresent(Bool.self, forKey: .showDockIcon) ?? d.showDockIcon
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(models, forKey: .models)
        try c.encode(hotkey, forKey: .hotkey)
        try c.encode(delimiters, forKey: .delimiters)
        try c.encode(notify, forKey: .notify)
        try c.encode(launchAtLogin, forKey: .launchAtLogin)
        try c.encode(showDockIcon, forKey: .showDockIcon)
    }

    /// Thrown by `load` with a message that names the bad key or YAML line.
    public struct LoadError: Error, LocalizedError, Equatable {
        public var message: String
        public var errorDescription: String? { message }
    }

    public static func load(from url: URL = configURL) throws -> AppConfig {
        guard FileManager.default.fileExists(atPath: url.path) else { return .default }
        let text = try String(contentsOf: url, encoding: .utf8)
        return try parse(yaml: text, source: url.lastPathComponent)
    }

    public static func parse(yaml text: String, source: String = "config.yaml") throws -> AppConfig {
        var cfg: AppConfig
        do {
            // Empty or comment-only file → defaults.
            if try Yams.compose(yaml: text) == nil { return .default }
            cfg = try YAMLDecoder().decode(AppConfig.self, from: text)
        } catch let error as DecodingError {
            throw LoadError(message: "\(source): \(describe(error))")
        } catch {
            throw LoadError(message: "\(source): \(error)")
        }
        let pair = Delimiters.resolve(
            preset: cfg.delimiters.preset,
            open: cfg.delimiters.open,
            close: cfg.delimiters.close
        )
        cfg.delimiters.open = pair.0
        cfg.delimiters.close = pair.1
        return cfg
    }

    /// Write the config. With `backupExisting`, first copy the current file to
    /// `config.yaml.bak` — used when the file on disk failed to load, so the
    /// user's unreadable settings aren't silently replaced.
    public func save(to url: URL = configURL, backupExisting: Bool = false) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if backupExisting, fm.fileExists(atPath: url.path) {
            let bak = AppConfig.backupURL(for: url)
            if fm.fileExists(atPath: bak.path) {
                try fm.removeItem(at: bak)
            }
            try fm.copyItem(at: url, to: bak)
        }
        let yaml = try YAMLEncoder().encode(self)
        try yaml.write(to: url, atomically: true, encoding: .utf8)
    }

    public static func backupURL(for url: URL) -> URL {
        url.appendingPathExtension("bak")
    }

    private static func describe(_ error: DecodingError) -> String {
        func path(_ keys: [CodingKey]) -> String {
            let p = keys.map { $0.intValue.map { "[\($0)]" } ?? $0.stringValue }.joined(separator: ".")
            return p.isEmpty ? "top level" : p
        }
        switch error {
        case .typeMismatch(_, let ctx), .valueNotFound(_, let ctx),
             .keyNotFound(_, let ctx), .dataCorrupted(let ctx):
            let underlying = ctx.underlyingError.map { " (\($0))" } ?? ""
            return "\(path(ctx.codingPath)): \(ctx.debugDescription)\(underlying)"
        @unknown default:
            return "\(error)"
        }
    }
}
