import Foundation

/// A follow-up task for the open folder (e.g. "find Marie's sepulture"), persisted in
/// summary.json so it survives closing the folder and is queryable outside the app.
struct TodoItem: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    var text: String
    var done: Bool

    init(id: UUID = UUID(), text: String = "", done: Bool = false) {
        self.id = id
        self.text = text
        self.done = done
    }
}
