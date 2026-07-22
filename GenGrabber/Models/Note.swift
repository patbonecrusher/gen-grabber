import Foundation

struct Note: Identifiable, Sendable, Equatable {
    let id: UUID
    var title: String
    var content: String
    /// The extension this note is written under. New notes are Markdown; a note read from
    /// disk keeps whatever it already was, so an existing lineage.txt stays lineage.txt.
    var fileExtension: String

    init(id: UUID = UUID(), title: String = "", content: String = "", fileExtension: String = "md") {
        self.id = id
        self.title = title
        self.content = content
        self.fileExtension = fileExtension
    }

    var filename: String {
        let name = title.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return "notes.\(fileExtension)" }
        return "\(name).\(fileExtension)"
    }
}
