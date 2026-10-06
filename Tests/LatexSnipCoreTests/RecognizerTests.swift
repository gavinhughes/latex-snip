import XCTest
@testable import LatexSnipCore

final class RecognizerTests: XCTestCase {
    private let image = URL(fileURLWithPath: "/nonexistent/snip.png")

    private func models(builtin: Bool, online: Bool = false, offline: Bool = false) -> AppConfig.Models {
        var m = AppConfig.Models.default
        m.builtinEnabled = builtin
        m.online.enabled = online
        m.offline.enabled = offline
        return m
    }

    func testBuiltinResultIsUsed() async throws {
        let r = try await Recognizer.recognize(imageURL: image, models: models(builtin: true)) { _ in " x^{2} " }
        XCTAssertEqual(r, .init(latex: "x^{2}", engine: .builtin))
    }

    func testBuiltinFailureIsReported() async {
        struct Boom: Error, LocalizedError { var errorDescription: String? { "model missing" } }
        do {
            _ = try await Recognizer.recognize(imageURL: image, models: models(builtin: true)) { _ in throw Boom() }
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Built-in: model missing")
        }
    }

    func testEmptyBuiltinFallsThroughToNextEngine() async {
        // Offline points at an unreachable URL, so both engines fail and both are listed.
        var m = models(builtin: true, offline: true)
        m.offline.llm.baseURL = "http://127.0.0.1:9/v1"
        m.offline.llm.timeout = 2
        do {
            _ = try await Recognizer.recognize(imageURL: image, models: m) { _ in "  " }
            XCTFail("expected an error")
        } catch {
            let lines = error.localizedDescription.components(separatedBy: "\n")
            XCTAssertEqual(lines.first, "Built-in: empty response")
            XCTAssertTrue(lines.last?.hasPrefix("Offline: ") == true, error.localizedDescription)
        }
    }

    func testDisabledBuiltinIsNotCalled() async {
        do {
            _ = try await Recognizer.recognize(imageURL: image, models: models(builtin: false)) { _ in
                XCTFail("built-in should not run")
                return "x"
            }
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error.localizedDescription.hasPrefix("No models enabled"), error.localizedDescription)
        }
    }

    func testEngineOrder() {
        var m = models(builtin: true, online: true, offline: true)
        XCTAssertEqual(m.enginesInOrder, [.builtin, .online, .offline])
        m.preferred = .offline
        XCTAssertEqual(m.enginesInOrder, [.builtin, .offline, .online])
        m.builtinEnabled = false
        XCTAssertEqual(m.enginesInOrder, [.offline, .online])
    }
}
