import SwiftUI

@Observable
final class SessionModel: @unchecked Sendable {
    var people: [Person] = []
    var tabs: [RecordTab] = []
    var notes: String = ""
    var selectedTabID: UUID?

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
        selectedTabID = tab.id
    }

    func removeTab(_ id: UUID) {
        tabs.removeAll { $0.id == id }
        if selectedTabID == id {
            selectedTabID = tabs.first?.id
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

    func clearAll() {
        people.removeAll()
        tabs.removeAll()
        notes = ""
        selectedTabID = nil
    }

    var totalImageCount: Int {
        tabs.reduce(0) { count, tab in
            var n = tab.lafranceImage != nil ? 1 : 0
            for page in tab.pages {
                if page.recordImage != nil { n += 1 }
                if page.closeupImage != nil { n += 1 }
            }
            return count + n
        }
    }
}
