# Gen Grabber Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS SwiftUI app that lets genealogy researchers paste record screenshots into labeled slots, enter metadata, and save all images with structured filenames in one action.

**Architecture:** Single-window SwiftUI app with an observable data model. The people list and record tabs are managed by a central `SessionModel`. Each record tab owns its metadata and image data. On save, a `FileSaver` constructs filenames from the model and writes PNGs + notes.txt to a user-chosen folder via NSOpenPanel.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit (NSPasteboard for clipboard, NSOpenPanel for folder picker), macOS 14+

---

## File Structure

```
GenGrabber/
├── GenGrabberApp.swift              — App entry point, single WindowGroup
├── Models/
│   ├── Person.swift                 — Person struct (id, gender, firstName, lastName)
│   ├── RecordType.swift             — Enum: birth, wedding, sepulture
│   ├── PageGroup.swift              — Page group (recordID, record image, closeup image)
│   ├── RecordTab.swift              — A single record tab (type, people refs, year, pages, lafrance image)
│   └── SessionModel.swift           — Observable session state (people list, tabs, notes)
├── Services/
│   ├── FilenameBuilder.swift        — Builds filenames from record metadata
│   └── FileSaver.swift              — Writes images + notes to disk via folder picker
├── Views/
│   ├── ContentView.swift            — Main window layout (people list + tabs + bottom bar)
│   ├── PeopleListView.swift         — People list header with add/remove
│   ├── PersonRowView.swift          — Single person row (gender badge, names, delete)
│   ├── TabBarView.swift             — Tab bar with record tabs + creation buttons
│   ├── RecordTabView.swift          — Two-column layout for a record tab
│   ├── MetadataColumnView.swift     — Left column: people info, year, page groups, filename preview
│   ├── ImageColumnView.swift        — Right column: LaFrance slot + page group image slots
│   ├── PageGroupView.swift          — Record + closeup slots for one page
│   ├── ImageSlotView.swift          — Single paste-able image slot with states
│   ├── NotesTabView.swift           — Free-form text area for notes
│   ├── PersonPickerPopover.swift    — Popover to pick 1 or 2 people when creating a tab
│   └── FilenamePreviewView.swift    — Live filename preview
└── Tests/
    ├── FilenameBuilderTests.swift   — Filename construction tests
    └── SessionModelTests.swift      — Model logic tests
```

---

### Task 1: Create Xcode Project

**Files:**
- Create: `GenGrabber.xcodeproj` (via Xcode CLI)
- Create: `GenGrabber/GenGrabberApp.swift`

- [ ] **Step 1: Create the Swift Package / Xcode project**

```bash
cd /Users/patricklaplante/Projects/gen-grabber
mkdir -p GenGrabber/Models GenGrabber/Services GenGrabber/Views GenGrabber/Tests
```

Create `GenGrabber/Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GenGrabber",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GenGrabber",
            path: "GenGrabber",
            exclude: ["Tests"]
        ),
        .testTarget(
            name: "GenGrabberTests",
            dependencies: ["GenGrabber"],
            path: "GenGrabber/Tests"
        ),
    ]
)
```

- [ ] **Step 2: Create app entry point**

Create `GenGrabber/GenGrabberApp.swift`:

```swift
import SwiftUI

@main
struct GenGrabberApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Gen Grabber")
                .frame(minWidth: 700, minHeight: 500)
        }
        .defaultSize(width: 900, height: 600)
    }
}
```

- [ ] **Step 3: Verify it builds**

Run: `cd /Users/patricklaplante/Projects/gen-grabber && swift build`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add GenGrabber/ Package.swift
git commit -m "feat: scaffold GenGrabber SwiftUI project"
```

---

### Task 2: Data Models — Person, RecordType, PageGroup

**Files:**
- Create: `GenGrabber/Models/Person.swift`
- Create: `GenGrabber/Models/RecordType.swift`
- Create: `GenGrabber/Models/PageGroup.swift`
- Test: `GenGrabber/Tests/SessionModelTests.swift`

- [ ] **Step 1: Write Person model**

Create `GenGrabber/Models/Person.swift`:

```swift
import Foundation

