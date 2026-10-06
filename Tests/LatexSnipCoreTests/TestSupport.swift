import Foundation
import XCTest

/// Fresh temp directory per test, removed on teardown.
func makeTempDir(_ test: XCTestCase) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("LatexSnipCoreTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    test.addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
    return dir
}
