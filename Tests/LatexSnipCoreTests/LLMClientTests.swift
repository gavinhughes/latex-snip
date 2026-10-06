import XCTest
@testable import LatexSnipCore

final class APIKeyResolutionTests: XCTestCase {
    private var authinfo: URL!

    override func setUpWithError() throws {
        authinfo = try makeTempDir(self).appendingPathComponent("authinfo")
        try """
        machine openrouter.ai login apikey password or-key
        machine api.other.example login apikey password other-key
        """.write(to: authinfo, atomically: true, encoding: .utf8)
    }

    private func onlineLLM(baseURL: String) -> AppConfig.LLM {
        var llm = AppConfig.LLM.onlineDefault
        llm.baseURL = baseURL
        return llm
    }

    func testKeyFollowsBaseURLHost() {
        let first = onlineLLM(baseURL: "https://openrouter.ai/api/v1")
        XCTAssertEqual(LLMClient.resolveAPIKey(for: first, environment: [:], authinfoPath: authinfo), "or-key")

        // Same slot after editing the base URL in Settings.
        var edited = first
        edited.baseURL = "https://other.example/v1"
        XCTAssertEqual(LLMClient.resolveAPIKey(for: edited, environment: [:], authinfoPath: authinfo), "other-key")

        edited.baseURL = "https://unknown.example/v1"
        XCTAssertNil(LLMClient.resolveAPIKey(for: edited, environment: [:], authinfoPath: authinfo))
    }

    func testLoadedConfigHoldsNoResolvedKey() throws {
        let c = try AppConfig.parse(yaml: "models:\n  online:\n    base_url: https://openrouter.ai/api/v1\n")
        XCTAssertNil(c.models.online.llm.apiKey)
    }

    func testExplicitKeyWins() {
        var llm = onlineLLM(baseURL: "https://openrouter.ai/api/v1")
        llm.apiKey = "explicit"
        XCTAssertEqual(
            LLMClient.resolveAPIKey(for: llm, environment: ["OPENROUTER_API_KEY": "env"], authinfoPath: authinfo),
            "explicit"
        )
    }

    func testEnvironmentBeforeAuthinfo() {
        let llm = onlineLLM(baseURL: "https://openrouter.ai/api/v1")
        XCTAssertEqual(
            LLMClient.resolveAPIKey(for: llm, environment: ["OPENROUTER_API_KEY": "env"], authinfoPath: authinfo),
            "env"
        )
        XCTAssertEqual(
            LLMClient.resolveAPIKey(for: llm, environment: ["LATEX_SNIP_API_KEY": "generic"], authinfoPath: authinfo),
            "generic"
        )
    }

    func testOfflineDefaultStaysKeyless() {
        var llm = AppConfig.LLM.offlineDefault
        llm.baseURL = "https://openrouter.ai/api/v1"
        XCTAssertNil(LLMClient.resolveAPIKey(
            for: llm,
            environment: ["LATEX_SNIP_API_KEY": "generic"],
            authinfoPath: authinfo
        ))
    }
}

final class ExtractLatexTests: XCTestCase {
    func testPlainTextIsTrimmed() {
        XCTAssertEqual(LLMClient.extractLatex("  x^2 \n"), "x^2")
    }

    func testLatexFence() {
        XCTAssertEqual(LLMClient.extractLatex("```latex\n\\frac{a}{b}\n```"), "\\frac{a}{b}")
    }

    func testBareFenceMultiline() {
        XCTAssertEqual(LLMClient.extractLatex("```\na = b\n\\\\\nc = d\n```\n"), "a = b\n\\\\\nc = d")
    }

    func testFenceWithoutClosing() {
        XCTAssertEqual(LLMClient.extractLatex("```tex\ny"), "y")
    }

    func testLeadingLatexLabel() {
        XCTAssertEqual(LLMClient.extractLatex("latex\nE = mc^2"), "E = mc^2")
    }
}

final class HostChangeTests: XCTestCase {
    private func configured() -> AppConfig.LLM {
        var llm = AppConfig.LLM.onlineDefault
        llm.apiKey = "explicit"
        llm.authinfoMachine = "openrouter.ai"
        return llm
    }

    func testHostChangeDropsHostBoundCredentials() throws {
        let authinfo = try makeTempDir(self).appendingPathComponent("authinfo")
        try "machine openrouter.ai password or-key\nmachine api.groq.com password groq-key\n"
            .write(to: authinfo, atomically: true, encoding: .utf8)
        let env = ["OPENROUTER_API_KEY": "or-env", "LATEX_SNIP_API_KEY": "generic"]

        var llm = configured()
        let old = llm.baseURL
        llm.baseURL = "https://api.groq.com/openai/v1"
        llm.dropHostBoundCredentials(ifHostChangedFrom: old)

        XCTAssertNil(llm.apiKey)
        XCTAssertEqual(llm.apiKeyEnv, "")
        XCTAssertNil(llm.authinfoMachine)
        XCTAssertTrue(llm.authinfoEnabled)
        XCTAssertEqual(LLMClient.resolveAPIKey(for: llm, environment: env, authinfoPath: authinfo), "groq-key")

        llm.baseURL = "https://unknown.example/v1"
        XCTAssertNil(LLMClient.resolveAPIKey(for: llm, environment: env, authinfoPath: authinfo))
    }

    func testSameHostKeepsCredentials() {
        var llm = configured()
        let before = llm
        llm.baseURL = "https://OpenRouter.ai/api/v2"
        llm.dropHostBoundCredentials(ifHostChangedFrom: before.baseURL)
        XCTAssertEqual(llm.apiKey, "explicit")
        XCTAssertEqual(llm.apiKeyEnv, "OPENROUTER_API_KEY")
        XCTAssertEqual(llm.authinfoMachine, "openrouter.ai")
    }

    func testUnparseableURLsCompareAsStrings() {
        var llm = configured()
        llm.baseURL = "not a url"
        llm.dropHostBoundCredentials(ifHostChangedFrom: "not a url")
        XCTAssertEqual(llm.apiKey, "explicit")
        llm.dropHostBoundCredentials(ifHostChangedFrom: "also not a url")
        XCTAssertNil(llm.apiKey)
    }
}