enum Gender: String, CaseIterable, Sendable {
    case male = "M"
    case female = "F"
}

struct Person: Identifiable, Sendable {
    let id: UUID
    var gender: Gender
    var lastName: String
    var firstName: String

    init(id: UUID = UUID(), gender: Gender = .male, lastName: String = "", firstName: String = "") {
        self.id = id
        self.gender = gender
        self.lastName = lastName
        self.firstName = firstName
    }
}
```

- [ ] **Step 2: Write RecordType enum**

Create `GenGrabber/Models/RecordType.swift`:

```swift
import Foundation

enum RecordType: String, CaseIterable, Sendable {
    case birth = "b"
    case wedding = "w"
    case sepulture = "s"

    var label: String {
        switch self {
        case .birth: "Birth"
        case .wedding: "Wedding"
        case .sepulture: "Sepulture"
        }
    }

    var shortLabel: String {
        switch self {
        case .birth: "B"
        case .wedding: "W"
        case .sepulture: "S"
        }
    }
}
```

- [ ] **Step 3: Write PageGroup model**

Create `GenGrabber/Models/PageGroup.swift`:

```swift
import AppKit
import Foundation

struct PageGroup: Identifiable, Sendable {
    let id: UUID
    var recordID: String
    var recordImage: NSImage?
    var closeupImage: NSImage?

    init(id: UUID = UUID(), recordID: String = "", recordImage: NSImage? = nil, closeupImage: NSImage? = nil) {
        self.id = id
        self.recordID = recordID
        self.recordImage = recordImage
        self.closeupImage = closeupImage
    }
}
```

- [ ] **Step 4: Verify it builds**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add GenGrabber/Models/
git commit -m "feat: add Person, RecordType, PageGroup models"
```

---

### Task 3: Data Models — RecordTab and SessionModel

**Files:**
- Create: `GenGrabber/Models/RecordTab.swift`
- Create: `GenGrabber/Models/SessionModel.swift`

- [ ] **Step 1: Write RecordTab model**

Create `GenGrabber/Models/RecordTab.swift`:

```swift
import AppKit
import Foundation

struct RecordTab: Identifiable, Sendable {
    let id: UUID
    let recordType: RecordType
    /// For wedding: [groomID, brideID]. For birth/sepulture: [personID].
    let personIDs: [UUID]
    var year: String
    var lafranceImage: NSImage?
    var pages: [PageGroup]

    init(
        id: UUID = UUID(),
        recordType: RecordType,
        personIDs: [UUID],
        year: String = "",
        lafranceImage: NSImage? = nil
    ) {
        self.id = id
        self.recordType = recordType
        self.personIDs = personIDs
        self.year = year
        self.lafranceImage = lafranceImage
        self.pages = [PageGroup()]
    }

    var tabLabel: String {
        // Will be resolved by the view using the session's people list
        "\(recordType.shortLabel)"
    }
}
```

- [ ] **Step 2: Write SessionModel**

Create `GenGrabber/Models/SessionModel.swift`:

```swift
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
```

- [ ] **Step 3: Verify it builds**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add GenGrabber/Models/RecordTab.swift GenGrabber/Models/SessionModel.swift
git commit -m "feat: add RecordTab and SessionModel"
```

---

### Task 4: FilenameBuilder Service

**Files:**
- Create: `GenGrabber/Services/FilenameBuilder.swift`
- Create: `GenGrabber/Tests/FilenameBuilderTests.swift`

- [ ] **Step 1: Write failing tests for filename construction**

Create `GenGrabber/Tests/FilenameBuilderTests.swift`:

```swift
import Testing
@testable import GenGrabber

