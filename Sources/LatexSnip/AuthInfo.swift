import Foundation

enum AuthInfo {
    static var defaultPaths: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".authinfo"),
            home.appendingPathComponent(".netrc")
        ]
    }

    static func lookupPassword(
        machine: String? = nil,
        login: String? = "apikey",
        baseURL: String? = nil,
        path: URL? = nil
    ) -> String? {
        let entries = loadEntries(path: path)
        guard !entries.isEmpty else { return nil }

        var candidates: [String] = []
        if let machine { candidates.append(machine.lowercased()) }
        if let baseURL, let host = URL(string: baseURL)?.host?.lowercased() {
            candidates.append(host)
            if host.hasPrefix("api.") {
                candidates.append(String(host.dropFirst(4)))
            } else {
                candidates.append("api.\(host)")
            }
        }

        var seen = Set<String>()
        let machines = candidates.filter { seen.insert($0).inserted }
        let loginL = (login ?? "apikey").lowercased()

        for m in machines {
            for ent in entries where ent["machine"]?.lowercased() == m {
                if login != nil,
                   let entLogin = ent["login"]?.lowercased(),
                   !entLogin.isEmpty,
                   entLogin != loginL {
                    continue
                }
                if let pw = ent["password"] ?? ent["secret"] ?? ent["token"], !pw.isEmpty {
                    return pw
                }
            }
        }
        return nil
    }

    private static func loadEntries(path: URL?) -> [[String: String]] {
        let paths = path.map { [$0] } ?? defaultPaths
        var out: [[String: String]] = []
        for p in paths {
            guard let text = try? String(contentsOf: p, encoding: .utf8) else { continue }
            for line in text.components(separatedBy: .newlines) {
                let ent = parseLine(line)
                if ent["machine"] != nil { out.append(ent) }
            }
        }
        return out
    }

    private static func parseLine(_ line: String) -> [String: String] {
        let s = line.trimmingCharacters(in: .whitespaces)
        if s.isEmpty || s.hasPrefix("#") { return [:] }
        let parts = s.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var out: [String: String] = [:]
        var i = 0
        while i + 1 < parts.count {
            out[parts[i]] = parts[i + 1]
            i += 2
        }
        return out
    }
}
