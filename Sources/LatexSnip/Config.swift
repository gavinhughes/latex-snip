import Foundation
import Yams

struct AppConfig: Equatable {
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

    var llm: LLM
    var hotkey: Hotkey
    var delimiters: DelimiterSettings
    var notify: Bool
    var launchAtLogin: Bool

    static var configDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/latex-snip")
    }

    static var configURL: URL { configDir.appendingPathComponent("config.yaml") }

    static var `default`: AppConfig {
        AppConfig(
            llm: .init(
                baseURL: "https://openrouter.ai/api/v1",
                model: "google/gemini-2.5-flash",
                apiKey: nil,
                apiKeyEnv: "OPENROUTER_API_KEY",
                authinfoEnabled: true,
                authinfoMachine: nil,
                authinfoLogin: "apikey",
                timeout: 120,
                temperature: 0,
                systemPrompt: "You convert images of mathematical expressions into LaTeX. Return ONLY the LaTeX for the expression(s). Do not wrap in markdown fences. Do not add $ \\( \\[ delimiters. Do not explain."
            ),
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
            launchAtLogin: false
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
        cfg.resolveAPIKey()
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
        root["llm"] = [
            "base_url": llm.baseURL,
            "model": llm.model,
            "api_key_env": llm.apiKeyEnv,
            "timeout_s": Int(llm.timeout),
            "temperature": llm.temperature
        ] as [String: Any]
        // don't write api_key into yaml
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

        let yaml = try Yams.dump(object: root)
        try yaml.write(to: url, atomically: true, encoding: .utf8)
    }

    mutating func resolveAPIKey() {
        if let k = llm.apiKey, !k.isEmpty { return }
        let env = ProcessInfo.processInfo.environment
        if let v = env[llm.apiKeyEnv], !v.isEmpty {
            llm.apiKey = v
            return
        }
        if let v = env["LATEX_SNIP_API_KEY"], !v.isEmpty {
            llm.apiKey = v
            return
        }
        guard llm.authinfoEnabled else { return }
        llm.apiKey = AuthInfo.lookupPassword(
            machine: llm.authinfoMachine,
            login: llm.authinfoLogin,
            baseURL: llm.baseURL
        )
    }

    private func merging(yaml root: [String: Any]) -> AppConfig {
        var c = self
        if let llm = root["llm"] as? [String: Any] {
            if let v = llm["base_url"] as? String { c.llm.baseURL = v }
            if let v = llm["model"] as? String { c.llm.model = v }
            if let v = llm["api_key"] as? String { c.llm.apiKey = v }
            if let v = llm["api_key_env"] as? String { c.llm.apiKeyEnv = v }
            if let v = llm["timeout_s"] as? Int { c.llm.timeout = TimeInterval(v) }
            if let v = llm["timeout_s"] as? Double { c.llm.timeout = v }
            if let v = llm["temperature"] as? Double { c.llm.temperature = v }
            if let v = llm["temperature"] as? Int { c.llm.temperature = Double(v) }
            if let v = llm["system_prompt"] as? String { c.llm.systemPrompt = v }
            if let auth = llm["authinfo"] as? Bool {
                c.llm.authinfoEnabled = auth
            } else if let auth = llm["authinfo"] as? [String: Any] {
                c.llm.authinfoEnabled = true
                if let m = auth["machine"] as? String { c.llm.authinfoMachine = m }
                if let l = auth["login"] as? String { c.llm.authinfoLogin = l }
            }
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
        return c
    }
}