@Suite("FilenameBuilder")
struct FilenameBuilderTests {
    @Test("Single-page wedding filenames")
    func singlePageWedding() {
        let groom = Person(gender: .male, lastName: "Girard", firstName: "Joseph")
        let bride = Person(gender: .female, lastName: "Vanasse", firstName: "Marie Anne")
        let tab = RecordTab(recordType: .wedding, personIDs: [groom.id, bride.id], year: "1732")
        var modifiedTab = tab
        modifiedTab.pages[0].recordID = "d1p_1142c0453"

        let people = [groom, bride]
        let filenames = FilenameBuilder.filenames(for: modifiedTab, people: people)

        #expect(filenames.lafrance == "1732-(w)-girard-joseph-vanasse-marie-anne-d1p_1142c0453-lafrance.png")
        #expect(filenames.pages[0].record == "1732-(w)-girard-joseph-vanasse-marie-anne-d1p_1142c0453.png")
        #expect(filenames.pages[0].closeups == ["1732-(w)-girard-joseph-vanasse-marie-anne-d1p_1142c0453-closeup.png"])
    }

    @Test("Multi-page wedding with different record IDs")
    func multiPageWedding() {
        let groom = Person(gender: .male, lastName: "Languirand", firstName: "Pierre")
        let bride = Person(gender: .female, lastName: "Levasseur", firstName: "Marie Anne")
        var tab = RecordTab(recordType: .wedding, personIDs: [groom.id, bride.id], year: "1787")
        tab.pages[0].recordID = "d1p_03871069"
        tab.pages.append(PageGroup(recordID: "d1p_03871070"))

        let people = [groom, bride]
        let filenames = FilenameBuilder.filenames(for: tab, people: people)

        #expect(filenames.lafrance == "1787-(w)-languirand-pierre-levasseur-marie-anne-d1p_03871069-lafrance.png")
        #expect(filenames.pages[0].record == "1787-(w)-languirand-pierre-levasseur-marie-anne-d1p_03871069.png")
        #expect(filenames.pages[0].closeups == ["1787-(w)-languirand-pierre-levasseur-marie-anne-d1p_03871069-closeup.png"])
        #expect(filenames.pages[1].record == "1787-(w)-languirand-pierre-levasseur-marie-anne-d1p_03871070.png")
        #expect(filenames.pages[1].closeups == ["1787-(w)-languirand-pierre-levasseur-marie-anne-d1p_03871070-closeup.png"])
    }

    @Test("Birth filenames")
    func birth() {
        let person = Person(gender: .male, lastName: "Girard", firstName: "Joseph")
        var tab = RecordTab(recordType: .birth, personIDs: [person.id], year: "1845")
        tab.pages[0].recordID = "12345"

        let filenames = FilenameBuilder.filenames(for: tab, people: [person])

        #expect(filenames.lafrance == "1845-(b)-girard-joseph-12345-lafrance.png")
        #expect(filenames.pages[0].record == "1845-(b)-girard-joseph-12345.png")
    }

    @Test("Sepulture filenames")
    func sepulture() {
        let person = Person(gender: .female, lastName: "Vanasse", firstName: "Marie Anne")
        var tab = RecordTab(recordType: .sepulture, personIDs: [person.id], year: "1800")
        tab.pages[0].recordID = "99999"

        let filenames = FilenameBuilder.filenames(for: tab, people: [person])

        #expect(filenames.lafrance == "1800-(s)-vanasse-marie-anne-99999-lafrance.png")
    }

    @Test("Names are lowercased and spaces become hyphens")
    func nameNormalization() {
        let person = Person(gender: .male, lastName: "TREMBLAY", firstName: "Jean Baptiste")
        var tab = RecordTab(recordType: .birth, personIDs: [person.id], year: "1900")
        tab.pages[0].recordID = "abc"

        let filenames = FilenameBuilder.filenames(for: tab, people: [person])

        #expect(filenames.lafrance == "1900-(b)-tremblay-jean-baptiste-abc-lafrance.png")
    }

    @Test("Single page with multiple closeups uses numbered suffixes")
    func multipleCloseupsSamePage() {
        let person = Person(gender: .male, lastName: "Girard", firstName: "Joseph")
        var tab = RecordTab(recordType: .birth, personIDs: [person.id], year: "1845")
        tab.pages[0].recordID = "12345"

        let filenames = FilenameBuilder.filenames(for: tab, people: [person], closeupCounts: [2])

        #expect(filenames.pages[0].closeups == [
            "1845-(b)-girard-joseph-12345-closeup-1.png",
            "1845-(b)-girard-joseph-12345-closeup-2.png",
        ])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: Compilation error — `FilenameBuilder` not defined

