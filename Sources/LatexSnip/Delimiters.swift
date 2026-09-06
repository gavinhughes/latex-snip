import Foundation

enum DelimiterPreset: String, CaseIterable, Identifiable {
    case none
    case inlineDollar = "inline_dollar"
    case displayDollar = "display_dollar"
    case inlineParen = "inline_paren"
    case displayBracket = "display_bracket"
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "none"
        case .inlineDollar: return "$ … $"
        case .displayDollar: return "$$ … $$"
        case .inlineParen: return "\\( … \\)"
        case .displayBracket: return "\\[ … \\]"
        case .custom: return "custom"
        }
    }

    var pair: (String, String) {
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

enum Delimiters {
    static func resolve(preset: DelimiterPreset, open: String?, close: String?) -> (String, String) {
        if preset == .custom {
            return (open ?? "", close ?? "")
        }
        return preset.pair
    }

    static func stripExisting(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pairs = [("$$", "$$"), ("$", "$"), ("\\[", "\\]"), ("\\(", "\\)")]
        for (a, b) in pairs {
            if s.hasPrefix(a), s.hasSuffix(b), s.count >= a.count + b.count {
                s = String(s.dropFirst(a.count).dropLast(b.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return s
            }
        }
        return s
    }

    static func wrap(_ latex: String, open: String, close: String) -> String {
        let body = stripExisting(latex)
        if open.isEmpty && close.isEmpty { return body }
        return "\(open)\(body)\(close)"
    }
}
