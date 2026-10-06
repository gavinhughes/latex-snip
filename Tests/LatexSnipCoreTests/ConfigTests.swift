import XCTest
@testable import LatexSnipCore

final class ConfigTests: XCTestCase {
    private func customized() -> AppConfig {
        var c = AppConfig.default
        c.models.online.llm.systemPrompt = "Custom prompt: $x$ and \\(y\\)"
        c.models.online.llm.apiKey = "sk-explicit"
        c.models.online.llm.apiKeyEnv = ""
        c.models.online.llm.authinfoMachine = "example.com"
        c.models.online.llm.authinfoLogin = "me"
        c.models.online.llm.timeout = 42.5
        c.models.online.llm.temperature = 0.3
        c.models.offline.enabled = true
        c.models.offline.llm.authinfoEnabled = true
        c.models.offline.llm.apiKeyEnv = "LOCAL_KEY"
        c.models.preferred = .offline
        c.hotkey = .init(enabled: false, keyEquivalent: "k", command: false, shift: true, option: true, control: true)
        c.delimiters = .init(preset: .custom, open: "<<", close: ">>", ask: .after)
        c.notify = false
        c.launchAtLogin = true
        c.showDockIcon = true
        return c
    }

    func testRoundTripPreservesEverySetting() throws {
        let url = try makeTempDir(self).appendingPathComponent("config.yaml")
        let original = customized()
        try original.save(to: url)
        XCTAssertEqual(try AppConfig.load(from: url), original)
    }

    func testRoundTripOfDefaults() throws {
        let url = try makeTempDir(self).appendingPathComponent("config.yaml")
        try AppConfig.default.save(to: url)
        XCTAssertEqual(try AppConfig.load(from: url), .default)
    }

    func testEmptyAPIKeyEnvIsWrittenAndNotReverted() throws {
        let url = try makeTempDir(self).appendingPathComponent("config.yaml")
        var c = AppConfig.default
        c.models.online.llm.apiKeyEnv = ""
        try c.save(to: url)
        XCTAssertEqual(try AppConfig.load(from: url).models.online.llm.apiKeyEnv, "")
    }

    func testAuthinfoBoolAndBlockForms() throws {
        let yaml = """
        models:
          online:
            authinfo: false
          offline:
            authinfo:
              machine: local.test
        """
        let c = try AppConfig.parse(yaml: yaml)
        XCTAssertFalse(c.models.online.llm.authinfoEnabled)
        XCTAssertTrue(c.models.offline.llm.authinfoEnabled)
        XCTAssertEqual(c.models.offline.llm.authinfoMachine, "local.test")
        XCTAssertEqual(c.models.offline.llm.authinfoLogin, "apikey")
    }

    func testPartialFileKeepsDefaults() throws {
        let c = try AppConfig.parse(yaml: "notify: false\nmodels:\n  online:\n    model: m\n")
        var expected = AppConfig.default
        expected.notify = false
        expected.models.online.llm.model = "m"
        XCTAssertEqual(c, expected)
    }

    func testEmptyOrMissingFileGivesDefaults() throws {
        let dir = try makeTempDir(self)
        XCTAssertEqual(try AppConfig.load(from: dir.appendingPathComponent("nope.yaml")), .default)
        XCTAssertEqual(try AppConfig.parse(yaml: ""), .default)
        XCTAssertEqual(try AppConfig.parse(yaml: "# only a comment\n"), .default)
    }

    func testExampleConfigLoads() throws {
        let example = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("config.example.yaml")
        let c = try AppConfig.load(from: example)
        XCTAssertEqual(c, .default)
    }

    func testOrderAndLegacyPreferred() throws {
        XCTAssertEqual(try AppConfig.parse(yaml: "models:\n  order: [offline, online]\n").models.preferred, .offline)
        XCTAssertEqual(try AppConfig.parse(yaml: "models:\n  preferred: offline\n").models.preferred, .offline)
    }

