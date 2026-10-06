import Foundation

/// Decoder for Texo's word-level `tokenizer.json`: each id is one LaTeX token,
/// and tokens are joined with spaces (LatexCleanup removes the extra ones).
public struct TexoTokenizer {
    let tokens: [Int: String]
    let special: Set<Int>

    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    init(data: Data) throws {
        struct File: Decodable {
            struct Model: Decodable { var vocab: [String: Int] }
            struct Added: Decodable { var id: Int; var content: String; var special: Bool? }
            var model: Model
            var added_tokens: [Added]?
        }
        let file = try JSONDecoder().decode(File.self, from: data)
        var tokens = Dictionary(uniqueKeysWithValues: file.model.vocab.map { ($1, $0) })
        var special = Set<Int>()
        for a in file.added_tokens ?? [] {
            tokens[a.id] = a.content
            if a.special ?? true { special.insert(a.id) }
        }
        self.tokens = tokens
        self.special = special
    }

    public func decode(_ ids: [Int]) -> String {
        ids.filter { !special.contains($0) }
            .compactMap { tokens[$0] }
            .joined(separator: " ")
    }
}
