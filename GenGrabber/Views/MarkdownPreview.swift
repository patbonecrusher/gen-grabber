import AppKit
import SwiftUI

/// Colors for the rendered note: a warm parchment palette that reads like the aged paper the
/// records come from, plus a matching low-glare dark variant.
///
/// Each color is a dynamic `NSColor`, so it resolves against whatever appearance it is drawn
/// in. Deriving them from `@Environment(\.colorScheme)` instead would silently fall back to
/// light whenever a color is read outside the view hierarchy.
struct MarkdownTheme {
    let background: Color
    let text: Color
    let secondaryText: Color
    let heading: Color
    let accent: Color
    let rule: Color
    let code: Color
    let codeBackground: Color
    let link: Color
    let quoteBar: Color
    let quoteText: Color

    static let parchment = MarkdownTheme(
        background: .dynamic(light: 0xFBF7EF, dark: 0x1B1917),      // aged paper / near-black
        text: .dynamic(light: 0x2E2A26, dark: 0xE6DFD4),            // warm ink
        secondaryText: .dynamic(light: 0x7E7367, dark: 0x9C9385),
        heading: .dynamic(light: 0x5B3A29, dark: 0xE0B589),         // sepia / warm gold
        accent: .dynamic(light: 0xA67B5B, dark: 0xC79C73),          // tan
        rule: .dynamic(light: 0xD9CFBF, dark: 0x3D3833),
        code: .dynamic(light: 0x8A4B2A, dark: 0xD9A066),            // rust
        codeBackground: .dynamic(light: 0xF0E9DC, dark: 0x2A2623),
        link: .dynamic(light: 0x0B6E99, dark: 0x6FB3D2),            // ink blue
        quoteBar: .dynamic(light: 0xC8B398, dark: 0x5A4F42),
        quoteText: .dynamic(light: 0x5D5549, dark: 0xBDB4A7)
    )
}

private extension Color {
    /// A color that follows the window's appearance, given a light and a dark hex value.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}


/// Splits Markdown into the block structure the preview lays out. Kept free of SwiftUI so the
/// rules are testable on their own.
enum MarkdownBlockParser {
    enum Block: Equatable {
        case heading(level: Int, text: String)
        case bullet(marker: String, text: String)
        case task(text: String, done: Bool)
        case quote(text: String)
        case codeBlock(lines: [String])
        case rule
        case blank
        case paragraph(text: String)
    }

    static func blocks(of text: String) -> [Block] {
        var result: [Block] = []
        var codeLines: [String]?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // Fenced code blocks swallow everything until the closing ```.
            if line.hasPrefix("```") {
                if let lines = codeLines {
                    result.append(.codeBlock(lines: lines))
                    codeLines = nil
                } else {
                    codeLines = []
                }
                continue
            }
            if codeLines != nil {
                codeLines?.append(rawLine)
                continue
            }

            result.append(classify(line))
        }
        // An unterminated fence still renders what it collected.
        if let lines = codeLines { result.append(.codeBlock(lines: lines)) }
        return result
    }

    static func classify(_ line: String) -> Block {
        if line.isEmpty { return .blank }
        if line.count >= 3, line.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }) { return .rule }
        if line.hasPrefix("#") {
            let level = line.prefix(while: { $0 == "#" }).count
            let text = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
            return .heading(level: min(level, 3), text: text)
        }
        if line.hasPrefix(">") {
            return .quote(text: line.dropFirst().trimmingCharacters(in: .whitespaces))
        }
        if let bullet = line.first, "-*+".contains(bullet) {
            let rest = line.dropFirst().trimmingCharacters(in: .whitespaces)
            if rest.hasPrefix("[ ] ") { return .task(text: String(rest.dropFirst(4)), done: false) }
            if rest.lowercased().hasPrefix("[x] ") { return .task(text: String(rest.dropFirst(4)), done: true) }
            return .bullet(marker: "•", text: rest)
        }
        // Ordered list: "1. text". Capped at three digits so a note that opens a sentence with
        // a year ("1812. Born in Sorel") stays a paragraph.
        if let dot = line.firstIndex(of: "."),
           line[line.startIndex..<dot].allSatisfy(\.isNumber),
           line.startIndex != dot,
           line.distance(from: line.startIndex, to: dot) <= 3,
           line.index(after: dot) < line.endIndex {
            let number = String(line[line.startIndex..<dot])
            let rest = line[line.index(after: dot)...].trimmingCharacters(in: .whitespaces)
            return .bullet(marker: "\(number).", text: rest)
        }
        return .paragraph(text: line)
    }

}

