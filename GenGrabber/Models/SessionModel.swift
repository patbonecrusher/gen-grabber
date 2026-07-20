import SwiftUI

enum TabSelection: Equatable {
    case record(UUID)
    case notes
    case todo
    case summary
    case other
}

@Observable
final class SessionModel: @unchecked Sendable {
    // Equatable-gated so that SwiftUI TextFields writing back an identical value (e.g. when a
    // field resigns focus as the Save panel opens) don't spuriously mark the session dirty.
    var people: [Person] = [] { didSet { if people != oldValue { markDirty() } } }
    var tabs: [RecordTab] = [] { didSet { markDirty() } }
    var notes: [Note] = [Note(title: "notes")] { didSet { if notes != oldValue { markDirty() } } }
    /// Follow-up tasks for the open folder, saved as a Markdown checklist (todo.md).
    var todos: [TodoItem] = [] { didSet { if todos != oldValue { markDirty() } } }
    var selection: TabSelection = .summary
    var summary: SessionSummary = SessionSummary() { didSet { if summary != oldValue { markDirty() } } }
    var otherFiles = OtherFilesCollection() { didSet { markDirty() } }

    /// The folder the current session was loaded from (nil if loaded manually / empty).
    private(set) var currentFolderURL: URL?
    /// Sibling subfolders of `currentFolderURL`, sorted in natural order. Cached on load.
    private(set) var siblingFolders: [URL] = []
    /// Maps each loaded image (by instance identity) to the file it was read from.
    /// Used by the saver to offer removal of old, differently-named originals.
    private(set) var sourceURLByImage: [ObjectIdentifier: URL] = [:]
    /// True when the loaded folder has records using the old single-dash naming.
    private(set) var hasLegacyFiles = false

    /// True when the session has edits not yet written to disk. Flipped on by any change
    /// to people/tabs/notes/summary/otherFiles, and cleared on load, clear, and save.
    @ObservationIgnored private(set) var hasUnsavedChanges = false

    private func markDirty() { hasUnsavedChanges = true }

    /// Call after a successful save so navigation no longer warns about lost work.
    func markSaved() { hasUnsavedChanges = false }

    private func setCurrentFolder(_ url: URL?) {
        currentFolderURL = url
        siblingFolders = url.map { FolderLoader.siblingFolders(of: $0) } ?? []
    }

    private var currentFolderIndex: Int? {
        guard let currentFolderURL else { return nil }
        return siblingFolders.firstIndex {
            $0.standardizedFileURL == currentFolderURL.standardizedFileURL
        }
    }

    var previousFolderURL: URL? {
        guard let i = currentFolderIndex, i > 0 else { return nil }
        return siblingFolders[i - 1]
    }

    var nextFolderURL: URL? {
        guard let i = currentFolderIndex, i < siblingFolders.count - 1 else { return nil }
        return siblingFolders[i + 1]
    }

    /// A "12 / 80" style position within the sibling folders, or nil when not in a folder.
    var folderPositionText: String? {
        guard let i = currentFolderIndex else { return nil }
        return "\(i + 1) / \(siblingFolders.count)"
    }

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
            return "\(tab.recordType.shortLabel): \(groom) + \(bride)\(unsureSuffix)"
        case .legal:
            let firsts = names.map { $0.firstName }.filter { !$0.isEmpty }
            let joined = firsts.isEmpty ? "?" : firsts.joined(separator: " + ")
            return "\(tab.recordType.shortLabel): \(joined)\(unsureSuffix)"
        case .birth, .sepulture, .census, .obituary, .thanks:
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

    // MARK: - Todos (persisted as todo.md)

    /// Number of todos still to do — drives the badge on the Todo tab.
    var openTodoCount: Int {
        todos.filter { !$0.done && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    func addTodo() {
        todos.append(TodoItem())
    }

    func removeTodo(_ id: UUID) {
        todos.removeAll { $0.id == id }
    }

    func clearCompletedTodos() {
        todos.removeAll { $0.done }
    }

    // MARK: - Genealogical status marks (name-keyed, persisted in summary.markedPeople)

    private func markKey(last: String, first: String) -> String {
        "\(last.trimmingCharacters(in: .whitespaces).lowercased())|\(first.trimmingCharacters(in: .whitespaces).lowercased())"
    }

    private func markIndex(last: String, first: String) -> Int? {
        let key = markKey(last: last, first: first)
        return summary.markedPeople.firstIndex { markKey(last: $0.lastName, first: $0.firstName) == key }
    }

    func statuses(last: String, first: String) -> Set<GenealogicalStatus> {
        guard let i = markIndex(last: last, first: first) else { return [] }
        return Set(summary.markedPeople[i].statuses)
    }

    func isMarked(_ status: GenealogicalStatus, last: String, first: String) -> Bool {
        statuses(last: last, first: first).contains(status)
    }

    func setStatus(_ status: GenealogicalStatus, _ on: Bool, last: String, first: String) {
        let i = ensureMark(last: last, first: first)
        var set = Set(summary.markedPeople[i].statuses)
        if on { set.insert(status) } else { set.remove(status) }
        // Store in a stable (declaration) order.
        summary.markedPeople[i].statuses = GenealogicalStatus.allCases.filter { set.contains($0) }
        pruneMarkIfEmpty(at: i)
    }

    func origin(last: String, first: String) -> String {
        guard let i = markIndex(last: last, first: first) else { return "" }
        return summary.markedPeople[i].origin
    }

    func setOrigin(_ origin: String, last: String, first: String) {
        let i = ensureMark(last: last, first: first)
        summary.markedPeople[i].origin = origin
        pruneMarkIfEmpty(at: i)
    }

    /// Index of the mark for this person, creating an empty one if needed.
    private func ensureMark(last: String, first: String) -> Int {
        if let i = markIndex(last: last, first: first) { return i }
        summary.markedPeople.append(PersonMark(lastName: last, firstName: first))
        return summary.markedPeople.count - 1
    }

    /// Drops a mark that no longer carries any status or origin, keeping summary.json clean.
    private func pruneMarkIfEmpty(at index: Int) {
        guard summary.markedPeople.indices.contains(index) else { return }
        let m = summary.markedPeople[index]
        if m.statuses.isEmpty && m.origin.trimmingCharacters(in: .whitespaces).isEmpty {
            summary.markedPeople.remove(at: index)
        }
    }

    func loadFromResult(_ result: FolderLoader.LoadResult) {
        clearAll()
        people = result.people
        tabs = result.tabs
        notes = result.notes
        todos = result.todos
        summary = result.summary
        otherFiles = result.otherFiles
        sourceURLByImage = result.sourceURLByImage
        hasLegacyFiles = result.hasLegacyFiles
        selection = tabs.first.map { .record($0.id) } ?? .notes
        setCurrentFolder(result.folderURL)
        hasUnsavedChanges = false
    }

    func clearAll() {
        people.removeAll()
        tabs.removeAll()
        notes = [Note(title: "notes")]
        todos = []
        summary = SessionSummary()
        otherFiles = OtherFilesCollection()
        sourceURLByImage = [:]
        hasLegacyFiles = false
        selection = .summary
        setCurrentFolder(nil)
        hasUnsavedChanges = false
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
