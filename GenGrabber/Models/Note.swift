import Foundation

struct Note: Identifiable, Sendable, Equatable {
    let id: UUID
    var title: String
    var content: String

    init(id: UUID = UUID(), title: String = "", content: String = "") {
        self.id = id
        self.title = title
        self.content = content
    }

    var filename: String {
        let name = title.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return "notes.txt" }
        return "\(name).txt"
    }
}