- [ ] **Step 3: Implement FilenameBuilder**

Create `GenGrabber/Services/FilenameBuilder.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add GenGrabber/Services/FilenameBuilder.swift GenGrabber/Tests/FilenameBuilderTests.swift
git commit -m "feat: add FilenameBuilder with filename construction logic"
```

---

### Task 5: FileSaver Service

**Files:**
- Create: `GenGrabber/Services/FileSaver.swift`

- [ ] **Step 1: Implement FileSaver**

Create `GenGrabber/Services/FileSaver.swift`:

```swift
import AppKit
import Foundation

enum FileSaver {
    struct SaveResult: Sendable {
        let fileCount: Int
        let folder: URL
    }

    @MainActor
    static func saveAll(session: SessionModel) async -> SaveResult? {
        guard let folderURL = pickFolder() else { return nil }

        var fileCount = 0

        for tabIndex in session.tabs.indices {
            let tab = session.tabs[tabIndex]
            let people = session.people
            let closeupCounts = tab.pages.map { _ in 1 } // Each page has 1 closeup slot
            let filenames = FilenameBuilder.filenames(for: tab, people: people, closeupCounts: closeupCounts)

            // Save LaFrance
            if let image = tab.lafranceImage {
                if saveImage(image, named: filenames.lafrance, to: folderURL) {
                    fileCount += 1
                }
            }

            // Save page images
            for (pageIndex, page) in tab.pages.enumerated() {
                guard pageIndex < filenames.pages.count else { continue }
                let pageFilenames = filenames.pages[pageIndex]

                if let image = page.recordImage {
                    if saveImage(image, named: pageFilenames.record, to: folderURL) {
                        fileCount += 1
                    }
                }

                if let image = page.closeupImage {
                    let closeupName = pageFilenames.closeups.first ?? ""
                    if saveImage(image, named: closeupName, to: folderURL) {
                        fileCount += 1
                    }
                }
            }
        }

        // Save notes
        if !session.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let notesURL = folderURL.appendingPathComponent("notes.txt")
            try? session.notes.write(to: notesURL, atomically: true, encoding: .utf8)
            fileCount += 1
        }

        return SaveResult(fileCount: fileCount, folder: folderURL)
    }

    private static func saveImage(_ image: NSImage, named filename: String, to folder: URL) -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else { return false }

        let fileURL = folder.appendingPathComponent(filename)
        do {
            try pngData.write(to: fileURL)
            return true
        } catch {
            return false
        }
    }

    @MainActor
    private static func pickFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Save Here"
        panel.message = "Choose a folder to save all record images"

        return panel.runModal() == .OK ? panel.url : nil
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add GenGrabber/Services/FileSaver.swift
git commit -m "feat: add FileSaver with folder picker and PNG export"
```

---

### Task 6: ImageSlotView — Paste-able Image Drop Zone

**Files:**
- Create: `GenGrabber/Views/ImageSlotView.swift`

- [ ] **Step 1: Implement ImageSlotView**

Create `GenGrabber/Views/ImageSlotView.swift`:

```swift
import SwiftUI

struct ImageSlotView: View {
    let label: String
    @Binding var image: NSImage?
    @State private var isFocused = false
    @State private var showPreview = false

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 120)
                        .onTapGesture { showPreview = true }
                        .overlay(alignment: .topTrailing) {
                            Button {
                                self.image = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .padding(4)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isFocused ? Color.accentColor : Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [6])
                        )
                        .frame(minHeight: 60)
                        .overlay {
                            Text("Paste here")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { isFocused = true }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(image != nil ? Color.green.opacity(0.08) : Color.clear)
            )
            .focusable()
            .focused($isFocused)
            .onKeyPress(.init("v"), modifiers: .command) {
                pasteFromClipboard()
                return .handled
            }
        }
        .sheet(isPresented: $showPreview) {
            if let image {
                VStack {
                    HStack {
                        Spacer()
                        Button("Close") { showPreview = false }
                            .padding()
                    }
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
                .frame(minWidth: 600, minHeight: 400)
            }
        }
    }

    @State private var _isFocused = false

    private func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        guard let pasteboardImage = NSImage(pasteboard: pasteboard) else { return }
        image = pasteboardImage
    }
}

extension ImageSlotView {
    func focused(_ isFocused: Binding<Bool>) -> some View {
        // SwiftUI focus tracking handled via .focusable()
        self
    }
}
```

