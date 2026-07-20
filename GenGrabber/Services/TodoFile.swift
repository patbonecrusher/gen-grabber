import Foundation

/// Reads and writes the folder's `todo.md` — a plain Markdown checklist, so the tasks are
/// readable (and editable) straight from Finder, Quick Look, or any text editor.
///
///     # To Do
///
///     - [ ] Find Marie's sepulture
///     - [x] Check the LaFrance parish
enum TodoFile {
    static let filename = "todo.md"
    private static let heading = "# To Do"

    /// Parses every Markdown task line, ignoring anything else in the file (headings, blank
    /// lines, prose). A line is a task when it reads `- [ ]` / `- [x]` (or `*` / `+` bullets).
    static func parse(_ text: String) -> [TodoItem] {
        var todos: [TodoItem] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let bullet = line.first, "-*+".contains(bullet) else { continue }

            let afterBullet = line.dropFirst().trimmingCharacters(in: .whitespaces)
            guard afterBullet.hasPrefix("["), afterBullet.count >= 3 else { continue }

            let markIndex = afterBullet.index(afterBullet.startIndex, offsetBy: 1)
            let closeIndex = afterBullet.index(afterBullet.startIndex, offsetBy: 2)
            guard afterBullet[closeIndex] == "]" else { continue }

            let mark = afterBullet[markIndex]
            let done = mark == "x" || mark == "X"
            guard done || mark == " " else { continue }

            let text = afterBullet[afterBullet.index(after: closeIndex)...]
                .trimmingCharacters(in: .whitespaces)
            todos.append(TodoItem(text: text, done: done))
        }
        return todos
    }

    /// Renders the checklist, dropping rows that were added but never typed into.
    /// Returns nil when there is nothing worth writing a file for.
    static func render(_ todos: [TodoItem]) -> String? {
        let lines = todos
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "- [\($0.done ? "x" : " ")] \($0.text.trimmingCharacters(in: .whitespaces))" }
        guard !lines.isEmpty else { return nil }
        return "\(heading)\n\n" + lines.joined(separator: "\n") + "\n"
    }

    static func load(from folderURL: URL) -> [TodoItem] {
        let url = folderURL.appendingPathComponent(filename)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parse(text)
    }
}
