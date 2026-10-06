import Foundation

/// One way of turning a snip into LaTeX.
public enum RecognitionEngine: String, Equatable, CaseIterable {
    case builtin
    case online
    case offline

    /// Lowercase name for status text, e.g. "Copied (built-in)".
    public var label: String {
        switch self {
        case .builtin: return "built-in"
        case .online: return "online"
        case .offline: return "offline"
        }
    }

    public var displayName: String {
        switch self {
        case .builtin: return "Built-in"
        case .online: return "Online"
        case .offline: return "Offline"
        }
    }
}

public enum Recognizer {
    public struct Error: Swift.Error, LocalizedError {
        public var message: String
        public var errorDescription: String? { message }
    }

    public struct Recognition: Equatable {
        public var latex: String
        public var engine: RecognitionEngine
    }

    /// Try enabled engines in order (built-in, then Online/Offline in the
    /// preferred order). An error or empty result falls through to the next
    /// engine; if all fail, the error lists each one.
    ///
    /// `builtin` runs the bundled model on the image file. It's passed in so
    /// the app can share one loaded model and tests can stub it.
    public static func recognize(
        imageURL: URL,
        models: AppConfig.Models,
        builtin: @escaping @Sendable (URL) throws -> String
    ) async throws -> Recognition {
        let engines = models.enginesInOrder
        guard !engines.isEmpty else {
            throw Error(message: "No models enabled. Turn on Built-in, Online or Offline in Settings.")
        }

        var errors: [String] = []
        for engine in engines {
            do {
                let latex: String
                switch engine {
                case .builtin:
                    // CPU-bound; keep it off the caller's (main) actor.
                    latex = try await Task.detached(priority: .userInitiated) { try builtin(imageURL) }.value
                case .online:
                    latex = try await LLMClient.recognize(imageURL: imageURL, config: models.online.llm)
                case .offline:
                    latex = try await LLMClient.recognize(imageURL: imageURL, config: models.offline.llm)
                }
                let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    errors.append("\(engine.displayName): empty response")
                    continue
                }
                return Recognition(latex: trimmed, engine: engine)
            } catch {
                errors.append("\(engine.displayName): \(error.localizedDescription)")
            }
        }
        throw Error(message: errors.joined(separator: "\n"))
    }
}