    func testLegacyLLMBlockBecomesOnline() throws {
        let yaml = """
        llm:
          base_url: https://api.example.com/v1
          model: legacy-model
          timeout_s: 30
        """
        let c = try AppConfig.parse(yaml: yaml)
        XCTAssertTrue(c.models.online.enabled)
        XCTAssertEqual(c.models.online.llm.baseURL, "https://api.example.com/v1")
        XCTAssertEqual(c.models.online.llm.model, "legacy-model")
        XCTAssertEqual(c.models.online.llm.timeout, 30)
        XCTAssertEqual(c.models.online.llm.apiKeyEnv, "OPENROUTER_API_KEY")
    }

    func testHotkeyFlagsAndKey() throws {
        let c = try AppConfig.parse(yaml: "hotkey:\n  flags: [Command, alt]\n  key: P\n")
        XCTAssertEqual(c.hotkey, .init(enabled: true, keyEquivalent: "p", command: true, shift: false, option: true, control: false))
    }

    func testPresetDelimitersOverrideFileOpenClose() throws {
        let c = try AppConfig.parse(yaml: "delimiters:\n  preset: inline_paren\n  open: x\n  close: y\n")
        XCTAssertEqual(c.delimiters.open, "\\(")
        XCTAssertEqual(c.delimiters.close, "\\)")
    }
}

final class ConfigLoadErrorTests: XCTestCase {
    func testMalformedYAMLThrowsWithMessage() {
        XCTAssertThrowsError(try AppConfig.parse(yaml: "hotkey:\n  key: [unclosed\n")) { error in
            let message = (error as? AppConfig.LoadError)?.message ?? ""
            XCTAssertTrue(message.hasPrefix("config.yaml:"), message)
        }
    }

    func testTypeMismatchNamesTheKey() {
        XCTAssertThrowsError(try AppConfig.parse(yaml: "hotkey:\n  enabled: maybe\n")) { error in
            let message = (error as? AppConfig.LoadError)?.message ?? ""
            XCTAssertTrue(message.contains("hotkey.enabled"), message)
        }
    }

    func testUnknownPresetIsAnError() {
        XCTAssertThrowsError(try AppConfig.parse(yaml: "delimiters:\n  preset: bogus\n")) { error in
            let message = (error as? AppConfig.LoadError)?.message ?? ""
            XCTAssertTrue(message.contains("delimiters.preset"), message)
        }
    }

    func testLoadThrowsForBrokenFile() throws {
        let url = try makeTempDir(self).appendingPathComponent("config.yaml")
        try "models: [".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try AppConfig.load(from: url))
    }

    func testSaveWithBackupKeepsBrokenFile() throws {
        let url = try makeTempDir(self).appendingPathComponent("config.yaml")
        let broken = "models:\n  online:\n    system_prompt: my precious prompt\n  oops: [\n"
        try broken.write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try AppConfig.load(from: url))

        try AppConfig.default.save(to: url, backupExisting: true)

        let bak = AppConfig.backupURL(for: url)
        XCTAssertEqual(bak.lastPathComponent, "config.yaml.bak")
        XCTAssertEqual(try String(contentsOf: bak, encoding: .utf8), broken)
        XCTAssertEqual(try AppConfig.load(from: url), .default)
    }

    func testSaveWithBackupReplacesOldBackup() throws {
        let url = try makeTempDir(self).appendingPathComponent("config.yaml")
        let bak = AppConfig.backupURL(for: url)
        try "old backup".write(to: bak, atomically: true, encoding: .utf8)
        try "current: [".write(to: url, atomically: true, encoding: .utf8)
        try AppConfig.default.save(to: url, backupExisting: true)
        XCTAssertEqual(try String(contentsOf: bak, encoding: .utf8), "current: [")
    }

    func testPlainSaveDoesNotBackUp() throws {
        let url = try makeTempDir(self).appendingPathComponent("config.yaml")
        try AppConfig.default.save(to: url)
        try AppConfig.default.save(to: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: AppConfig.backupURL(for: url).path))
    }
}
