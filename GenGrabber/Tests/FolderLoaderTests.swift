import Foundation
import Testing
@testable import GenGrabber

@Suite("FolderLoader")
struct FolderLoaderTests {
    /// Creates a temp directory, writes empty files with the given names, runs the
    /// loader, then cleans up. Parsing only depends on filenames, so empty files suffice.
    private func loadWith(_ filenames: [String]) throws -> FolderLoader.LoadResult {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gengrabber-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        for name in filenames {
            let url = dir.appendingPathComponent(name)
            try Data().write(to: url)
        }
        return FolderLoader.load(from: dir)
    }

    @Test("New format birth parses year, type, name, and record ID")
    func newFormatBirth() throws {
        let result = try loadWith([
            "1845--b--girard-joseph--d13p_12345--lafrance.png",
            "1845--b--girard-joseph--d13p_12345.png",
        ])

        #expect(result.tabs.count == 1)
        let tab = try #require(result.tabs.first)
        #expect(tab.recordType == .birth)
        #expect(tab.year == "1845")
        #expect(tab.pages.first?.recordID == "d13p_12345")

        let person = try #require(result.people.first)
        #expect(person.lastName == "Girard")
        #expect(person.firstName == "Joseph")
    }

    @Test("New format wedding splits groom and bride on __ with correct genders")
    func newFormatWedding() throws {
        let result = try loadWith([
            "1938--w--laplante-ernest__seyer-laurette--ancestry.png",
        ])

        let tab = try #require(result.tabs.first)
        #expect(tab.recordType == .wedding)
        #expect(tab.personIDs.count == 2)

        let groom = try #require(result.people.first { $0.id == tab.personIDs[0] })
        let bride = try #require(result.people.first { $0.id == tab.personIDs[1] })
        #expect(groom.lastName == "Laplante")
        #expect(groom.firstName == "Ernest")
        #expect(groom.gender == .male)
        #expect(bride.lastName == "Seyer")
        #expect(bride.firstName == "Laurette")
        #expect(bride.gender == .female)
    }

    @Test("Legacy format preserves the full record ID")
    func legacyFormatFullRecordID() throws {
        let result = try loadWith([
            "1732-w-girard-joseph-vanasse-marie-anne-d1p_1142c0453-lafrance.png",
        ])

        let tab = try #require(result.tabs.first)
        #expect(tab.recordType == .wedding)
        #expect(tab.year == "1732")
        #expect(tab.pages.first?.recordID == "d1p_1142c0453")
    }

    @Test("New format census parses as a single-person record")
    func newFormatCensus() throws {
        let result = try loadWith([
            "1851--c--girard-joseph--census-1851.png",
        ])

        let tab = try #require(result.tabs.first)
        #expect(tab.recordType == .census)
        #expect(tab.year == "1851")
        #expect(tab.personIDs.count == 1)

        let person = try #require(result.people.first)
        #expect(person.lastName == "Girard")
        #expect(person.firstName == "Joseph")
    }

    @Test("New format legal record splits its two parties on __")
    func newFormatLegal() throws {
        let result = try loadWith([
            "1818--l--girard-joseph__vanasse-marie-anne--d1p_555.png",
        ])

        let tab = try #require(result.tabs.first)
        #expect(tab.recordType == .legal)
        #expect(tab.year == "1818")
        #expect(tab.personIDs.count == 2)
        #expect(tab.pages.first?.recordID == "d1p_555")

        let first = try #require(result.people.first { $0.id == tab.personIDs[0] })
        let second = try #require(result.people.first { $0.id == tab.personIDs[1] })
        #expect(first.lastName == "Girard")
        #expect(first.firstName == "Joseph")
        #expect(second.lastName == "Vanasse")
        #expect(second.firstName == "Marie Anne")
    }

    @Test("Unrecognized files go to the Other collection")
    func unrecognizedFileGoesToOther() throws {
        let result = try loadWith([
            "headshot-laplante-ernest.png",
        ])

        #expect(result.tabs.isEmpty)
        #expect(result.otherFiles.files.count == 1)
        #expect(result.otherFiles.files.first?.filename == "headshot-laplante-ernest.png")
    }

    @Test("Parsed text is loaded onto the matching page")
    func parsedTextRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gengrabber-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try Data().write(to: dir.appendingPathComponent("1845--b--girard-joseph--d13p_12345.png"))
        try "Transcribed text".write(
            to: dir.appendingPathComponent("1845--b--girard-joseph--d13p_12345--parsed.txt"),
            atomically: true,
            encoding: .utf8
        )

        let result = FolderLoader.load(from: dir)
        #expect(result.tabs.first?.pages.first?.parsedText == "Transcribed text")
        // The parsed .txt must not be loaded as a note.
        #expect(result.notes.allSatisfy { !$0.content.contains("Transcribed") })
    }

    @Test("Note .txt files load by title")
    func notesLoadByTitle() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gengrabber-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try "Some research notes".write(
            to: dir.appendingPathComponent("research.txt"),
            atomically: true,
            encoding: .utf8
        )

        let result = FolderLoader.load(from: dir)
        let note = try #require(result.notes.first { $0.title == "research" })
        #expect(note.content == "Some research notes")
    }

    @Test("Legacy single-dash filenames set hasLegacyFiles")
    func detectsLegacyNaming() throws {
        let legacy = try loadWith(["1845-b-girard-joseph-d1p_12345.jpg"])
        #expect(legacy.hasLegacyFiles)

        let modern = try loadWith(["1845--b--girard-joseph--d1p_12345.png"])
        #expect(!modern.hasLegacyFiles)
    }
}
