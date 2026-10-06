import Foundation
import XCTest
import LatexSnipCore

/// Fresh temp directory per test, removed on teardown.
func makeTempDir(_ test: XCTestCase) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("LatexSnipCoreTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    test.addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
    return dir
}

/// Models/Texo from scripts/fetch-model.sh (or LATEX_SNIP_TEXO_DIR). Skipped
/// locally when absent; CI fetches the model, so there it must be present.
func texoModelDirectory() throws -> URL {
    if let dir = ProcessInfo.processInfo.environment["LATEX_SNIP_TEXO_DIR"], !dir.isEmpty {
        return URL(fileURLWithPath: dir)
    }
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let dir = root.appendingPathComponent("Models/Texo")
    let present = TexoModel.fileNames.allSatisfy {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent($0).path)
    }
    if !present {
        if ProcessInfo.processInfo.environment["CI"] != nil {
            XCTFail("Models/Texo missing in CI; run scripts/fetch-model.sh")
        }
        throw XCTSkip("Models/Texo not present; run scripts/fetch-model.sh")
    }
    return dir
}