Note: The `focused` and `onKeyPress` APIs may need adjustment based on the exact SwiftUI version. The core idea is: click to focus, Cmd+V to paste from NSPasteboard.

- [ ] **Step 2: Verify it builds**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add GenGrabber/Views/ImageSlotView.swift
git commit -m "feat: add ImageSlotView with clipboard paste support"
```

---

### Task 7: PeopleListView and PersonRowView

**Files:**
- Create: `GenGrabber/Views/PeopleListView.swift`
- Create: `GenGrabber/Views/PersonRowView.swift`

- [ ] **Step 1: Implement PersonRowView**

Create `GenGrabber/Views/PersonRowView.swift`:

```swift
import SwiftUI

struct PersonRowView: View {
    @Bindable var session: SessionModel
    let personID: UUID

    private var personIndex: Int? {
        session.people.firstIndex { $0.id == personID }
    }

    var body: some View {
        if let index = personIndex {
            HStack(spacing: 8) {
                // Gender badge
                Picker("", selection: $session.people[index].gender) {
                    Text("M").tag(Gender.male)
                    Text("F").tag(Gender.female)
                }
                .labelsHidden()
                .frame(width: 50)

                TextField("Last Name", text: $session.people[index].lastName)
                    .textFieldStyle(.roundedBorder)

                TextField("First Name", text: $session.people[index].firstName)
                    .textFieldStyle(.roundedBorder)

                Button {
                    session.removePerson(personID)
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .disabled(session.isPersonReferenced(personID))
                .help(session.isPersonReferenced(personID)
                    ? "Cannot remove — referenced by a record tab"
                    : "Remove person")
            }
        }
    }
}
```

- [ ] **Step 2: Implement PeopleListView**

Create `GenGrabber/Views/PeopleListView.swift`:

```swift
import SwiftUI

struct PeopleListView: View {
    @Bindable var session: SessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("PEOPLE")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ForEach(session.people) { person in
                PersonRowView(session: session, personID: person.id)
            }

            Button {
                session.addPerson()
            } label: {
                Label("Add Person", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.accent)
        }
        .padding(12)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 3: Verify it builds**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add GenGrabber/Views/PeopleListView.swift GenGrabber/Views/PersonRowView.swift
git commit -m "feat: add PeopleListView and PersonRowView"
```

---

### Task 8: PersonPickerPopover

**Files:**
- Create: `GenGrabber/Views/PersonPickerPopover.swift`

- [ ] **Step 1: Implement PersonPickerPopover**

Create `GenGrabber/Views/PersonPickerPopover.swift`:

```swift
import SwiftUI

struct PersonPickerPopover: View {
    let recordType: RecordType
    let people: [Person]
    let onSelect: ([UUID]) -> Void
    let onCancel: () -> Void

    @State private var selectedFirst: UUID?
    @State private var selectedSecond: UUID?

    private var isWedding: Bool { recordType == .wedding }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select \(isWedding ? "Groom & Bride" : "Person")")
                .font(.headline)

