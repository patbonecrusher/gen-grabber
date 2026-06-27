import AppKit
import Foundation

enum FolderLoader {
    struct LoadResult {
        var folderURL: URL
        var people: [Person]
        var tabs: [RecordTab]
        var notes: [Note]
        var summary: SessionSummary
        var otherFiles: OtherFilesCollection
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

    /// Returns the sibling subfolders of the given folder (including itself), sorted
    /// in natural order by name so numbered folders (0256, 0257, …) order correctly.
    static func siblingFolders(of folderURL: URL) -> [URL] {
        let parent = folderURL.deletingLastPathComponent()
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(
            at: parent,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let dirs = contents.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        }
        return dirs.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    static func load(from folderURL: URL) -> LoadResult {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)) ?? []

        // Load note .txt files (excluding --parsed.txt and summary.json)
        var loadedNotes: [Note] = []
        for url in files where url.pathExtension.lowercased() == "txt" && !url.lastPathComponent.contains("--parsed") {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                let title = url.deletingPathExtension().lastPathComponent
                loadedNotes.append(Note(title: title, content: content))
            }
        }
        if loadedNotes.isEmpty {
            loadedNotes = [Note(title: "notes")]
        }

        // Load summary JSON if present
        let jsonURL = folderURL.appendingPathComponent("summary.json")
        var summary = SessionSummary()
        if let jsonData = try? Data(contentsOf: jsonURL) {
            summary = (try? JSONDecoder().decode(SessionSummary.self, from: jsonData)) ?? SessionSummary()
        }

        // Collect parsed text files (--parsed.txt) keyed by their record key + record ID
        // e.g. "1845--b--girard-joseph--d13p_12345--parsed.txt" → key "d13p_12345"
        // LaFrance parsed text: "base--recordID--lafrance--parsed.txt" → keyed separately
        var parsedTexts: [String: String] = [:]  // recordID → text
        var parsedTextsByRecordKey: [String: String] = [:]  // recordKey → text (fallback)
        var lafranceParsedTexts: [String: String] = [:]  // recordKey → lafrance parsed text
        for url in files where url.lastPathComponent.hasSuffix("--parsed.txt") {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let filename = url.lastPathComponent
            let parts = filename.replacingOccurrences(of: "--parsed.txt", with: "")
                .components(separatedBy: "--")

            // Check for lafrance parsed text (ends with --lafrance--parsed.txt)
            if parts.last == "lafrance" {
                let recordKey = parts.dropLast().joined(separator: "--")
                lafranceParsedTexts[recordKey] = text
                continue
            }

            // Last non-"parsed" part is the recordID, earlier parts form the record key
            if parts.count >= 4 {
                // year--type--names--recordID
                let recordID = parts.last!
                let recordKey = parts.dropLast().joined(separator: "--")
                parsedTexts[recordID] = text
                parsedTextsByRecordKey[recordKey] = text
            } else if parts.count == 3 {
                // year--type--names (no recordID)
                let recordKey = parts.joined(separator: "--")
                parsedTextsByRecordKey[recordKey] = text
            }
        }

        // Group image files by record base (year-type-names)
        let imageFiles = files.filter { isImageFile($0) }

