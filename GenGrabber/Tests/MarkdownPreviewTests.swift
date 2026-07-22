import Foundation
import Testing
@testable import GenGrabber

@Suite("MarkdownPreview")
struct MarkdownPreviewTests {
    private func blocks(_ text: String) -> [MarkdownBlockParser.Block] {
        MarkdownBlockParser.blocks(of: text)
    }

    @Test("Headings, bullets, tasks, quotes and rules are recognized")
    func classifiesBlocks() {
        #expect(MarkdownBlockParser.classify("# Findings") == .heading(level: 1, text: "Findings"))
        #expect(MarkdownBlockParser.classify("### Deep") == .heading(level: 3, text: "Deep"))
        // Deeper levels clamp to the smallest heading style.
        #expect(MarkdownBlockParser.classify("##### Deeper") == .heading(level: 3, text: "Deeper"))
        #expect(MarkdownBlockParser.classify("- baptised 1812") == .bullet(marker: "•", text: "baptised 1812"))
        #expect(MarkdownBlockParser.classify("2. second") == .bullet(marker: "2.", text: "second"))
        #expect(MarkdownBlockParser.classify("- [x] done") == .task(text: "done", done: true))
        #expect(MarkdownBlockParser.classify("- [ ] todo") == .task(text: "todo", done: false))
        #expect(MarkdownBlockParser.classify("> quoted") == .quote(text: "quoted"))
        #expect(MarkdownBlockParser.classify("---") == .rule)
        #expect(MarkdownBlockParser.classify("") == .blank)
        #expect(MarkdownBlockParser.classify("Born in Sorel") == .paragraph(text: "Born in Sorel"))
    }

    @Test("A sentence opening with a year is not an ordered list")
    func yearIsNotAListMarker() {
        #expect(MarkdownBlockParser.classify("1812. Born in Sorel") == .paragraph(text: "1812. Born in Sorel"))
    }

    @Test("Fenced code blocks are collected verbatim")
    func fencedCode() {
        let parsed = blocks("""
        Before
        ```
        - not a bullet
        # not a heading
        ```
        After
        """)

        #expect(parsed.first == .paragraph(text: "Before"))
        #expect(parsed.contains(.codeBlock(lines: ["- not a bullet", "# not a heading"])))
        #expect(parsed.last == .paragraph(text: "After"))
    }

    @Test("An unterminated fence still renders what it collected")
    func unterminatedFence() {
        #expect(blocks("```\nlet x = 1").contains(.codeBlock(lines: ["let x = 1"])))
    }
}