            if isWedding {
                Text("Groom:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(people) { person in
                let isSelectedFirst = selectedFirst == person.id
                let isSelectedSecond = selectedSecond == person.id
                let isDisabled = isWedding && (isSelectedFirst && selectedSecond == nil ? false : isSelectedSecond)

                Button {
                    if isWedding {
                        if selectedFirst == nil {
                            selectedFirst = person.id
                        } else if selectedFirst == person.id {
                            selectedFirst = nil
                        } else if selectedSecond == nil {
                            selectedSecond = person.id
                        } else if selectedSecond == person.id {
                            selectedSecond = nil
                        }
                    } else {
                        selectedFirst = person.id
                    }
                } label: {
                    HStack {
                        Text(person.gender.rawValue)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(person.gender == .male ? .blue : .pink)
                            .frame(width: 20)
                        Text("\(person.lastName), \(person.firstName)")
                        Spacer()
                        if isSelectedFirst {
                            Text(isWedding ? "Groom" : "Selected")
                                .font(.caption2)
                                .foregroundStyle(.accent)
                        }
                        if isSelectedSecond {
                            Text("Bride")
                                .font(.caption2)
                                .foregroundStyle(.pink)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        (isSelectedFirst || isSelectedSecond)
                            ? Color.accentColor.opacity(0.1)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }

            if isWedding && selectedFirst != nil {
                Text("Bride:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel") { onCancel() }
                Spacer()
                Button("Create") {
                    if isWedding, let first = selectedFirst, let second = selectedSecond {
                        onSelect([first, second])
                    } else if !isWedding, let first = selectedFirst {
                        onSelect([first])
                    }
                }
                .disabled(isWedding ? (selectedFirst == nil || selectedSecond == nil) : selectedFirst == nil)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 260)
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add GenGrabber/Views/PersonPickerPopover.swift
git commit -m "feat: add PersonPickerPopover for tab creation"
```

---

### Task 9: TabBarView

**Files:**
- Create: `GenGrabber/Views/TabBarView.swift`

- [ ] **Step 1: Implement TabBarView**

Create `GenGrabber/Views/TabBarView.swift`:

```swift
import SwiftUI

struct TabBarView: View {
    @Bindable var session: SessionModel
    @State private var showPickerFor: RecordType?

    var body: some View {
        HStack(spacing: 0) {
            // Record tabs
            ForEach(session.tabs) { tab in
                TabButton(
                    label: session.tabLabel(for: tab),
                    isSelected: session.selectedTabID == tab.id,
                    onSelect: { session.selectedTabID = tab.id },
                    onClose: { session.removeTab(tab.id) }
                )
            }

            // Notes tab
            TabButton(
                label: "Notes",
                isSelected: session.selectedTabID == nil,
                isCloseable: false,
                onSelect: { session.selectedTabID = nil },
                onClose: {}
            )

            Spacer()

            // Creation buttons
            HStack(spacing: 4) {
                AddTabButton(label: "+ Birth", color: .green) {
                    showPickerFor = .birth
                }
                AddTabButton(label: "+ Wedding", color: .blue) {
                    showPickerFor = .wedding
                }
                AddTabButton(label: "+ Sepulture", color: .red) {
                    showPickerFor = .sepulture
                }
            }
            .popover(item: $showPickerFor) { type in
                PersonPickerPopover(
                    recordType: type,
                    people: session.people,
                    onSelect: { personIDs in
                        session.addTab(type: type, personIDs: personIDs)
                        showPickerFor = nil
                    },
                    onCancel: { showPickerFor = nil }
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

extension RecordType: @retroactive Identifiable {
    public var id: String { rawValue }
}

private struct TabButton: View {
    let label: String
    let isSelected: Bool
    var isCloseable: Bool = true
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .lineLimit(1)

            if isCloseable {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onTapGesture { onSelect() }
    }
}

private struct AddTabButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .buttonStyle(.bordered)
        .tint(color)
        .controlSize(.small)
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add GenGrabber/Views/TabBarView.swift
git commit -m "feat: add TabBarView with record creation buttons"
```

---

### Task 10: Record Tab Views (MetadataColumn, ImageColumn, PageGroup)

**Files:**
- Create: `GenGrabber/Views/PageGroupView.swift`
- Create: `GenGrabber/Views/FilenamePreviewView.swift`
- Create: `GenGrabber/Views/MetadataColumnView.swift`
- Create: `GenGrabber/Views/ImageColumnView.swift`
- Create: `GenGrabber/Views/RecordTabView.swift`

- [ ] **Step 1: Implement PageGroupView**

Create `GenGrabber/Views/PageGroupView.swift`:

```swift
import SwiftUI

struct PageGroupView: View {
    let pageNumber: Int
    @Binding var page: PageGroup
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("PAGE \(pageNumber)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.accent)

                if !page.recordID.isEmpty {
                    Text("— \(page.recordID)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if canRemove {
                    Button { onRemove() } label: {
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                ImageSlotView(label: "Record", image: $page.recordImage)
                ImageSlotView(label: "Closeup", image: $page.closeupImage)
            }
        }
        .padding(8)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 2: Implement FilenamePreviewView**

Create `GenGrabber/Views/FilenamePreviewView.swift`:

```swift
import SwiftUI

struct FilenamePreviewView: View {
    let tab: RecordTab
    let people: [Person]

    var body: some View {
        let filenames = FilenameBuilder.filenames(for: tab, people: people)

        VStack(alignment: .leading, spacing: 2) {
            Text("FILENAMES")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 1) {
                filenameRow(filenames.lafrance)
                ForEach(Array(filenames.pages.enumerated()), id: \.offset) { _, page in
                    filenameRow(page.record)
                    ForEach(page.closeups, id: \.self) { closeup in
                        filenameRow(closeup)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func filenameRow(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.green.opacity(0.8))
            .lineLimit(1)
            .truncationMode(.middle)
    }
}
```

- [ ] **Step 3: Implement MetadataColumnView**

Create `GenGrabber/Views/MetadataColumnView.swift`:

```swift
import SwiftUI

struct MetadataColumnView: View {
    @Bindable var session: SessionModel
    let tabIndex: Int

    private var tab: RecordTab { session.tabs[tabIndex] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // People info (read-only)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(tab.personIDs, id: \.self) { personID in
                    if let person = session.person(for: personID) {
                        HStack(spacing: 4) {
                            Text(person.gender == .male ? "M" : "F")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(person.gender == .male ? .blue : .pink)
                            Text("\(person.lastName), \(person.firstName)")
                                .font(.caption)
                        }
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Year
            VStack(alignment: .leading, spacing: 2) {
                Text("YEAR")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                TextField("Year", text: $session.tabs[tabIndex].year)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospacedDigit())
            }

            // Page groups
            ForEach(Array(session.tabs[tabIndex].pages.indices), id: \.self) { pageIndex in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("PAGE \(pageIndex + 1)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.accent)
                        Spacer()
                        if pageIndex > 0 {
                            Button {
                                session.tabs[tabIndex].pages.remove(at: pageIndex)
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("RECORD ID")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        TextField("Record ID", text: $session.tabs[tabIndex].pages[pageIndex].recordID)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospaced())
                    }
                }
                .padding(8)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Add page button
            Button {
                session.tabs[tabIndex].pages.append(PageGroup())
            } label: {
                Label("Add Page", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.accent)

            Spacer()

            // Filename preview
            FilenamePreviewView(tab: tab, people: session.people)
        }
        .frame(width: 200)
    }
}
```

- [ ] **Step 4: Implement ImageColumnView**

Create `GenGrabber/Views/ImageColumnView.swift`:

```swift
import SwiftUI

struct ImageColumnView: View {
    @Bindable var session: SessionModel
    let tabIndex: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // LaFrance — always one
                VStack(alignment: .leading, spacing: 4) {
                    Text("LAFRANCE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    ImageSlotView(
                        label: "",
                        image: $session.tabs[tabIndex].lafranceImage
                    )
                }

                // Page groups
                ForEach(Array(session.tabs[tabIndex].pages.indices), id: \.self) { pageIndex in
                    PageGroupView(
                        pageNumber: pageIndex + 1,
                        page: $session.tabs[tabIndex].pages[pageIndex],
                        canRemove: pageIndex > 0,
                        onRemove: {
                            session.tabs[tabIndex].pages.remove(at: pageIndex)
                        }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}
```

- [ ] **Step 5: Implement RecordTabView**

Create `GenGrabber/Views/RecordTabView.swift`:

```swift
import SwiftUI

struct RecordTabView: View {
    @Bindable var session: SessionModel
    let tabIndex: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MetadataColumnView(session: session, tabIndex: tabIndex)
            ImageColumnView(session: session, tabIndex: tabIndex)
        }
        .padding(12)
    }
}
```

- [ ] **Step 6: Verify it builds**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 7: Commit**

```bash
git add GenGrabber/Views/PageGroupView.swift GenGrabber/Views/FilenamePreviewView.swift GenGrabber/Views/MetadataColumnView.swift GenGrabber/Views/ImageColumnView.swift GenGrabber/Views/RecordTabView.swift
git commit -m "feat: add record tab views (metadata column, image column, page groups)"
```

---

### Task 11: NotesTabView

**Files:**
- Create: `GenGrabber/Views/NotesTabView.swift`

- [ ] **Step 1: Implement NotesTabView**

Create `GenGrabber/Views/NotesTabView.swift`:

```swift
import SwiftUI

struct NotesTabView: View {
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Notes")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextEditor(text: $notes)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Saved as notes.txt — leave empty to skip")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add GenGrabber/Views/NotesTabView.swift
git commit -m "feat: add NotesTabView"
```

---

### Task 12: ContentView — Main Window Assembly

**Files:**
- Create: `GenGrabber/Views/ContentView.swift`
- Modify: `GenGrabber/GenGrabberApp.swift`

- [ ] **Step 1: Implement ContentView**

Create `GenGrabber/Views/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @State private var session = SessionModel()
    @State private var showClearConfirmation = false
    @State private var saveResult: FileSaver.SaveResult?
    @State private var showSaveConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // People list
            PeopleListView(session: session)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Tab bar
            TabBarView(session: session)

            Divider()

            // Tab content
            Group {
                if let selectedID = session.selectedTabID,
                   let tabIndex = session.tabs.firstIndex(where: { $0.id == selectedID }) {
                    RecordTabView(session: session, tabIndex: tabIndex)
                } else {
                    NotesTabView(notes: $session.notes)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Bottom bar
            HStack {
                Text("\(session.tabs.count) records, \(session.totalImageCount) images")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Clear All") {
                    showClearConfirmation = true
                }
                .controlSize(.small)

                Button("Save All...") {
                    Task {
                        if let result = await FileSaver.saveAll(session: session) {
                            saveResult = result
                            showSaveConfirmation = true
                        }
                    }
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 700, minHeight: 500)
        .alert("Clear All?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                session.clearAll()
            }
        } message: {
            Text("This will remove all people, records, and images. This cannot be undone.")
        }
        .alert("Saved", isPresented: $showSaveConfirmation) {
            Button("OK") {}
        } message: {
            if let result = saveResult {
                Text("Saved \(result.fileCount) files to \(result.folder.lastPathComponent)/")
            }
        }
    }
}
```

- [ ] **Step 2: Update GenGrabberApp.swift**

Replace the contents of `GenGrabber/GenGrabberApp.swift`:

```swift
import SwiftUI

@main
struct GenGrabberApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 900, height: 600)
    }
}
```

- [ ] **Step 3: Verify it builds**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add GenGrabber/Views/ContentView.swift GenGrabber/GenGrabberApp.swift
git commit -m "feat: assemble ContentView main window with all components"
```

---

### Task 13: Integration Test — Manual Smoke Test

- [ ] **Step 1: Run the app**

Run: `swift run` or open in Xcode and run.

- [ ] **Step 2: Smoke test checklist**

Test each of these manually:
1. Add 2-3 people in the people list
2. Click "+ Wedding" — pick groom and bride from popover
3. Enter year and record ID
4. Click the LaFrance image slot, then Cmd+V to paste a screenshot
5. Click the Record slot, paste another image
6. Click the Closeup slot, paste another image
7. Click "+ Add Page" — enter second record ID, paste images
8. Click "+ Birth" — pick a person
9. Click the Notes tab — type some notes
10. Click "Save All..." — pick a folder
11. Verify files are saved with correct names
12. Verify notes.txt is saved
13. Click "Clear All" — verify everything resets

- [ ] **Step 3: Fix any issues found during smoke test**

Address any build errors, layout issues, or functionality bugs.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: address issues found in smoke testing"
```

---

### Task 14: Run All Tests and Final Cleanup

- [ ] **Step 1: Run all tests**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 2: Clean up any compiler warnings**

Run: `swift build 2>&1 | grep -i warning`
Fix any warnings found.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "chore: final cleanup and all tests passing"
```
