import Foundation
import Testing
@testable import GenGrabber

@Suite("Todos")
struct TodoTests {
    @Test("Parses Markdown task lines and their checked state")
    func parsesTasks() {
        let todos = TodoFile.parse("""
        # To Do

        - [ ] Find Marie's sepulture
        - [x] Check the LaFrance parish
        """)

        #expect(todos.count == 2)
        #expect(todos[0].text == "Find Marie's sepulture")
        #expect(todos[0].done == false)
        #expect(todos[1].text == "Check the LaFrance parish")
        #expect(todos[1].done == true)
    }

    @Test("Accepts hand-edited variations and ignores non-task lines")
    func parsesHandEdits() {
        let todos = TodoFile.parse("""
        Some prose someone typed in Finder.

        * [X] Uppercase X, star bullet
          + [ ] Indented plus bullet
        - not a task
        - [] malformed
        """)

        #expect(todos.map(\.text) == ["Uppercase X, star bullet", "Indented plus bullet"])
        #expect(todos[0].done == true)
        #expect(todos[1].done == false)
    }

    @Test("Renders a checklist and round-trips through parse")
    func roundTrip() throws {
        let original = [
            TodoItem(text: "Find Marie's sepulture", done: false),
            TodoItem(text: "Check the LaFrance parish", done: true),
        ]
        let markdown = try #require(TodoFile.render(original))
        #expect(markdown.hasPrefix("# To Do\n\n"))
        #expect(markdown.contains("- [ ] Find Marie's sepulture"))
        #expect(markdown.contains("- [x] Check the LaFrance parish"))

        let reparsed = TodoFile.parse(markdown)
        #expect(reparsed.map(\.text) == original.map(\.text))
        #expect(reparsed.map(\.done) == original.map(\.done))
    }

    @Test("Blank rows are never written, and an all-blank list writes no file")
    func skipsBlankRows() throws {
        #expect(TodoFile.render([]) == nil)
        #expect(TodoFile.render([TodoItem(text: "   ")]) == nil)

        let markdown = try #require(TodoFile.render([TodoItem(text: ""), TodoItem(text: "Real task")]))
        #expect(TodoFile.parse(markdown).map(\.text) == ["Real task"])
    }

    @Test("A folder's todo.md loads back into the session")
    func loadsFromFolder() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gengrabber-todo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try "- [ ] Trace the Acadian line\n"
            .write(to: dir.appendingPathComponent("todo.md"), atomically: true, encoding: .utf8)

        let result = FolderLoader.load(from: dir)
        #expect(result.todos.map(\.text) == ["Trace the Acadian line"])
        // todo.md is Markdown, so it must not also surface as a note or an "other" file.
        #expect(result.notes.allSatisfy { $0.title != "todo" })
        #expect(result.otherFiles.files.isEmpty)
    }

    @MainActor
    @Test("Open count ignores done and blank rows")
    func openCount() {
        let session = SessionModel()
        session.todos = [
            TodoItem(text: "Find the will", done: false),
            TodoItem(text: "Done already", done: true),
            TodoItem(text: "   ", done: false),
        ]
        #expect(session.openTodoCount == 1)

        session.clearCompletedTodos()
        #expect(session.todos.count == 2)
    }
}
