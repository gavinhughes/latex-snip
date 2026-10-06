import Foundation

public enum DelimiterPreset: String, CaseIterable, Identifiable, Codable {
    case none
    case inlineDollar = "inline_dollar"
    case displayDollar = "display_dollar"
    case inlineParen = "inline_paren"
    case displayBracket = "display_bracket"
    case custom

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .none: return "none"
        case .inlineDollar: return "$ … $"
        case .displayDollar: return "$$ … $$"
        case .inlineParen: return "\\( … \\)"
        case .displayBracket: return "\\[ … \\]"
        case .custom: return "custom"
        }
    }

    public var pair: (String, String) {
        switch self {
        case .none: return ("", "")
        case .inlineDollar: return ("$", "$")
        case .displayDollar: return ("$$", "$$")
        case .inlineParen: return ("\\(", "\\)")
        case .displayBracket: return ("\\[", "\\]")
        case .custom: return ("", "")
        }
    }
}

public enum Delimiters {
    public static func resolve(preset: DelimiterPreset, open: String?, close: String?) -> (String, String) {
        if preset == .custom {
            return (open ?? "", close ?? "")
        }
        return preset.pair
    }

    public static func stripExisting(_ text: String) -> String {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pairs = [("$$", "$$"), ("$", "$"), ("\\[", "\\]"), ("\\(", "\\)")]
        for (a, b) in pairs {
            guard s.hasPrefix(a), s.hasSuffix(b), s.count >= a.count + b.count else { continue }
            let body = String(s.dropFirst(a.count).dropLast(b.count))
            // "$a$ + $b$" starts and ends with "$" but is two expressions.
            if body.contains(a) { continue }
            return body.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s
    }

    public static func wrap(_ latex: String, open: String, close: String) -> String {
        let body = stripExisting(latex)
        if open.isEmpty && close.isEmpty { return body }
        return "\(open)\(body)\(close)"
    }
}
