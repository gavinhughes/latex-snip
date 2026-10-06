import CoreGraphics
import Foundation
import OnnxRuntimeBindings

/// The built-in Texo formula-recognition model (alephpi/FormulaNet, AGPL-3.0),
/// run with ONNX Runtime. Expects `encoder_model.onnx`, `decoder_model.onnx`
/// and `tokenizer.json` in one directory (see scripts/fetch-model.sh).
public final class TexoModel: @unchecked Sendable {
    public struct Error: Swift.Error, LocalizedError {
        public var message: String
        public var errorDescription: String? { message }
    }

    public static let fileNames = ["encoder_model.onnx", "decoder_model.onnx", "tokenizer.json"]

    // From the model's generation_config.json.
    static let decoderStartID = 0
    static let eosID = 2
    static let maxTokens = 1024

    private let env: ORTEnv
    private let encoder: ORTSession
    private let decoder: ORTSession
    private let tokenizer: TexoTokenizer

    public init(directory: URL) throws {
        let missing = Self.fileNames.filter {
            !FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path)
        }
        guard missing.isEmpty else {
            throw Error(message: "Built-in model files missing in \(directory.path): \(missing.joined(separator: ", "))")
        }
        env = try ORTEnv(loggingLevel: .warning)
        let options = try ORTSessionOptions()
        try options.setGraphOptimizationLevel(.all)
        encoder = try ORTSession(
            env: env, modelPath: directory.appendingPathComponent("encoder_model.onnx").path, sessionOptions: options
        )
        decoder = try ORTSession(
            env: env, modelPath: directory.appendingPathComponent("decoder_model.onnx").path, sessionOptions: options
        )
        tokenizer = try TexoTokenizer(contentsOf: directory.appendingPathComponent("tokenizer.json"))
    }

    /// Recognize the image file and return tidied LaTeX.
    public func recognize(imageAt url: URL) throws -> String {
        LatexCleanup.tidy(try recognizeRaw(TexoPreprocessor.loadImage(at: url)))
    }

    /// Raw model output: space-separated LaTeX tokens. Pass through
    /// `LatexCleanup.tidy` before showing it to anyone.
    public func recognizeRaw(_ image: CGImage) throws -> String {
        var pixels = try TexoPreprocessor.pixelValues(for: image)
        let side = NSNumber(value: TexoPreprocessor.side)
        let pixelValues = try ORTValue(
            tensorData: NSMutableData(bytes: &pixels, length: pixels.count * MemoryLayout<Float>.size),
            elementType: .float,
            shape: [1, 3, side, side]
        )
        let encoded = try encoder.run(
            withInputs: ["pixel_values": pixelValues], outputNames: ["last_hidden_state"], runOptions: nil
        )
        guard let hidden = encoded["last_hidden_state"] else {
            throw Error(message: "Built-in model: encoder produced no output")
        }

        // Greedy decoding. The no-cache decoder re-reads the whole prefix each
        // step; formulas are short, so this stays well under a second.
        var ids = [Int64(Self.decoderStartID)]
        for _ in 0..<Self.maxTokens {
            let inputIDs = try ORTValue(
                tensorData: NSMutableData(bytes: &ids, length: ids.count * MemoryLayout<Int64>.size),
                elementType: .int64,
                shape: [1, NSNumber(value: ids.count)]
            )
            let out = try decoder.run(
                withInputs: ["input_ids": inputIDs, "encoder_hidden_states": hidden],
                outputNames: ["logits"],
                runOptions: nil
            )
            guard let logits = out["logits"] else {
                throw Error(message: "Built-in model: decoder produced no output")
            }
            let next = try Self.argmaxOfLastRow(logits, rows: ids.count)
            if next == Self.eosID { break }
            ids.append(Int64(next))
        }
        return tokenizer.decode(ids.dropFirst().map { Int($0) })
    }

    private static func argmaxOfLastRow(_ logits: ORTValue, rows: Int) throws -> Int {
        let data = try logits.tensorData() as Data
        let count = data.count / MemoryLayout<Float>.size
        let vocab = count / rows
        return data.withUnsafeBytes { raw -> Int in
            let floats = raw.bindMemory(to: Float.self)
            let start = (rows - 1) * vocab
            var best = 0
            var bestValue = -Float.infinity
            for i in 0..<vocab where floats[start + i] > bestValue {
                bestValue = floats[start + i]
                best = i
            }
            return best
        }
    }
}

/// Loads the model once, on first use, from whichever thread asks first.
/// A failed load is retried on the next call (e.g. after fetching the files).
public final class TexoLoader: @unchecked Sendable {
    private let directory: () -> URL?
    private let lock = NSLock()
    private var model: TexoModel?

    /// `directory` returns nil when no model location is known.
    public init(directory: @escaping () -> URL?) {
        self.directory = directory
    }

    public func load() throws -> TexoModel {
        lock.lock()
        defer { lock.unlock() }
        if let model { return model }
        guard let dir = directory() else {
            throw TexoModel.Error(message: "Built-in model not found in the app bundle.")
        }
        let loaded = try TexoModel(directory: dir)
        model = loaded
        return loaded
    }
}
