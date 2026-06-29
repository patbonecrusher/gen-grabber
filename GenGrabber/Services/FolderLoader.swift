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
        /// Maps each loaded image (by instance identity) back to the file it came from,
        /// so the saver can detect and offer to remove old, differently-named originals.
        var sourceURLByImage: [ObjectIdentifier: URL]
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

        // Tracks which file each loaded image came from (keyed by instance identity).
        var sourceURLByImage: [ObjectIdentifier: URL] = [:]

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

        // The couple encoded in the folder name lets us split legacy wedding names and unify
        // dit-alias surnames (a record under "meunier" or "lapierre" → the one husband).
        let couple = coupleMembers(fromFolder: folderURL.lastPathComponent)

        // Group image files by record base (year-type-names)
        let imageFiles = files.filter { isImageFile($0) }

        var parsed: [ParsedFile] = []
        var otherFiles = OtherFilesCollection()
        for url in imageFiles {
            if let p = parseNewFormat(url) ?? parseLegacyFormat(url, couple: couple) {
                parsed.append(p)
            } else {
                let image = NSImage(contentsOf: url)
                if let image { sourceURLByImage[ObjectIdentifier(image)] = url }
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
                let groom = makePerson(
                    last: first.names[safe: 0] ?? "", first: first.names[safe: 1] ?? "",
                    defaultGender: .male, knownGender: true, couple: couple, registry: &peopleByName
                )
                let bride = makePerson(
                    last: first.names[safe: 2] ?? "", first: first.names[safe: 3] ?? "",
                    defaultGender: .female, knownGender: true, couple: couple, registry: &peopleByName
                )
                personIDs = [groom.id, bride.id]
            case .birth, .sepulture, .obituary, .thanks:
                let person = makePerson(
                    last: first.names[safe: 0] ?? "", first: first.names[safe: 1] ?? "",
                    defaultGender: .male, // Default, corrected if seen in a wedding or matched to the couple
                    knownGender: false, couple: couple, registry: &peopleByName
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
                    if let image { sourceURLByImage[ObjectIdentifier(image)] = f.url }
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

        // When summary.json is present it is authoritative for the last/first split (its
        // markedPeople are user-authored, its record persons store "LASTNAME, Firstname"),
        // so correct any ambiguous "dit" splits the filename heuristic may have guessed.
        let splitMap = buildNameSplitMap(from: summary)
        if !splitMap.isEmpty {
            people = people.map { applyNameSplit($0, using: splitMap) }
        }
        // Realign any marks saved with an older split so they still attach to their person.
        summary.markedPeople = reconcileMarks(summary.markedPeople, to: people)

        return LoadResult(folderURL: folderURL, people: people, tabs: tabs, notes: loadedNotes, summary: summary, otherFiles: otherFiles, sourceURLByImage: sourceURLByImage)
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
            let groom = splitPersonName(personParts[0])
            let bride = splitPersonName(personParts[1])
            names = [groom.last, groom.first, bride.last, bride.first]
        } else {
            let split = splitPersonName(namesPart)
            names = split.first.isEmpty ? [split.last] : [split.last, split.first]
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

    private static func parseLegacyFormat(_ url: URL, couple: [CoupleMember]) -> ParsedFile? {
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

        // Find where the recordID starts: the first segment that isn't a plain lowercase name
        // (i.e. contains a digit or an uppercase letter). Handles d1p_… as well as FamilySearch
        // ARKs (e.g. 3QSQ-G993-F93K-J), BANQ ids, and other non-d1p identifiers.
        let segments = remainder.split(separator: "-").map(String.init)
        var recordIDStart: Int?
        for i in segments.indices {
            if segments[i].contains(where: { $0.isNumber || $0.isUppercase }) {
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

        let names = parseLegacyNames(namesPart, recordType: recordType, couple: couple)

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

    private static func parseLegacyNames(_ namesPart: String, recordType: RecordType, couple: [CoupleMember]) -> [String] {
        let segments = namesPart.split(separator: "-").map(String.init)

        switch recordType {
        case .birth, .sepulture, .obituary, .thanks:
            guard segments.count >= 2 else { return segments }
            let (last, first) = splitNameSegments(segments)
            return [last.joined(separator: "-"), first.joined(separator: "-")]

        case .misc:
            return segments

        case .wedding:
            // Prefer the folder-name couple to find the groom/bride boundary — it handles
            // multi-word "dit" surnames the positional heuristic below cannot.
            if let names = splitLegacyWedding(segments, couple: couple) { return names }

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

        let husbandName = splitPersonName(personParts[0])
        let wifeName = splitPersonName(personParts[1])

        let husband = Person(
            gender: .male,
            lastName: capitalize(husbandName.last),
            firstName: capitalize(husbandName.first)
        )
        let wife = Person(
            gender: .female,
            lastName: capitalize(wifeName.last),
            firstName: capitalize(wifeName.first)
        )

        return [husband, wife]
    }

    // MARK: - Helpers

    private static func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "png" || ext == "jpg" || ext == "jpeg"
    }

    // MARK: - Folder-name couple unification (dit aliases)

    /// One spouse from the folder name, with the set of surname forms that should map to them
    /// (the base surname plus each "dit" alias).
    private struct CoupleMember {
        let gender: Gender
        let canonicalLast: String   // normalized, e.g. "jared-dit-beauregard"
        let firstNorm: String       // normalized, e.g. "pierre"
        let variants: Set<String>   // {jared-dit-beauregard, jared, beauregard}
    }

    /// Parses "…--husband__wife" from the folder name into couple members for unification.
    private static func coupleMembers(fromFolder name: String) -> [CoupleMember] {
        let sections = name.components(separatedBy: "--")
        guard sections.count >= 2 else { return [] }
        let namesPart = sections.dropFirst().joined(separator: "--")
        let parts = namesPart.components(separatedBy: "__")
        guard parts.count == 2 else { return [] }
        return [coupleMember(from: parts[0], gender: .male),
                coupleMember(from: parts[1], gender: .female)].compactMap { $0 }
    }

    private static func coupleMember(from raw: String, gender: Gender) -> CoupleMember? {
        let (last, first) = splitPersonName(raw)
        guard !last.isEmpty else { return nil }
        var variants: Set<String> = [last]
        // Each run of segments between "dit" markers is an alternate surname.
        var current: [String] = []
        for seg in last.split(separator: "-").map(String.init) {
            if ditMarkers.contains(seg.lowercased()) {
                if !current.isEmpty { variants.insert(current.joined(separator: "-")) }
                current = []
            } else {
                current.append(seg)
            }
        }
        if !current.isEmpty { variants.insert(current.joined(separator: "-")) }
        return CoupleMember(gender: gender, canonicalLast: last, firstNorm: first, variants: variants)
    }

    /// Splits a legacy wedding name ("groom…bride…", no separator) using the folder couple to find
    /// the boundary: the longest "<variant>-<firstname>" prefix that matches a spouse is the first
    /// person; the remainder is the other. Returns nil when no couple member matches.
    private static func splitLegacyWedding(_ segments: [String], couple: [CoupleMember]) -> [String]? {
        guard !couple.isEmpty else { return nil }
        let namesPart = segments.joined(separator: "-")

        var bestCandidate: String?
        var bestMember: CoupleMember?
        for member in couple {
            for variant in member.variants {
                let candidate = "\(variant)-\(member.firstNorm)"
                guard namesPart == candidate || namesPart.hasPrefix(candidate + "-") else { continue }
                if bestCandidate == nil || candidate.count > bestCandidate!.count {
                    bestCandidate = candidate
                    bestMember = member
                }
            }
        }
        guard let candidate = bestCandidate, let member = bestMember else { return nil }

        let remainder = namesPart == candidate ? "" : String(namesPart.dropFirst(candidate.count + 1))
        let spouse2 = splitPersonName(remainder)
        return [member.canonicalLast, member.firstNorm, spouse2.last, spouse2.first]
    }

    /// Returns the couple member a record name belongs to (matching first name + a surname variant).
    private static func resolve(last: String, first: String, in couple: [CoupleMember]) -> CoupleMember? {
        let l = FilenameBuilder.normalize(last)
        let f = FilenameBuilder.normalize(first)
        return couple.first { $0.firstNorm == f && $0.variants.contains(l) }
    }

    /// Creates/fetches a Person, first folding dit-alias surnames into the canonical couple member.
    private static func makePerson(
        last: String, first: String, defaultGender: Gender, knownGender: Bool,
        couple: [CoupleMember], registry: inout [String: Person]
    ) -> Person {
        if let member = resolve(last: last, first: first, in: couple) {
            return getOrCreatePerson(
                lastName: member.canonicalLast, firstName: member.firstNorm,
                gender: member.gender, knownGender: true, registry: &registry
            )
        }
        return getOrCreatePerson(
            lastName: last, firstName: first, gender: defaultGender,
            knownGender: knownGender, registry: &registry
        )
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
            .map { seg -> String in
                let s = String(seg)
                // Keep French-Canadian "dit" markers lowercase (e.g. "Hus dit Cournoyer").
                if ditMarkers.contains(s.lowercased()) { return s.lowercased() }
                return s.prefix(1).uppercased() + s.dropFirst()
            }
            .joined(separator: " ")
    }

    // MARK: - Person name splitting ("dit" names)

    // In French-Canadian names, "<surname> dit <alias> <firstname>" keeps the "dit <alias>"
    // with the surname. Aliases are normally one token, or two when prefixed with a Saint form
    // (e.g. "dit St-Germain").
    private static let ditMarkers: Set<String> = ["dit", "dite", "ditte", "dits", "dites"]
    private static let saintPrefixes: Set<String> = ["st", "ste", "saint", "sainte"]

    /// Splits a hyphen-joined person name into (lastName, firstName) as hyphen-joined lowercase
    /// parts, keeping any "dit <alias>" with the surname.
    static func splitPersonName(_ namesPart: String) -> (last: String, first: String) {
        let (last, first) = splitNameSegments(namesPart.split(separator: "-").map(String.init))
        return (last.joined(separator: "-"), first.joined(separator: "-"))
    }

    private static func splitNameSegments(_ segments: [String]) -> (last: [String], first: [String]) {
        guard !segments.isEmpty else { return ([], []) }
        // Use the LAST "dit" marker so chained aliases ("dit X dit Y") stay with the surname.
        if let ditIndex = segments.lastIndex(where: { ditMarkers.contains($0.lowercased()) }),
           ditIndex + 1 < segments.count {
            let aliasStart = ditIndex + 1
            var aliasEnd = aliasStart
            // A Saint-prefixed alias spans two tokens (e.g. "st-germain").
            if saintPrefixes.contains(segments[aliasStart].lowercased()), aliasStart + 1 < segments.count {
                aliasEnd = aliasStart + 1
            }
            let last = Array(segments[0...aliasEnd])
            let first = aliasEnd + 1 < segments.count ? Array(segments[(aliasEnd + 1)...]) : []
            return (last, first)
        }
        // No "dit": first token is the surname, the rest the given name.
        return ([segments[0]], Array(segments.dropFirst()))
    }

    // MARK: - Name split overrides from summary.json

    /// Builds an authoritative map from a person's joined name (e.g. "hus-dit-cournoyer-charles")
    /// to its (last, first) split, using summary.json. markedPeople (user-authored) win over
    /// AI-extracted record persons.
    private static func buildNameSplitMap(from summary: SessionSummary) -> [String: (last: String, first: String)] {
        var map: [String: (last: String, first: String)] = [:]
        for record in summary.records {
            for person in record.persons {
                guard let split = splitDisplayName(person.name), !startsWithDit(split.first) else { continue }
                map[nameKey(last: split.last, first: split.first)] =
                    (FilenameBuilder.normalize(split.last), FilenameBuilder.normalize(split.first))
            }
        }
        for mark in summary.markedPeople where !mark.lastName.isEmpty || !mark.firstName.isEmpty {
            // Skip splits that are obviously wrong (a first name never begins with "dit") — these
            // are usually stale marks saved before dit-aware parsing; the heuristic is better.
            guard !startsWithDit(mark.firstName) else { continue }
            map[nameKey(last: mark.lastName, first: mark.firstName)] =
                (FilenameBuilder.normalize(mark.lastName), FilenameBuilder.normalize(mark.firstName))
        }
        return map
    }

    /// True when a name's first word is a "dit" marker — a sign the surname/first split is wrong.
    private static func startsWithDit(_ name: String) -> Bool {
        guard let firstWord = name.split(whereSeparator: { $0 == " " || $0 == "-" }).first else { return false }
        return ditMarkers.contains(firstWord.lowercased())
    }

    /// Realigns stored marks to the people's (corrected) last/first split, matched by joined name,
    /// so a mark saved with an old split still attaches to its person.
    private static func reconcileMarks(_ marks: [PersonMark], to people: [Person]) -> [PersonMark] {
        var splitByKey: [String: (last: String, first: String)] = [:]
        for person in people {
            splitByKey[nameKey(last: person.lastName, first: person.firstName)] = (person.lastName, person.firstName)
        }
        return marks.map { mark in
            guard let split = splitByKey[nameKey(last: mark.lastName, first: mark.firstName)] else { return mark }
            var updated = mark
            updated.lastName = split.last
            updated.firstName = split.first
            return updated
        }
    }

    /// The joined-name key used to match a person against the summary map.
    private static func nameKey(last: String, first: String) -> String {
        let l = FilenameBuilder.normalize(last)
        let f = FilenameBuilder.normalize(first)
        return f.isEmpty ? l : "\(l)-\(f)"
    }

    /// Splits a "LASTNAME, Firstname" display name into (last, first), or nil if there's no comma.
    private static func splitDisplayName(_ name: String) -> (last: String, first: String)? {
        let parts = name.components(separatedBy: ",")
        guard parts.count >= 2 else { return nil }
        let last = parts[0].trimmingCharacters(in: .whitespaces)
        let first = parts[1...].joined(separator: ",").trimmingCharacters(in: .whitespaces)
        guard !last.isEmpty else { return nil }
        return (last, first)
    }

    /// Re-splits a person's name using the summary map when the joined name matches; otherwise
    /// leaves the heuristic split untouched.
    private static func applyNameSplit(_ person: Person, using map: [String: (last: String, first: String)]) -> Person {
        guard let split = map[nameKey(last: person.lastName, first: person.firstName)] else { return person }
        var updated = person
        updated.lastName = capitalize(split.last)
        updated.firstName = capitalize(split.first)
        return updated
    }
}
