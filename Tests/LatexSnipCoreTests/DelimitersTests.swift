import XCTest
import LatexSnipCore

final class DelimitersTests: XCTestCase {
    func testStripSinglePairs() {
        XCTAssertEqual(Delimiters.stripExisting("$x$"), "x")
        XCTAssertEqual(Delimiters.stripExisting("$$ x $$"), "x")
        XCTAssertEqual(Delimiters.stripExisting("\\[x\\]"), "x")
        XCTAssertEqual(Delimiters.stripExisting("\\(x\\)"), "x")
        XCTAssertEqual(Delimiters.stripExisting("  x + y \n"), "x + y")
    }

    func testDoesNotStripAcrossSeparateExpressions() {
        XCTAssertEqual(Delimiters.stripExisting("$a$ + $b$"), "$a$ + $b$")
        XCTAssertEqual(Delimiters.stripExisting("$$a$$ + $$b$$"), "$$a$$ + $$b$$")
        XCTAssertEqual(Delimiters.stripExisting("\\(a\\) and \\(b\\)"), "\\(a\\) and \\(b\\)")
        XCTAssertEqual(Delimiters.stripExisting("\\[a\\] \\[b\\]"), "\\[a\\] \\[b\\]")
    }

    func testLoneDollarIsNotStripped() {
        XCTAssertEqual(Delimiters.stripExisting("$"), "$")
    }

    func testWrap() {
        XCTAssertEqual(Delimiters.wrap("x", open: "$$", close: "$$"), "$$x$$")
        XCTAssertEqual(Delimiters.wrap("$x$", open: "\\[", close: "\\]"), "\\[x\\]")
        XCTAssertEqual(Delimiters.wrap("$a$ + $b$", open: "", close: ""), "$a$ + $b$")
        XCTAssertEqual(Delimiters.wrap("$a$ + $b$", open: "$$", close: "$$"), "$$$a$ + $b$$$")
    }

    func testResolve() {
        XCTAssertTrue(Delimiters.resolve(preset: .inlineDollar, open: "x", close: "y") == ("$", "$"))
        XCTAssertTrue(Delimiters.resolve(preset: .custom, open: "<", close: ">") == ("<", ">"))
        XCTAssertTrue(Delimiters.resolve(preset: .custom, open: nil, close: nil) == ("", ""))
    }
}
