import Foundation

/// Tidies Texo's raw output (space-separated tokens in KaTeX-normalized style)
/// into LaTeX a person would write: `x ={\frac{1}{2}}` → `x=\frac{1}{2}`,
/// `\operatorname*{l i m }` → `\lim`. Every rule keeps the rendering the same.
public enum LatexCleanup {
    public static func tidy(_ raw: String) -> String {
        var s = joinTokens(raw)
        s = replaceKatexOnly(s)
        s = s.replacingOccurrences(of: "\\!", with: "")
        s = s.replacingOccurrences(of: "~", with: "\\,")
        s = useNamedOperators(s)
        s = useMatrixEnvironments(s)
        s = removeRedundantBraces(s)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Drop the separator spaces, keeping one only where LaTeX needs it
    /// (a control word followed by a letter or digit) and after `\\`.
    static func joinTokens(_ raw: String) -> String {
        let tokens = raw.split(whereSeparator: \.isWhitespace).map(String.init)
        var out = ""
        for (i, token) in tokens.enumerated() {
            out += token
            guard i + 1 < tokens.count else { break }
            let next = tokens[i + 1]
            if token == "\\\\" {
                out += " "
            } else if isControlWord(token), let c = next.first, c.isLetter || c.isNumber {
                out += " "
            }
        }
        return out
    }

    static func isControlWord(_ token: String) -> Bool {
        guard token.count > 1, token.first == "\\" else { return false }
        return token.dropFirst().allSatisfy(\.isLetter)
    }

    /// KaTeX accepts these; pdfLaTeX doesn't. Same mapping as Texo-web.
    static let katexOnly = [
        "infin": "infty", "rarr": "rightarrow", "larr": "leftarrow", "harr": "leftrightarrow",
        "Rarr": "Rightarrow", "Larr": "Leftarrow", "Harr": "Leftrightarrow",
        "darr": "downarrow", "uarr": "uparrow",
    ]

    static func replaceKatexOnly(_ s: String) -> String {
        replacing(#"\\([A-Za-z]+)"#, in: s) { m in
            katexOnly[m[1]].map { "\\" + $0 } ?? m[0]
        }
    }

    /// Standard operator names with their own commands.
    static let operators: Set<String> = [
        "lim", "limsup", "liminf", "sin", "cos", "tan", "cot", "sec", "csc",
        "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh", "coth",
        "log", "ln", "lg", "exp", "det", "dim", "ker", "max", "min", "sup", "inf",
        "arg", "deg", "gcd", "hom", "Pr",
    ]

    /// `\operatorname*{lim}` → `\lim` (space added if a letter follows).
    static func useNamedOperators(_ s: String) -> String {
        replacing(#"\\operatorname\*?\{([A-Za-z]+)\}(?=([A-Za-z0-9]?))"#, in: s) { m in
            guard operators.contains(m[1]) else { return m[0] }
            return "\\" + m[1] + (m[2].isEmpty ? "" : " ")
        }
    }

    /// `\left(\begin{array}{cc}…\end{array}\right)` → `\begin{pmatrix}…\end{pmatrix}`,
    /// and `\left\{\begin{array}{ll}…\end{array}\right.` → `cases`.
    static func useMatrixEnvironments(_ s: String) -> String {
        let forms: [(open: String, close: String, env: String)] = [
            (#"\left("#, #"\right)"#, "pmatrix"),
            (#"\left["#, #"\right]"#, "bmatrix"),
            (#"\left|"#, #"\right|"#, "vmatrix"),
            (#"\left\|"#, #"\right\|"#, "Vmatrix"),
            (#"\left\{"#, #"\right."#, "cases"),
        ]
        var s = s
        for f in forms {
            let pattern = NSRegularExpression.escapedPattern(for: f.open)
                + #"\\begin\{array\}\{[lcr]+\}((?:(?!\\begin\{array\}).)*?)\\end\{array\}"#
                + NSRegularExpression.escapedPattern(for: f.close)
            s = replacing(pattern, in: s) { m in "\\begin{\(f.env)}\(m[1])\\end{\(f.env)}" }
        }
        return s
    }

    /// Commands Texo wraps in an extra group: `={\frac{a}{b}}`.
    static let unwrapStarts = [
        "\\frac", "\\dfrac", "\\tfrac", "\\sqrt", "\\binom", "\\left", "\\begin", "\\mathrm",
        "\\mathbf", "\\mathit", "\\mathcal", "\\mathbb", "\\hat", "\\bar", "\\tilde", "\\vec",
        "\\overline",
    ]
    /// Accents: a script after the group belongs to the whole group, so keep it.
    static let accents: Set<String> = ["\\hat", "\\bar", "\\tilde", "\\vec", "\\overline"]

    /// Commands whose `{…}` arguments must stay braced.
    static let takesArguments: Set<String> = [
        "frac", "dfrac", "tfrac", "sqrt", "binom", "mathrm", "mathbf", "mathit", "mathcal", "mathbb",
        "mathsf", "mathtt", "mathfrak", "boldsymbol", "text", "textrm", "textbf", "textit",
        "operatorname", "hat", "bar", "tilde", "vec", "dot", "ddot", "overline", "underline",
        "overbrace", "underbrace", "widehat", "widetilde", "begin", "end", "stackrel", "overset",
        "underset", "color", "textcolor", "xrightarrow", "xleftarrow", "pmod", "substack",
    ]

    /// Remove braces that change nothing:
    /// - around a group starting with one of `unwrapStarts` (`={\frac{a}{b}}`),
    ///   unless the braces are an argument of the preceding command;
    /// - around matrix/cases cells (`{a}&{b}\\ {c}&{d}`).
    static func removeRedundantBraces(_ s: String) -> String {
        var chars = Array(s)
        var i = 0
        while i < chars.count {
            guard chars[i] == "{", !isEscaped(chars, i), let close = matchingBrace(chars, from: i) else {
                i += 1
                continue
            }
            let inner = String(chars[(i + 1)..<close])
            let after = close + 1 < chars.count ? chars[close + 1] : " "
            let start = unwrapStarts.first { startsWithCommand(inner, $0) }
            let unwrap: Bool
            if isCell(chars, open: i, close: close) {
                unwrap = true
            } else if let start, !couldBeArgument(chars, open: i) {
                unwrap = !(accents.contains(start) && "^_'".contains(after))
            } else {
                unwrap = false
            }
            if unwrap {
                chars.remove(at: close)
                chars.remove(at: i)
                continue // re-check the same position: groups can nest
            }
            i += 1
        }
        return String(chars)
    }

    /// Could the group opening at `open` be an argument of what precedes it?
    static func couldBeArgument(_ chars: [Character], open: Int) -> Bool {
        guard open > 0 else { return false }
        let before = chars[open - 1]
        if "^_]*".contains(before) { return true }
        if before == "}" {
            // After a script group (`^{…}{\frac…}`) it can't be an argument;
            // after any other group (`\frac{a}{…}`) it might be.
            guard let o = matchingOpenBrace(chars, close: open - 1) else { return true }
            return !(o > 0 && "^_".contains(chars[o - 1]))
        }
        if before.isLetter {
            var j = open - 1
            while j >= 0, chars[j].isLetter { j -= 1 }
            guard j >= 0, chars[j] == "\\", !isEscaped(chars, j) else { return true } // plain letters
            return takesArguments.contains(String(chars[(j + 1)..<open]))
        }
        return false
    }

    /// A group that is a whole cell of a matrix/cases/array row.
    static func isCell(_ chars: [Character], open: Int, close: Int) -> Bool {
        let before = String(chars[..<open]).trimmingCharacters(in: .whitespaces)
        let after = String(chars[(close + 1)...]).trimmingCharacters(in: .whitespaces)
        let startsCell = before.hasSuffix("&") || before.hasSuffix("\\\\")
            || before.range(of: #"\\begin\{(?:[pbvV]?matrix|cases|array\}\{[lcr|]*)\}$"#, options: .regularExpression) != nil
        let endsCell = after.hasPrefix("&") || after.hasPrefix("\\\\") || after.hasPrefix("\\end{")
        return startsCell && endsCell
    }

    private static func startsWithCommand(_ s: String, _ command: String) -> Bool {
        guard s.hasPrefix(command) else { return false }
        let rest = s.dropFirst(command.count)
        return rest.first.map { !$0.isLetter } ?? true
    }

    private static func isEscaped(_ chars: [Character], _ i: Int) -> Bool {
        var n = 0
        var j = i - 1
        while j >= 0, chars[j] == "\\" { n += 1; j -= 1 }
        return n % 2 == 1
    }

    private static func matchingOpenBrace(_ chars: [Character], close: Int) -> Int? {
        var depth = 0
        var j = close
        while j >= 0 {
            if !isEscaped(chars, j) {
                if chars[j] == "}" { depth += 1 }
                if chars[j] == "{" {
                    depth -= 1
                    if depth == 0 { return j }
                }
            }
            j -= 1
        }
        return nil
    }

    private static func matchingBrace(_ chars: [Character], from open: Int) -> Int? {
        var depth = 0
        for j in open..<chars.count where !isEscaped(chars, j) {
            if chars[j] == "{" { depth += 1 }
            if chars[j] == "}" {
                depth -= 1
                if depth == 0 { return j }
            }
        }
        return nil
    }

    private static func replacing(_ pattern: String, in s: String, _ transform: ([String]) -> String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return s }
        let ns = s as NSString
        var out = ""
        var last = 0
        for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let groups = (0..<m.numberOfRanges).map { i -> String in
                let r = m.range(at: i)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
            out += transform(groups)
            last = m.range.location + m.range.length
        }
        out += ns.substring(from: last)
        return out
    }
}
