import Foundation

public enum LLMClient {
    public struct Error: Swift.Error, LocalizedError {
        public var message: String
        public var errorDescription: String? { message }
    }

    public static func recognize(imageURL: URL, config: AppConfig.LLM) async throws -> String {
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
        if let key = resolveAPIKey(for: config) {
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

    static func extractLatex(_ text: String) -> String {
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

    /// Resolved for every request from the slot's current base URL, so
    /// editing the URL in Settings never sends an old host's key to a new one.
    /// Offline defaults have an empty `apiKeyEnv` and authinfo off, so they
    /// stay keyless (local Ollama/LM Studio).
    public static func resolveAPIKey(
        for llm: AppConfig.LLM,
        environment env: [String: String] = ProcessInfo.processInfo.environment,
        authinfoPath: URL? = nil
    ) -> String? {
        if let k = llm.apiKey, !k.isEmpty { return k }
        if !llm.apiKeyEnv.isEmpty {
            if let v = env[llm.apiKeyEnv], !v.isEmpty { return v }
            if let v = env["LATEX_SNIP_API_KEY"], !v.isEmpty { return v }
        }
        guard llm.authinfoEnabled else { return nil }
        return AuthInfo.lookupPassword(
            machine: llm.authinfoMachine,
            login: llm.authinfoLogin,
            baseURL: llm.baseURL,
            path: authinfoPath
        )
    }
}
