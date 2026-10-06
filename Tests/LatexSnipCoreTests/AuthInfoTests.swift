import XCTest
import LatexSnipCore

final class AuthInfoTests: XCTestCase {
    private func write(_ text: String) throws -> URL {
        let url = try makeTempDir(self).appendingPathComponent("authinfo")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testMatchesHostFromBaseURL() throws {
        let path = try write("machine openrouter.ai login apikey password secret1\n")
        XCTAssertEqual(AuthInfo.lookupPassword(baseURL: "https://openrouter.ai/api/v1", path: path), "secret1")
    }

    func testApiPrefixBothWays() throws {
        let path = try write("machine api.a.test login apikey password A\nmachine b.test login apikey password B\n")
        XCTAssertEqual(AuthInfo.lookupPassword(baseURL: "https://a.test/v1", path: path), "A")
        XCTAssertEqual(AuthInfo.lookupPassword(baseURL: "https://api.b.test/v1", path: path), "B")
    }

    func testExplicitMachineFirst() throws {
        let path = try write("machine host.test login apikey password H\nmachine named login apikey password N\n")
        XCTAssertEqual(AuthInfo.lookupPassword(machine: "Named", baseURL: "https://host.test", path: path), "N")
    }

    func testLoginFilterAndCommentsAndBlankLines() throws {
        let path = try write("""
        # comment line
        machine x.test login someone password wrong

        machine x.test login APIKEY password right
        """)
        XCTAssertEqual(AuthInfo.lookupPassword(baseURL: "https://x.test", path: path), "right")
        XCTAssertEqual(AuthInfo.lookupPassword(login: "someone", baseURL: "https://x.test", path: path), "wrong")
    }

    func testEntryWithoutLoginMatchesAnyLogin() throws {
        let path = try write("machine x.test password p\n")
        XCTAssertEqual(AuthInfo.lookupPassword(baseURL: "https://x.test", path: path), "p")
    }

    func testSecretAndTokenAliases() throws {
        let path = try write("machine s.test secret S\nmachine t.test token T\n")
        XCTAssertEqual(AuthInfo.lookupPassword(baseURL: "https://s.test", path: path), "S")
        XCTAssertEqual(AuthInfo.lookupPassword(baseURL: "https://t.test", path: path), "T")
    }

    func testMissingFileOrNoMatch() throws {
        let dir = try makeTempDir(self)
        XCTAssertNil(AuthInfo.lookupPassword(baseURL: "https://x.test", path: dir.appendingPathComponent("none")))
        let path = try write("machine other.test password p\n")
        XCTAssertNil(AuthInfo.lookupPassword(baseURL: "https://x.test", path: path))
    }
}
