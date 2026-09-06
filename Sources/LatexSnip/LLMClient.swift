import Foundation

enum LLMClient {
    struct Error: Swift.Error, LocalizedError {
        var message: String
        var errorDescription: String? { message }
    }

    struct Recognition: Equatable {
        var latex: String
        var slot: AppConfig.ModelSlotID
    }

    /// Try enabled slots in preferred order. Network / HTTP / timeout / empty
    /// responses fall through to the next enabled slot. Combined error if all fail.
    static func recognize(imageURL: URL, models: AppConfig.Models) async throws -> Recognition {
        let attempts = models.enabledInOrder()
        guard !attempts.isEmpty else {
            throw Error(message: "No models enabled. Turn on Online and/or Offline in Settings.")
        }

        var errors: [String] = []
        for (id, config) in attempts {
            do {
                let latex = try await recognize(imageURL: imageURL, config: config)
                let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    errors.append("\(id.displayName): empty response")
                    continue
                }
                return Recognition(latex: trimmed, slot: id)
            } catch {
                errors.append("\(id.displayName): \(error.localizedDescription)")
            }
        }
        throw Error(message: errors.joined(separator: "\n"))
    }

    static func recognize(imageURL: URL, config: AppConfig.LLM) async throws -> String {
        guard let base = URL(string: config.baseURL) else {
            throw Error(message: "Invalid base URL")
        }
        let endpoint = base.appendingPathComponent("chat/completions")
        let data = try Data(contentsOf: imageURL)
        let b64 = data.base64EncodedString()
        let dataURL = "data:image/png;base64,\(b64)"

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = config.timeout
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = config.apiKey, !key.isEmpty {
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        if config.baseURL.contains("openrouter.ai") {
            req.setValue("https://github.com/gavinhughes/latex-snip", forHTTPHeaderField: "HTTP-Referer")
            req.setValue("LaTeX Snip", forHTTPHeaderField: "X-Title")
        }

        let body: [String: Any] = [
            "model": config.model,
            "temperature": config.temperature,
            "messages": [
                ["role": "system", "content": config.systemPrompt],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Convert the math in this image to LaTeX. Output only the LaTeX."
                        ],
                        [
                            "type": "image_url",
                            "image_url": ["url": dataURL]
                        ]
                    ] as [[String: Any]]
                ]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (respData, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw Error(message: "No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: respData, encoding: .utf8) ?? ""
            throw Error(message: "LLM HTTP \(http.statusCode): \(text.prefix(400))")
        }

        guard
            let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any]
        else {
            throw Error(message: "Unexpected LLM response shape")
        }

        let content: String
        if let s = message["content"] as? String {
            content = s
        } else if let parts = message["content"] as? [[String: Any]] {
            content = parts.compactMap { $0["text"] as? String }.joined()
        } else {
            throw Error(message: "Missing message content")
        }
        return extractLatex(content)
    }

    private static func extractLatex(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            let lines = s.components(separatedBy: .newlines)
            if lines.count >= 2 {
                var body = Array(lines.dropFirst())
                if let last = body.last, last.hasPrefix("```") {
                    body = Array(body.dropLast())
                }
                s = body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if s.lowercased().hasPrefix("latex\n") {
            s = String(s.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s
    }
}
