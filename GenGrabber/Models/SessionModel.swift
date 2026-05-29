import SwiftUI

enum TabSelection: Equatable {
    case record(UUID)
    case notes
    case summary
}

@Observable
final class SessionModel: @unchecked Sendable {
    var people: [Person] = []
    var tabs: [RecordTab] = []
    var notes: String = ""
    var selection: TabSelection = .notes
    var summary: SessionSummary = SessionSummary()

    func addPerson() {
        people.append(Person())
    }

    func removePerson(_ id: UUID) {
        guard !isPersonReferenced(id) else { return }
        people.removeAll { $0.id == id }
    }

    func isPersonReferenced(_ id: UUID) -> Bool {
        tabs.contains { $0.personIDs.contains(id) }
    }

    func addTab(type: RecordType, personIDs: [UUID]) {
        let tab = RecordTab(recordType: type, personIDs: personIDs)
        tabs.append(tab)
        selection = .record(tab.id)
    }

    func removeTab(_ id: UUID) {
        tabs.removeAll { $0.id == id }
        if selection == .record(id) {
            selection = tabs.first.map { .record($0.id) } ?? .notes
        }
    }

    func person(for id: UUID) -> Person? {
        people.first { $0.id == id }
    }

    func tabLabel(for tab: RecordTab) -> String {
        let names = tab.personIDs.compactMap { person(for: $0) }
        switch tab.recordType {
        case .wedding:
            let groom = names.first.map { $0.firstName } ?? "?"
            let bride = names.dropFirst().first.map { $0.firstName } ?? "?"
            return "W: \(groom) + \(bride)"
        case .birth:
            let name = names.first.map { $0.firstName } ?? "?"
            return "B: \(name)"
        case .sepulture:
            let name = names.first.map { $0.firstName } ?? "?"
            return "S: \(name)"
        }
    }

    func loadFromResult(_ result: FolderLoader.LoadResult) {
        clearAll()
        people = result.people
        tabs = result.tabs
        notes = result.notes
        summary = result.summary
        selection = tabs.first.map { .record($0.id) } ?? .notes
    }

    func clearAll() {
        people.removeAll()
        tabs.removeAll()
        notes = ""
        summary = SessionSummary()
        selection = .notes
    }

    var totalImageCount: Int {
        tabs.reduce(0) { count, tab in
            var n = tab.lafranceImage != nil ? 1 : 0
            for page in tab.pages {
                if page.recordImage != nil { n += 1 }
                n += page.closeupImages.compactMap({ $0 }).count
            }
            return count + n
        }
    }
}