        var parsed: [ParsedFile] = []
        var otherFiles = OtherFilesCollection()
        for url in imageFiles {
            if let p = parseNewFormat(url) ?? parseLegacyFormat(url) {
                parsed.append(p)
            } else {
                let image = NSImage(contentsOf: url)
                otherFiles.files.append(OtherFile(url: url, filename: url.lastPathComponent, image: image))
            }
        }

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
                    knownGender: true,
                    registry: &peopleByName
                )
                let bride = getOrCreatePerson(
                    lastName: first.names[safe: 2] ?? "",
                    firstName: first.names[safe: 3] ?? "",
                    gender: .female,
                    knownGender: true,
                    registry: &peopleByName
                )
                personIDs = [groom.id, bride.id]
            case .birth, .sepulture, .obituary, .thanks:
                let person = getOrCreatePerson(
                    lastName: first.names[safe: 0] ?? "",
                    firstName: first.names[safe: 1] ?? "",
                    gender: .male, // Default, will be corrected if seen in a wedding
                    registry: &peopleByName
                )
                personIDs = [person.id]
            case .misc:
                personIDs = []
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
                let pageFiles = (pagesByRecordID[recordID] ?? [])
                    .sorted { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }

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

                // Look up parsed text for this page by recordID, then by record key
                if let text = parsedTexts[recordID] {
                    page.parsedText = text
                } else {
                    // Build the record key in the same format as filenames
                    let names = first.names
                    let namesPart: String
                    if first.recordType == .wedding && names.count == 4 {
                        namesPart = "\(names[0])-\(names[1])__\(names[2])-\(names[3])"
                    } else {
                        namesPart = names.joined(separator: "-")
                    }
                    let key = "\(first.year)--\(first.recordType.rawValue)--\(namesPart)"
                    if let text = parsedTextsByRecordKey[key] {
                        page.parsedText = text
                    }
                }

                pages.append(page)
            }

            var tab = RecordTab(recordType: recordType, personIDs: personIDs, year: first.year, isUnsure: first.isUnsure)
            tab.lafranceImage = lafranceImage
            tab.pages = pages

            tabs.append(tab)
        }

        // If folder is empty, try to populate people from the folder name
        // Format: 410-411--lastname-firstname__lastname-firstname
        var people = Array(peopleByName.values)
        if people.isEmpty && tabs.isEmpty {
            let folderPeople = parseFolderName(folderURL.lastPathComponent)
            people = folderPeople
        }

        return LoadResult(folderURL: folderURL, people: people, tabs: tabs, notes: loadedNotes, summary: summary, otherFiles: otherFiles)
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
        let isUnsure: Bool
        var recordKey: String { "\(year)-\(recordType.rawValue)-\(names.joined(separator: "-"))" }
    }

    // MARK: - New Format Parser (uses -- and __ separators)
    // Format: year--type--names[--source[--suffix]].ext
    // Wedding names use __ to separate people: groom-first__bride-first

    private static func parseNewFormat(_ url: URL) -> ParsedFile? {
        let filename = url.deletingPathExtension().lastPathComponent

        // New format requires at least two -- separators (year--type--names)
        let sections = filename.components(separatedBy: "--")
        guard sections.count >= 3 else { return nil }

        let year = sections[0]
        guard let recordType = RecordType(rawValue: sections[1]) else { return nil }
        let namesPart = sections[2]

        // Parse names: split on __ for wedding (person1__person2)
        let names: [String]
        if recordType == .wedding, namesPart.contains("__") {
            let personParts = namesPart.components(separatedBy: "__")
            guard personParts.count == 2 else { return nil }
            let groomSegments = personParts[0].split(separator: "-", maxSplits: 1).map(String.init)
            let brideSegments = personParts[1].split(separator: "-", maxSplits: 1).map(String.init)
            names = [
                groomSegments[safe: 0] ?? "", groomSegments[safe: 1] ?? "",
                brideSegments[safe: 0] ?? "", brideSegments[safe: 1] ?? "",
            ]
        } else {
            names = namesPart.split(separator: "-", maxSplits: 1).map(String.init)
        }

        // Remaining sections are source/recordID and suffix
        var remaining = Array(sections.dropFirst(3))

        // Detect and strip "unsure" flag
        let isUnsure = remaining.contains("unsure")
        remaining.removeAll { $0 == "unsure" }

        // Identify suffix (last section if it's a known keyword)
        let knownSuffixes: Set<String> = ["lafrance", "closeup", "parsed"]
        let suffix: FileSuffix
        var sourceSections = remaining

        if let last = sourceSections.last {
            if last.contains("lafrance") {
                suffix = .lafrance
                sourceSections.removeLast()
            } else if last.hasPrefix("closeup") {
                suffix = .closeup
                sourceSections.removeLast()
            } else if knownSuffixes.contains(last) {
                // "parsed" — skip this file (it's a text file, not an image)
                return nil
            } else {
                suffix = .record
            }
        } else {
            suffix = .record
        }

        // What's left is the source/recordID
        var recordID = ""
        var source = ""
        for section in sourceSections {
            if section.hasPrefix("d") && section.contains("p_") {
                recordID = section
            } else {
                source = section
            }
        }
        // If no LaFrance-style recordID, use the source as the grouping key
        if recordID.isEmpty && !source.isEmpty {
            recordID = source
        }

        return ParsedFile(
            url: url,
            year: year,
            recordType: recordType,
            names: names,
            recordID: recordID,
            suffix: suffix,
            isUnsure: isUnsure
        )
    }

    // MARK: - Legacy Format Parser (old LaFrance regex-based)

    private static func parseLegacyFormat(_ url: URL) -> ParsedFile? {
        let filename = url.deletingPathExtension().lastPathComponent

        // Determine suffix by checking what's at the end
        let suffix: FileSuffix
        var working = filename
        if let range = working.range(of: "-lafrance", options: .backwards) {
            suffix = .lafrance
            working = String(working[..<range.lowerBound])
        } else if let range = working.range(of: #"-closeup(-\d+)?$"#, options: .regularExpression) {
            suffix = .closeup
            working = String(working[..<range.lowerBound])
        } else {
            suffix = .record
        }

        // Split: year-type-names-recordID
        // year is first segment, type is second, then names, then the last segment is the recordID
        // The recordID starts with "d" followed by digits then "p_"
        let parts = working.split(separator: "-", maxSplits: 2).map(String.init)
        guard parts.count >= 3 else { return nil }

        let year = parts[0]
        guard let recordType = RecordType(rawValue: parts[1]) else { return nil }

        let remainder = parts[2] // "names-recordID"

        // Find the recordID: look for last segment starting with "d" followed by digit then "p_"
        // Split remainder into segments and find where recordID starts
        let segments = remainder.split(separator: "-").map(String.init)
        var recordIDStart: Int?
        for i in segments.indices {
            if segments[i].hasPrefix("d") && segments[i].contains("p_") {
                recordIDStart = i
                break
            }
        }

        let namesPart: String
        let recordID: String
        if let start = recordIDStart, start > 0 {
            namesPart = segments[0..<start].joined(separator: "-")
            recordID = segments[start...].joined(separator: "-")
        } else {
            // No recordID found
            return nil
        }

        let names = parseLegacyNames(namesPart, recordType: recordType)

        return ParsedFile(
            url: url,
            year: year,
            recordType: recordType,
            names: names,
            recordID: recordID,
            suffix: suffix,
            isUnsure: false
        )
    }

    private static func parseLegacyNames(_ namesPart: String, recordType: RecordType) -> [String] {
        let segments = namesPart.split(separator: "-").map(String.init)

        switch recordType {
        case .birth, .sepulture, .obituary, .thanks:
            guard segments.count >= 2 else { return segments }
            let lastName = segments[0]
            let firstName = segments[1...].joined(separator: "-")
            return [lastName, firstName]

        case .misc:
            return segments

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

    // MARK: - Folder Name Parsing
    // Format: 410-411--lastname-firstname__lastname-firstname
    // The ahnentafel numbers before -- are ignored.

    private static func parseFolderName(_ name: String) -> [Person] {
        let sections = name.components(separatedBy: "--")
        guard sections.count >= 2 else { return [] }

        // Everything after the first -- is the names part (rejoin in case of extra --)
        let namesPart = sections.dropFirst().joined(separator: "--")

        // Split on __ for husband and wife
        let personParts = namesPart.components(separatedBy: "__")
        guard personParts.count == 2 else { return [] }

        let husbandSegments = personParts[0].split(separator: "-", maxSplits: 1).map(String.init)
        let wifeSegments = personParts[1].split(separator: "-", maxSplits: 1).map(String.init)

        let husband = Person(
            gender: .male,
            lastName: capitalize(husbandSegments[safe: 0] ?? ""),
            firstName: capitalize(husbandSegments[safe: 1] ?? "")
        )
        let wife = Person(
            gender: .female,
            lastName: capitalize(wifeSegments[safe: 0] ?? ""),
            firstName: capitalize(wifeSegments[safe: 1] ?? "")
        )

        return [husband, wife]
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
        knownGender: Bool = false,
        registry: inout [String: Person]
    ) -> Person {
        // Capitalize names for display
        let displayLast = capitalize(lastName)
        let displayFirst = capitalize(firstName)
        let key = "\(lastName)-\(firstName)".lowercased()

        if var existing = registry[key] {
            // Only update gender when we actually know it (from a wedding role)
            if knownGender && existing.gender != gender {
                existing.gender = gender
                registry[key] = existing
            }
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
