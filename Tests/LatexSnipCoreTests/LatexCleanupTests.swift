import XCTest
@testable import LatexSnipCore

final class LatexCleanupTests: XCTestCase {
    /// Raw Texo output for benchmark snips → what a person would write.
    func testRealModelOutputs() {
        let cases: [(String, String)] = [
            (#"\int _ { 0 } ^ { \infin } e ^ { - x ^ { 2 } } ~ d x = { \frac { \sqrt { \pi } } { 2 } }"#,
             #"\int_{0}^{\infty}e^{-x^{2}}\,dx=\frac{\sqrt{\pi}}{2}"#),  // r01
            (#"\sum _ { n = 1 } ^ { \infin } { \frac { 1 } { n ^ { 2 } } } = { \frac { \pi ^ { 2 } } { 6 } }"#,
             #"\sum_{n=1}^{\infty}\frac{1}{n^{2}}=\frac{\pi^{2}}{6}"#),  // r02
            (#"{ \left ( \begin{array} { c c } { a } & { b } \\ { c } & { d } \end{array} \right ) } ^ { - 1 } = { \frac { 1 } { a d - b c } } \left ( \begin{array} { c c } { d } & { - b } \\ { - c } & { a } \end{array} \right )"#,
             #"\begin{pmatrix}a&b\\ c&d\end{pmatrix}^{-1}=\frac{1}{ad-bc}\begin{pmatrix}d&-b\\ -c&a\end{pmatrix}"#),  // r03
            (#"f ^ { \prime } ( x ) = \operatorname* { l i m } _ { h \rarr 0 } { \frac { f ( x + h ) - f ( x ) } { h } }"#,
             #"f^{\prime}(x)=\lim_{h\rightarrow 0}\frac{f(x+h)-f(x)}{h}"#),  // r04
            (#"E = m c ^ { 2 }"#,
             #"E=mc^{2}"#),  // s01
            (#"x = { \frac { - b \pm { \sqrt { b ^ { 2 } - 4 a c } } } { 2 a } }"#,
             #"x=\frac{-b\pm\sqrt{b^{2}-4ac}}{2a}"#),  // s03
            (#"P ( A \mid B ) = { \frac { P ( B \mid A ) ~ P ( A ) } { P ( B ) } }"#,
             #"P(A\mid B)=\frac{P(B\mid A)\,P(A)}{P(B)}"#),  // s04
            (#"| x | = { \left \{ \begin{array} { l l } { x } & { x \geq 0 } \\ { - x } & { x < 0 } \end{array} \right . }"#,
             #"|x|=\begin{cases}x&x\geq 0\\ -x&x<0\end{cases}"#),  // s07
            (#"\begin{array} { l } { ( a + b ) ^ { 2 } = a ^ { 2 } + 2 a b + b ^ { 2 } } \\ { ( a - b ) ^ { 2 } = a ^ { 2 } - 2 a b + b ^ { 2 } } \end{array}"#,
             #"\begin{array}{l}(a+b)^{2}=a^{2}+2ab+b^{2}\\ (a-b)^{2}=a^{2}-2ab+b^{2}\end{array}"#),  // s08
            (#"\operatorname* { l i m } _ { n \rarr \infin } \left ( 1 + { \frac { 1 } { n } } \right ) ^ { n } = e"#,
             #"\lim_{n\rightarrow\infty}\left(1+\frac{1}{n}\right)^{n}=e"#),  // s11
            (#"\operatorname* { d e t } { \left ( \begin{array} { l l } { a } & { b } \\ { c } & { d } \end{array} \right ) } = a d - b c"#,
             #"\det\begin{pmatrix}a&b\\ c&d\end{pmatrix}=ad-bc"#),  // s14
            (#"{ \frac { d } { d x } } \left [ \int _ { 0 } ^ { x } \sin ( t ^ { 2 } ) ~ d t \right ] + \sum _ { k = 1 } ^ { n } { \binom { n } { k } } x ^ { k } y ^ { n - k } = \sin ( x ^ { 2 } ) + ( x + y ) ^ { n } - y ^ { n }"#,
             #"\frac{d}{dx}\left[\int_{0}^{x}\sin(t^{2})\,dt\right]+\sum_{k=1}^{n}\binom{n}{k}x^{k}y^{n-k}=\sin(x^{2})+(x+y)^{n}-y^{n}"#),  // w02
            (#"L ( \theta ) = - \frac { 1 } { N } \sum _ { i = 1 } ^ { N } \left [ y _ { i } \log \hat { y } _ { i } + ( 1 - y _ { i } ) \log ( 1 - \hat { y } _ { i } ) \right ] + \lambda \| \theta \| _ { 2 } ^ { 2 }"#,
             #"L(\theta)=-\frac{1}{N}\sum_{i=1}^{N}\left[y_{i}\log\hat{y}_{i}+(1-y_{i})\log(1-\hat{y}_{i})\right]+\lambda\|\theta\|_{2}^{2}"#),  // w03
        ]
        for (raw, expected) in cases {
            XCTAssertEqual(LatexCleanup.tidy(raw), expected, raw)
        }
    }

    func testJoinKeepsSpaceAfterControlWordBeforeLetterOrDigit() {
        XCTAssertEqual(LatexCleanup.joinTokens(#"\alpha x + \beta 2"#), #"\alpha x+\beta 2"#)
        XCTAssertEqual(LatexCleanup.joinTokens(#"\frac { 1 } { 2 }"#), #"\frac{1}{2}"#)
        XCTAssertEqual(LatexCleanup.joinTokens(#"a \\ b"#), #"a\\ b"#)
    }

    func testKatexOnlyCommands() {
        XCTAssertEqual(LatexCleanup.tidy(#"n \rarr \infin"#), #"n\rightarrow\infty"#)
        XCTAssertEqual(LatexCleanup.tidy(#"\infinity"#), #"\infinity"#)
    }

    func testNamedOperators() {
        XCTAssertEqual(LatexCleanup.tidy(#"\operatorname { s i n } x"#), #"\sin x"#)
        XCTAssertEqual(LatexCleanup.tidy(#"\operatorname* { l i m } _ { n }"#), #"\lim_{n}"#)
        XCTAssertEqual(LatexCleanup.tidy(#"\operatorname { f o o } ( x )"#), #"\operatorname{foo}(x)"#)
    }

    func testSpacingCommands() {
        XCTAssertEqual(LatexCleanup.tidy(#"f ( x ) ~ d x"#), #"f(x)\,dx"#)
        XCTAssertEqual(LatexCleanup.tidy(#"a \! b"#), #"ab"#)
    }

    func testBracesThatAreArgumentsStay() {
        XCTAssertEqual(LatexCleanup.tidy(#"\sqrt { \frac { 1 } { 2 } }"#), #"\sqrt{\frac{1}{2}}"#)
        XCTAssertEqual(LatexCleanup.tidy(#"\frac { a } { \frac { b } { c } }"#), #"\frac{a}{\frac{b}{c}}"#)
        XCTAssertEqual(LatexCleanup.tidy(#"x ^ { \frac { 1 } { 2 } }"#), #"x^{\frac{1}{2}}"#)
        XCTAssertEqual(LatexCleanup.tidy(#"\sqrt [ 3 ] { \frac { 1 } { 2 } }"#), #"\sqrt[3]{\frac{1}{2}}"#)
        XCTAssertEqual(LatexCleanup.tidy(#"\mathbf { \hat { x } }"#), #"\mathbf{\hat{x}}"#)
    }

    func testAccentGroupKeepsItsScript() {
        XCTAssertEqual(LatexCleanup.tidy(#"= { \hat { y } } _ { i }"#), #"={\hat{y}}_{i}"#)
        XCTAssertEqual(LatexCleanup.tidy(#"= { \frac { 1 } { 2 } } ^ { 2 }"#), #"=\frac{1}{2}^{2}"#)
    }

    func testOtherGroupsStay() {
        XCTAssertEqual(LatexCleanup.tidy(#"{ \rm d } x"#), #"{\rm d}x"#)
        XCTAssertEqual(LatexCleanup.tidy(#"{ a + b } ^ { 2 }"#), #"{a+b}^{2}"#)
    }

    func testMatrixEnvironments() {
        XCTAssertEqual(
            LatexCleanup.tidy(#"\left[ \begin{array} { c c } { 1 } & { 0 } \\ { 0 } & { 1 } \end{array} \right]"#),
            #"\begin{bmatrix}1&0\\ 0&1\end{bmatrix}"#
        )
        XCTAssertEqual(
            LatexCleanup.tidy(#"\left| \begin{array} { c c } { a } & { b } \end{array} \right|"#),
            #"\begin{vmatrix}a&b\end{vmatrix}"#
        )
    }

    /// Regression: `\cfrac{\mathrm{d}z}{z}` lost its numerator braces because
    /// `\cfrac` wasn't a known argument-taking command.
    func testArgumentsOfUnlistedCommandsKeepTheirBraces() {
        XCTAssertEqual(
            LatexCleanup.tidy(#"\int _ { a } ^ { b } { \cfrac { \mathrm { d } z } { z } } = \log b - \log a"#),
            #"\int_{a}^{b}\frac{\mathrm{d}z}{z}=\log b-\log a"#
        )
        XCTAssertEqual(LatexCleanup.tidy(#"\boxed { \frac { a } { b } }"#), #"\boxed{\frac{a}{b}}"#)
        XCTAssertEqual(LatexCleanup.tidy(#"\overrightarrow { \mathrm { A B } }"#), #"\overrightarrow{\mathrm{AB}}"#)
        XCTAssertEqual(LatexCleanup.tidy(#"\textcircled { \mathrm { a } }"#), #"\textcircled{\mathrm{a}}"#)
    }

    func testContinuedFractionKeepsCfrac() {
        XCTAssertEqual(
            LatexCleanup.tidy(#"x = \cfrac { 1 } { 1 + \cfrac { 1 } { x } }"#),
            #"x=\cfrac{1}{1+\cfrac{1}{x}}"#
        )
    }

    /// Every command Texo can emit: braces after it are kept unless it's known
    /// to take no argument, in which case a redundant group is removed.
    func testEveryVocabularyCommand() throws {
        struct File: Decodable { struct Model: Decodable { var vocab: [String: Int] }; var model: Model }
        let url = try texoModelDirectory().appendingPathComponent("tokenizer.json")
        let vocab = try JSONDecoder().decode(File.self, from: Data(contentsOf: url)).model.vocab.keys
        let commands = vocab.filter { LatexCleanup.isControlWord($0) }
        XCTAssertGreaterThan(commands.count, 500)
        for command in commands {
            let name = String(command.dropFirst())
            let shown = LatexCleanup.katexOnly[name] ?? name
            let out = LatexCleanup.tidy("\(command) { \\frac { a } { b } }")
            if LatexCleanup.takesNoArguments.contains(shown) {
                XCTAssertEqual(out, "\\\(shown)\\frac{a}{b}", command)
            } else {
                XCTAssertTrue(out.hasSuffix("{\\frac{a}{b}}"), "\(command) → \(out)")
            }
        }
    }
}
