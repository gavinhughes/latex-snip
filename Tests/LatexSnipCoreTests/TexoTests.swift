import CoreGraphics
import XCTest
@testable import LatexSnipCore

/// Models/Texo from scripts/fetch-model.sh (or LATEX_SNIP_TEXO_DIR). Skipped
/// locally when absent; CI fetches the model, so there it must be present.
private func texoDirectory() throws -> URL {
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

final class TexoModelTests: XCTestCase {
    private static var model: TexoModel?

    private func model() throws -> TexoModel {
        if let m = Self.model { return m }
        let m = try TexoModel(directory: try texoDirectory())
        Self.model = m
        return m
    }

    private func fixture(_ name: String) throws -> URL {
        try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Fixtures"))
    }

    func testRecognizesFixtures() throws {
        let cases: [(String, String)] = [
            ("inline-emc2", #"E=mc^{2}"#),
            ("quadratic", #"x=\frac{-b\pm\sqrt{b^{2}-4ac}}{2a}"#),
            ("cases", #"|x|=\begin{cases}x&x\geq 0\\ -x&x<0\end{cases}"#),
            ("dark-limit", #"\lim_{n\rightarrow\infty}\left(1+\frac{1}{n}\right)^{n}=e"#),
            ("lowres-variance", #"\sigma^{2}=\frac{1}{N}\sum_{i=1}^{N}(x_{i}-\mu)^{2}"#),
            ("matrix-inverse", #"\begin{pmatrix}a&b\\ c&d\end{pmatrix}^{-1}=\frac{1}{ad-bc}\begin{pmatrix}d&-b\\ -c&a\end{pmatrix}"#),
            ("wide-binomial", #"\frac{d}{dx}\left[\int_{0}^{x}\sin(t^{2})\,dt\right]+\sum_{k=1}^{n}\binom{n}{k}x^{k}y^{n-k}=\sin(x^{2})+(x+y)^{n}-y^{n}"#),
        ]
        let m = try model()
        for (name, expected) in cases {
            XCTAssertEqual(try m.recognize(imageAt: try fixture(name)), expected, name)
        }
    }

    func testMissingFilesError() throws {
        let empty = try makeTempDir(self)
        XCTAssertThrowsError(try TexoModel(directory: empty)) { error in
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("encoder_model.onnx"), message)
        }
    }

    func testLoaderReportsMissingDirectoryAndRetries() throws {
        var dir: URL?
        let loader = TexoLoader { dir }
        XCTAssertThrowsError(try loader.load())
        dir = try texoDirectory()
        XCTAssertNoThrow(try loader.load())
    }
}

final class TexoTokenizerTests: XCTestCase {
    func testDecodeJoinsTokensAndSkipsSpecials() throws {
        let json = """
        {"model": {"type": "WordLevel", "vocab": {"<s>": 0, "</s>": 2, "x": 4, "^": 5, "{": 6, "2": 7, "}": 8}},
         "added_tokens": [{"id": 0, "content": "<s>", "special": true}, {"id": 2, "content": "</s>", "special": true}]}
        """
        let tok = try TexoTokenizer(data: Data(json.utf8))
        XCTAssertEqual(tok.decode([0, 4, 5, 6, 7, 8, 2]), "x ^ { 2 }")
        XCTAssertEqual(tok.decode([4, 99]), "x")
    }
}

final class TexoPreprocessorTests: XCTestCase {
    /// `width`×`height` image of `background` with a `fill` rectangle at `rect`
    /// (top-left origin).
    private func image(width: Int, height: Int, background: UInt8, fill: UInt8, rect: CGRect) -> CGImage {
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        ctx.setFillColor(gray: CGFloat(background) / 255, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setFillColor(gray: CGFloat(fill) / 255, alpha: 1)
        ctx.fill(CGRect(x: rect.minX, y: CGFloat(height) - rect.maxY, width: rect.width, height: rect.height))
        return ctx.makeImage()!
    }

    func testCropsToInk() throws {
        let img = image(width: 100, height: 50, background: 255, fill: 0, rect: CGRect(x: 10, y: 5, width: 40, height: 20))
        let g = TexoPreprocessor.cropToInk(try TexoPreprocessor.grayscale(img))
        // Texo-web's crop treats the far edge as exclusive.
        XCTAssertEqual(g.width, 39)
        XCTAssertEqual(g.height, 19)
        XCTAssertTrue(g.pixels.allSatisfy { $0 == 0 })
    }

    func testInvertsDarkMode() throws {
        let img = image(width: 20, height: 10, background: 30, fill: 240, rect: CGRect(x: 2, y: 2, width: 4, height: 4))
        let g = TexoPreprocessor.invertIfDark(try TexoPreprocessor.grayscale(img))
        XCTAssertEqual(g.pixels[0], 225)
        XCTAssertEqual(g.pixels[3 * 20 + 3], 15)
    }

    func testLightImageIsNotInverted() throws {
        let img = image(width: 20, height: 10, background: 255, fill: 0, rect: CGRect(x: 2, y: 2, width: 4, height: 4))
        let g = try TexoPreprocessor.grayscale(img)
        XCTAssertEqual(TexoPreprocessor.invertIfDark(g), g)
    }

    func testFitKeepsAspectAndCentersOnBlack() throws {
        let wide = TexoPreprocessor.Gray(width: 200, height: 50, pixels: [UInt8](repeating: 255, count: 200 * 50))
        let out = try TexoPreprocessor.fit(wide)
        XCTAssertEqual(out.width, 384)
        XCTAssertEqual(out.height, 384)
        // 200×50 → 384×96, centred vertically: rows 144..<240 are image, rest padding.
        XCTAssertEqual(out.pixels[0], 0)
        XCTAssertEqual(out.pixels[143 * 384 + 10], 0)
        XCTAssertEqual(out.pixels[144 * 384 + 10], 255)
        XCTAssertEqual(out.pixels[239 * 384 + 10], 255)
        XCTAssertEqual(out.pixels[240 * 384 + 10], 0)
    }

    func testPixelValuesShapeAndNormalization() throws {
        let img = image(width: 60, height: 30, background: 255, fill: 0, rect: CGRect(x: 5, y: 5, width: 20, height: 10))
        let values = try TexoPreprocessor.pixelValues(for: img)
        XCTAssertEqual(values.count, 3 * 384 * 384)
        // Black padding normalizes to (0 - mean) / std.
        XCTAssertEqual(values[0], (0 - 0.7931) / 0.1738, accuracy: 1e-4)
        XCTAssertEqual(Array(values[0..<384 * 384]), Array(values[384 * 384..<2 * 384 * 384]))
    }
}
