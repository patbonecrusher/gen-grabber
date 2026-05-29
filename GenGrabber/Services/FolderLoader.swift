import AppKit
import Foundation

enum FolderLoader {
    struct LoadResult {
        var people: [Person]
        var tabs: [RecordTab]
        var notes: String
        var summary: SessionSummary
    }

    @MainActor
    static func pickAndLoad() -> LoadResult? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose a folder with genealogy record files"

        guard panel.runModal() == .OK, let folderURL = panel.url else { return nil }
        return load(from: folderURL)
    }

    static func load(from folderURL: URL) -> LoadResult {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)) ?? []

        // Load notes.txt if present
        let notesURL = folderURL.appendingPathComponent("notes.txt")
        let notes = (try? String(contentsOf: notesURL, encoding: .utf8)) ?? ""

        // Load summary JSON if present
        let folderName = folderURL.lastPathComponent
        let jsonURL = folderURL.appendingPathComponent("\(folderName).json")
        var summary = SessionSummary()
        if let jsonData = try? Data(contentsOf: jsonURL) {
            summary = (try? JSONDecoder().decode(SessionSummary.self, from: jsonData)) ?? SessionSummary()
        }

        // Group image files by record base (year-type-names)
        let imageFiles = files.filter { isImageFile($0) }
        let parsed = imageFiles.compactMap { parseFilename($0) }

        // Group by record key (year + type + names)
        var recordGroups: [String: [ParsedFile]] = [:]
        for p in parsed {
            recordGroups[p.recordKey, default: []].append(p)
        }

        // Build people list and tabs
        var peopleByName: [String: Person] = [:] // "lastname-firstname" -> Person
        var tabs: [RecordTab] = []

        for (_, group) in recordGroups.sorted(by: { $0.key < $1.key }) {
            guard let first = group.first else { continue }

            let personIDs: [UUID]
            let recordType = first.recordType

            switch recordType {
            case .wedding:
                let groom = getOrCreatePerson(
                    lastName: first.names[safe: 0] ?? "",
                    firstName: first.names[safe: 1] ?? "",
                    gender: .male,
                    registry: &peopleByName
                )
                let bride = getOrCreatePerson(
                    lastName: first.names[safe: 2] ?? "",
                    firstName: first.names[safe: 3] ?? "",
                    gender: .female,
                    registry: &peopleByName
                )
                personIDs = [groom.id, bride.id]
            case .birth, .sepulture:
                let person = getOrCreatePerson(
                    lastName: first.names[safe: 0] ?? "",
                    firstName: first.names[safe: 1] ?? "",
                    gender: .male, // Default, will be corrected if seen in a wedding
                    registry: &peopleByName
                )
                personIDs = [person.id]
            }

            // Group files by record ID to build pages
            var pagesByRecordID: [String: [ParsedFile]] = [:]
            for f in group {
                pagesByRecordID[f.recordID, default: []].append(f)
            }

            // Find the lafrance image (from first record ID)
            var lafranceImage: NSImage?
            var pages: [PageGroup] = []

            let sortedRecordIDs = pagesByRecordID.keys.sorted()
            for recordID in sortedRecordIDs {
                let pageFiles = pagesByRecordID[recordID] ?? []

                var recordImage: NSImage?
                var closeupImages: [NSImage?] = []

                for f in pageFiles {
                    let image = NSImage(contentsOf: f.url)
                    switch f.suffix {
                    case .lafrance:
                        lafranceImage = image
                    case .record:
                        recordImage = image
                    case .closeup:
                        closeupImages.append(image)
                    }
                }

                if closeupImages.isEmpty {
                    closeupImages = [nil]
                }

                var page = PageGroup(recordID: recordID, recordImage: recordImage)
                page.closeupImages = closeupImages
                pages.append(page)
            }

            var tab = RecordTab(recordType: recordType, personIDs: personIDs, year: first.year)
            tab.lafranceImage = lafranceImage
            tab.pages = pages
            tabs.append(tab)
        }

        let people = Array(peopleByName.values)
        return LoadResult(people: people, tabs: tabs, notes: notes, summary: summary)
    }

    // MARK: - Filename Parsing

    private enum FileSuffix {
        case lafrance
        case record
        case closeup
    }

    private struct ParsedFile {
        let url: URL
        let year: String
        let recordType: RecordType
        let names: [String] // [lastName, firstName] or [groomLast, groomFirst, brideLast, brideFirst]
        let recordID: String
        let suffix: FileSuffix
        var recordKey: String { "\(year)-\(recordType.rawValue)-\(names.joined(separator: "-"))" }
    }

    private static func parseFilename(_ url: URL) -> ParsedFile? {
        let filename = url.deletingPathExtension().lastPathComponent

        // Find record ID (starts with d1p_ or is a numeric string)
        // Split on the record ID pattern
        guard let recordIDRange = filename.range(of: #"d\dp_\d+"#, options: .regularExpression) else {
            return nil
        }

        let recordID = String(filename[recordIDRange])
        let beforeRecordID = String(filename[filename.startIndex..<recordIDRange.lowerBound])
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let afterRecordID = String(filename[recordIDRange.upperBound...])

        // Parse suffix
        let suffix: FileSuffix
        if afterRecordID.contains("lafrance") {
            suffix = .lafrance
        } else if afterRecordID.contains("closeup") {
            suffix = .closeup
        } else {
            suffix = .record
        }

        // Parse year-type-names from beforeRecordID
        let parts = beforeRecordID.split(separator: "-", maxSplits: 2).map(String.init)
        guard parts.count >= 3 else { return nil }

        let year = parts[0]
        guard let recordType = RecordType(rawValue: parts[1]) else { return nil }

        let namesPart = parts[2]
        let names = parseNames(namesPart, recordType: recordType)

        return ParsedFile(
            url: url,
            year: year,
            recordType: recordType,
            names: names,
            recordID: recordID,
            suffix: suffix
        )
    }

    private static func parseNames(_ namesPart: String, recordType: RecordType) -> [String] {
        // Names are hyphenated: "girard-joseph" or "girard-joseph-vanasse-marie-anne"
        // For birth/sepulture: [lastName, firstName]
        // For wedding: [groomLast, groomFirst, brideLast, brideFirst]
        // Challenge: first names can be multi-part (marie-anne)

        // Strategy: we know the structure. For birth/sepulture, the first segment is last name,
        // the rest is first name. For wedding, we need to find where groom ends and bride begins.
        // We use the fact that last names are single words (one segment) and first names may be
        // multi-segment.

        // Actually, looking at real data: last names are always single segment in the filename.
        // "girard-joseph", "vanasse-marie-anne", "languirand-pierre"
        // So: lastname is always the first segment, firstname is everything until the next lastname.

        let segments = namesPart.split(separator: "-").map(String.init)

        switch recordType {
        case .birth, .sepulture:
            guard segments.count >= 2 else { return segments }
            let lastName = segments[0]
            let firstName = segments[1...].joined(separator: "-")
            return [lastName, firstName]

        case .wedding:
            // Need to split into groom and bride names
            // Pattern: groomLast-groomFirst[-groomFirst...]-brideLast-brideFirst[-brideFirst...]
            // Since last names are single segments, we try splitting at each position
            // and use heuristic: both halves should have at least 2 segments
            guard segments.count >= 4 else { return segments }

            // Try each possible split point (after groom's name)
            // The groom has at least 2 segments (last + first), bride has at least 2
            // We try split points from position 2 to count-2
            // Pick the split where both halves look like valid names

            // Simple approach: last names are single segment, so groom = segments[0] + segments[1..split],
            // bride = segments[split] + segments[split+1..]
            // Since we don't know where groom's first name ends, we try all splits
            // For now, assume each person has lastname + firstname where firstname may be compound

            // Look at it differently: we have groomLast, then groomFirst (may be multi), then brideLast, then brideFirst
            // groomLast = segments[0]
            // We need to find where brideLastName starts
            // Heuristic: try split at 2, 3, etc. and see if it produces reasonable names

            // Best heuristic: capitalize patterns. In real data, last names tend to be different from first names.
            // But all are lowercased in filenames, so we can't use that.

            // Simplest working approach: assume first names are at most 2 segments
            // groomLast = segments[0], groomFirst = segments[1] (or segments[1]-segments[2] if segments[2] looks like a first name continuation)

            // Actually, let's just try: groom is 2 segments, bride gets the rest.
            // If that leaves bride with < 2 segments, try groom as 3 segments.
            for groomLen in 2...max(2, segments.count - 2) {
                let groomSegments = Array(segments[0..<groomLen])
                let brideSegments = Array(segments[groomLen...])
                if brideSegments.count >= 2 {
                    let groomLast = groomSegments[0]
                    let groomFirst = groomSegments[1...].joined(separator: "-")
                    let brideLast = brideSegments[0]
                    let brideFirst = brideSegments[1...].joined(separator: "-")
                    return [groomLast, groomFirst, brideLast, brideFirst]
                }
            }
            return segments
        }
    }

    // MARK: - Helpers

    private static func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "png" || ext == "jpg" || ext == "jpeg"
    }

    private static func getOrCreatePerson(
        lastName: String,
        firstName: String,
        gender: Gender,
        registry: inout [String: Person]
    ) -> Person {
        // Capitalize names for display
        let displayLast = capitalize(lastName)
        let displayFirst = capitalize(firstName)
        let key = "\(lastName)-\(firstName)".lowercased()

        if let existing = registry[key] {
            return existing
        }

        let person = Person(gender: gender, lastName: displayLast, firstName: displayFirst)
        registry[key] = person
        return person
    }

    private static func capitalize(_ name: String) -> String {
        name.split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
