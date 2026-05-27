import Foundation

struct PageFilenames: Sendable {
    let record: String
    let closeups: [String]
}

struct RecordFilenames: Sendable {
    let lafrance: String
    let pages: [PageFilenames]
}

enum FilenameBuilder {
    static func filenames(
        for tab: RecordTab,
        people: [Person],
        closeupCounts: [Int]? = nil
    ) -> RecordFilenames {
        let base = buildBase(for: tab, people: people)
        let firstRecordID = tab.pages.first?.recordID ?? ""
        let lafrance = "\(base)-\(firstRecordID)-lafrance.png"

        let pageFilenames = tab.pages.enumerated().map { index, page in
            let record = "\(base)-\(page.recordID).png"
            let count = closeupCounts?[safe: index] ?? 1
            let closeups: [String]
            if count <= 1 {
                closeups = ["\(base)-\(page.recordID)-closeup.png"]
            } else {
                closeups = (1...count).map { n in
                    "\(base)-\(page.recordID)-closeup-\(n).png"
                }
            }
            return PageFilenames(record: record, closeups: closeups)
        }

        return RecordFilenames(lafrance: lafrance, pages: pageFilenames)
    }

    private static func buildBase(for tab: RecordTab, people: [Person]) -> String {
        let type = tab.recordType.rawValue
        let year = tab.year

        switch tab.recordType {
        case .wedding:
            let groom = people.first { $0.id == tab.personIDs[safe: 0] }
            let bride = people.first { $0.id == tab.personIDs[safe: 1] }
            let groomName = formatName(groom)
            let brideName = formatName(bride)
            return "\(year)-(\(type))-\(groomName)-\(brideName)"
        case .birth, .sepulture:
            let person = people.first { $0.id == tab.personIDs[safe: 0] }
            let name = formatName(person)
            return "\(year)-(\(type))-\(name)"
        }
    }

    private static func formatName(_ person: Person?) -> String {
        guard let person else { return "unknown" }
        let last = normalize(person.lastName)
        let first = normalize(person.firstName)
        return "\(last)-\(first)"
    }

    static func normalize(_ name: String) -> String {
        name.lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
