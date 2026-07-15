import Foundation

struct PageFilenames: Sendable {
    let record: String
    let closeups: [String]
    let parsed: String
}

struct RecordFilenames: Sendable {
    let lafrance: String?
    let pages: [PageFilenames]
}

enum FilenameBuilder {
    static func filenames(
        for tab: RecordTab,
        people: [Person],
        closeupCounts: [Int]? = nil
    ) -> RecordFilenames {
        var base = buildBase(for: tab, people: people)
        if tab.isUnsure { base += "--unsure" }

        let lafrance: String?
        if tab.lafranceImage != nil {
            // Use the record the LaFrance came from, not just the first page, so it keeps its id
            // when the tab spans multiple records.
            let lafranceRecordID = tab.lafranceRecordID ?? tab.pages.first?.recordID ?? ""
            let recordIDPart = lafranceRecordID.isEmpty ? "" : "--\(lafranceRecordID)"
            lafrance = "\(base)\(recordIDPart)--lafrance.png"
        } else {
            lafrance = nil
        }

        let pageFilenames = tab.pages.enumerated().map { index, page in
            let recordIDPart = page.recordID.isEmpty ? "" : "--\(page.recordID)"
            let record = "\(base)\(recordIDPart).png"
            let parsed = "\(base)\(recordIDPart)--parsed.txt"
            let count = closeupCounts?[safe: index] ?? 1
            let closeups: [String]
            if count <= 1 {
                closeups = ["\(base)\(recordIDPart)--closeup.png"]
            } else {
                closeups = (1...count).map { n in
                    "\(base)\(recordIDPart)--closeup-\(n).png"
                }
            }
            return PageFilenames(record: record, closeups: closeups, parsed: parsed)
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
            return "\(year)--\(type)--\(groomName)__\(brideName)"
        case .legal:
            // One or more parties joined by __ (a single party reads like a normal name).
            let parts = tab.personIDs.map { id in formatName(people.first { $0.id == id }) }
            let joined = parts.isEmpty ? formatName(nil) : parts.joined(separator: "__")
            return "\(year)--\(type)--\(joined)"
        case .birth, .sepulture, .census, .obituary, .thanks:
            let person = people.first { $0.id == tab.personIDs[safe: 0] }
            let name = formatName(person)
            return "\(year)--\(type)--\(name)"
        case .misc:
            let label = tab.customLabel.isEmpty ? "misc" : normalize(tab.customLabel)
            return label
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