/// Renders a note's Markdown for reading. SwiftUI's `AttributedString(markdown:)` only handles
/// inline syntax (bold, italic, links, code), so block structure — headings, lists, quotes,
/// fenced code, rules — is laid out line by line here and each line's inline syntax styled
/// within it.
struct MarkdownPreview: View {
    let text: String
    private let theme = MarkdownTheme.parchment

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(MarkdownBlockParser.blocks(of: text).enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(theme.text)
        .textSelection(.enabled)
    }

    /// The parchment page the note is drawn on. The caller applies it so it fills the whole
    /// pane rather than just the text's bounds.
    static var pageBackground: Color { MarkdownTheme.parchment.background }

    // MARK: - Rendering

    @ViewBuilder
    private func view(for block: MarkdownBlockParser.Block) -> some View {
        switch block {
        case .heading(let level, let text):
            VStack(alignment: .leading, spacing: 3) {
                inline(text)
                    .font(level == 1 ? .title2 : level == 2 ? .title3 : .headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.heading)
                // A hairline under the top-level heading, like a title page rule.
                if level == 1 {
                    Rectangle()
                        .fill(theme.rule)
                        .frame(height: 1)
                }
            }
            .padding(.top, level == 1 ? 2 : 6)

        case .bullet(let marker, let text):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(marker)
                    .font(.body)
                    .foregroundStyle(theme.accent)
                inline(text)
            }
            .padding(.leading, 4)

        case .task(let text, let done):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Image(systemName: done ? "checkmark.square.fill" : "square")
                    .foregroundStyle(done ? theme.accent : theme.secondaryText)
                inline(text)
                    .strikethrough(done, color: theme.secondaryText)
                    .foregroundStyle(done ? theme.secondaryText : theme.text)
            }
            .padding(.leading, 4)

        case .quote(let text):
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(theme.quoteBar)
                    .frame(width: 3)
                inline(text)
                    .italic()
                    .foregroundStyle(theme.quoteText)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .codeBlock(let lines):
            Text(lines.joined(separator: "\n"))
                .font(.callout.monospaced())
                .foregroundStyle(theme.code)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.codeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))

        case .rule:
            Rectangle()
                .fill(theme.rule)
                .frame(height: 1)
                .padding(.vertical, 4)

        case .blank:
            Spacer().frame(height: 2)

        case .paragraph(let text):
            inline(text)
        }
    }

    /// Renders one line's inline Markdown, tinting code spans and links to the theme.
    /// Falls back to the literal text if the line doesn't parse.
    private func inline(_ line: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        guard var attributed = try? AttributedString(markdown: line, options: options) else {
            return Text(line)
        }

        // Collect first, then restyle — mutating while iterating runs invalidates them.
        var codeRanges: [Range<AttributedString.Index>] = []
        var linkRanges: [Range<AttributedString.Index>] = []
        for run in attributed.runs {
            if run.inlinePresentationIntent?.contains(.code) == true { codeRanges.append(run.range) }
            if run.link != nil { linkRanges.append(run.range) }
        }
        for range in codeRanges {
            attributed[range].font = .callout.monospaced()
            attributed[range].foregroundColor = theme.code
            attributed[range].backgroundColor = theme.codeBackground
        }
        for range in linkRanges {
            attributed[range].foregroundColor = theme.link
            attributed[range].underlineStyle = .single
        }
        return Text(attributed)
    }
}
