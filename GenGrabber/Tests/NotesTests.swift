import Foundation
import Testing
@testable import GenGrabber

@Suite("Notes")
struct NotesTests {
    private func makeFolder(_ files: [String: String]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gengrabber-notes-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (name, content) in files {
            try content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        return dir
    }

    @Test("New notes are saved as Markdown")
    func filenameIsMarkdown() {
        #expect(Note(title: "tremblay-jean").filename == "tremblay-jean.md")
        #expect(Note(title: "").filename == "notes.md")
    }

    @Test("Markdown notes load by title")
    func loadsMarkdownNote() throws {
        let dir = try makeFolder(["research.md": "# Findings\n\n- baptised 1812"])
        defer { try? FileManager.default.removeItem(at: dir) }

        let note = try #require(FolderLoader.load(from: dir).notes.first { $0.title == "research" })
        #expect(note.content.contains("baptised 1812"))
        #expect(note.filename == "research.md")
    }

    @Test("An existing .txt note keeps its .txt extension")
    func textNotesStayText() throws {
        let dir = try makeFolder(["sources.txt": "Old plain-text note"])
        defer { try? FileManager.default.removeItem(at: dir) }

        let note = try #require(FolderLoader.load(from: dir).notes.first { $0.title == "sources" })
        #expect(note.content == "Old plain-text note")
        // It must be written back exactly where it came from, not converted to Markdown.
        #expect(note.filename == "sources.txt")
    }

    @Test("A .txt and a .md of the same name stay separate notes")
    func textAndMarkdownCoexist() throws {
        let dir = try makeFolder([
            "research.txt": "text version",
            "research.md": "markdown version",
        ])
        defer { try? FileManager.default.removeItem(at: dir) }

        let notes = FolderLoader.load(from: dir).notes.filter { $0.title == "research" }
        #expect(notes.count == 2)
        #expect(Set(notes.map(\.filename)) == ["research.txt", "research.md"])
    }

    @Test("todo.md is not loaded as a note")
    func todoIsNotANote() throws {
        let dir = try makeFolder(["todo.md": "- [ ] Find the will"])
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = FolderLoader.load(from: dir)
        #expect(result.notes.allSatisfy { $0.title != "todo" })
        #expect(result.todos.count == 1)
    }
}
