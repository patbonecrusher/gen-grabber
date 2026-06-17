import SwiftUI

enum TabSelection: Equatable {
    case record(UUID)
    case notes
    case summary
    case other
}

@Observable
final class SessionModel: @unchecked Sendable {
    var people: [Person] = []
    var tabs: [RecordTab] = []
    var notes: [Note] = [Note(title: "notes")]
    var selection: TabSelection = .summary
    var summary: SessionSummary = SessionSummary()
    var otherFiles = OtherFilesCollection()

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
        if type == .wedding { updateWeddingGenders(personIDs) }
        let tab = RecordTab(recordType: type, personIDs: personIDs)
        tabs.append(tab)
        selection = .record(tab.id)
    }

    func promoteOtherFile(_ fileID: UUID, type: RecordType, personIDs: [UUID]) {
        guard let index = otherFiles.files.firstIndex(where: { $0.id == fileID }) else { return }
        let file = otherFiles.files.remove(at: index)

        if type == .wedding { updateWeddingGenders(personIDs) }

        let inferred = inferMetadata(from: file.filename, type: type, personIDs: personIDs)

        // Check if there's an existing tab for these people + type we can add the image to
        if let tabIndex = tabs.firstIndex(where: {
            $0.recordType == type && $0.personIDs == personIDs
        }) {
            // Add as a page image to the existing tab
            if tabs[tabIndex].pages.last?.recordImage != nil {
                var newPage = PageGroup(recordID: inferred.recordID)
                newPage.recordImage = file.image
                tabs[tabIndex].pages.append(newPage)
            } else {
                let lastIdx = tabs[tabIndex].pages.count - 1
                tabs[tabIndex].pages[lastIdx].recordImage = file.image
                if tabs[tabIndex].pages[lastIdx].recordID.isEmpty {
                    tabs[tabIndex].pages[lastIdx].recordID = inferred.recordID
                }
            }
            if tabs[tabIndex].year.isEmpty { tabs[tabIndex].year = inferred.year }
            selection = .record(tabs[tabIndex].id)
        } else {
            // Create a new tab
            var tab = RecordTab(recordType: type, personIDs: personIDs, year: inferred.year)
            tab.pages[0].recordID = inferred.recordID
            tab.pages[0].recordImage = file.image
            tabs.append(tab)
            selection = .record(tab.id)
        }
    }

    private struct InferredMetadata {
        var year: String = ""
        var recordID: String = ""
    }

    private func inferMetadata(from filename: String, type: RecordType, personIDs: [UUID]) -> InferredMetadata {
        // Strip extension
        var name = filename
        if let dotIdx = name.lastIndex(of: ".") { name = String(name[..<dotIdx]) }

        // Strip known parts from the filename to find the leftover (record ID / source)
        // Build list of segments to remove: year, type code, person names
        let personNames = personIDs.compactMap { person(for: $0) }.flatMap { p in
            [FilenameBuilder.normalize(p.lastName), FilenameBuilder.normalize(p.firstName)]
        }

        // Try to extract year (leading 4-digit number)
        var year = ""
        let segments = name.split(separator: "-", maxSplits: 1).map(String.init)
        if let first = segments.first, first.count == 4, first.allSatisfy(\.isNumber) {
            year = first
        }

        // Remove known parts: year, type raw value, and person name segments
        var remaining = name.lowercased()
        // Remove year prefix
        if !year.isEmpty, remaining.hasPrefix(year) {
            remaining = String(remaining.dropFirst(year.count))
            remaining = remaining.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }
        // Remove type code
        let typeCode = type.rawValue
        if remaining.hasPrefix(typeCode + "-") || remaining.hasPrefix(typeCode + "--") {
            remaining = String(remaining.dropFirst(typeCode.count))
            remaining = remaining.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }
        // Remove person name segments
        for namePart in personNames where !namePart.isEmpty {
            remaining = remaining.replacingOccurrences(of: namePart, with: "")
        }
        // Also remove __ separator
        remaining = remaining.replacingOccurrences(of: "__", with: "")
        // Clean up leftover dashes
        remaining = remaining
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .replacingOccurrences(of: "---", with: "-")
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return InferredMetadata(year: year, recordID: remaining)
    }

    private func updateWeddingGenders(_ personIDs: [UUID]) {
        if let groomIdx = people.firstIndex(where: { $0.id == personIDs[safe: 0] }) {
            people[groomIdx].gender = .male
        }
        if let brideIdx = people.firstIndex(where: { $0.id == personIDs[safe: 1] }) {
            people[brideIdx].gender = .female
        }
    }

    func removeTab(_ id: UUID) {
        tabs.removeAll { $0.id == id }
        if selection == .record(id) {
            selection = tabs.first.map { TabSelection.record($0.id) } ?? .notes
        }
    }

    func person(for id: UUID) -> Person? {
        people.first { $0.id == id }
    }

    func tabLabel(for tab: RecordTab) -> String {
        let names = tab.personIDs.compactMap { person(for: $0) }
        let unsureSuffix = tab.isUnsure ? "?" : ""
        switch tab.recordType {
        case .wedding:
            let groom = names.first.map { $0.firstName } ?? "?"
            let bride = names.dropFirst().first.map { $0.firstName } ?? "?"
            return "W: \(groom) + \(bride)\(unsureSuffix)"
        case .birth, .sepulture, .obituary, .thanks:
            let name = names.first.map { $0.firstName } ?? "?"
            return "\(tab.recordType.shortLabel): \(name)\(unsureSuffix)"
        case .misc:
            let label = tab.customLabel.isEmpty ? "Misc" : tab.customLabel
            return "M: \(label)\(unsureSuffix)"
        }
    }

    func addNote() {
        notes.append(Note())
    }

    func removeNote(_ id: UUID) {
        guard notes.count > 1 else { return }
        notes.removeAll { $0.id == id }
    }

    func loadFromResult(_ result: FolderLoader.LoadResult) {
        clearAll()
        people = result.people
        tabs = result.tabs
        notes = result.notes
        summary = result.summary
        otherFiles = result.otherFiles
        selection = tabs.first.map { .record($0.id) } ?? .notes
    }

    func clearAll() {
        people.removeAll()
        tabs.removeAll()
        notes = [Note(title: "notes")]
        summary = SessionSummary()
        otherFiles = OtherFilesCollection()
        selection = .summary
    }

    var totalImageCount: Int {
        let tabImages = tabs.reduce(0) { count, tab in
            var n = tab.lafranceImage != nil ? 1 : 0
            for page in tab.pages {
                if page.recordImage != nil { n += 1 }
                n += page.closeupImages.compactMap({ $0 }).count
            }
            return count + n
        }
        return tabImages + otherFiles.files.count
    }
}
