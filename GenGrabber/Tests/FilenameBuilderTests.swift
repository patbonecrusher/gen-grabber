import Testing
@testable import GenGrabber

@Suite("FilenameBuilder")
struct FilenameBuilderTests {
    @Test("Single-page wedding filenames")
    func singlePageWedding() {
        let groom = Person(gender: .male, lastName: "Girard", firstName: "Joseph")
        let bride = Person(gender: .female, lastName: "Vanasse", firstName: "Marie Anne")
        var tab = RecordTab(recordType: .wedding, personIDs: [groom.id, bride.id], year: "1732")
        tab.pages[0].recordID = "d1p_1142c0453"

        let filenames = FilenameBuilder.filenames(for: tab, people: [groom, bride])

        #expect(filenames.lafrance == "1732-w-girard-joseph-vanasse-marie-anne-d1p_1142c0453-lafrance.png")
        #expect(filenames.pages[0].record == "1732-w-girard-joseph-vanasse-marie-anne-d1p_1142c0453.png")
        #expect(filenames.pages[0].closeups == ["1732-w-girard-joseph-vanasse-marie-anne-d1p_1142c0453-closeup.png"])
    }

    @Test("Multi-page wedding with different record IDs")
    func multiPageWedding() {
        let groom = Person(gender: .male, lastName: "Languirand", firstName: "Pierre")
        let bride = Person(gender: .female, lastName: "Levasseur", firstName: "Marie Anne")
        var tab = RecordTab(recordType: .wedding, personIDs: [groom.id, bride.id], year: "1787")
        tab.pages[0].recordID = "d1p_03871069"
        tab.pages.append(PageGroup(recordID: "d1p_03871070"))

        let filenames = FilenameBuilder.filenames(for: tab, people: [groom, bride])

        #expect(filenames.lafrance == "1787-w-languirand-pierre-levasseur-marie-anne-d1p_03871069-lafrance.png")
        #expect(filenames.pages[0].record == "1787-w-languirand-pierre-levasseur-marie-anne-d1p_03871069.png")
        #expect(filenames.pages[0].closeups == ["1787-w-languirand-pierre-levasseur-marie-anne-d1p_03871069-closeup.png"])
        #expect(filenames.pages[1].record == "1787-w-languirand-pierre-levasseur-marie-anne-d1p_03871070.png")
        #expect(filenames.pages[1].closeups == ["1787-w-languirand-pierre-levasseur-marie-anne-d1p_03871070-closeup.png"])
    }

    @Test("Birth filenames")
    func birth() {
        let person = Person(gender: .male, lastName: "Girard", firstName: "Joseph")
        var tab = RecordTab(recordType: .birth, personIDs: [person.id], year: "1845")
        tab.pages[0].recordID = "12345"

        let filenames = FilenameBuilder.filenames(for: tab, people: [person])

        #expect(filenames.lafrance == "1845-b-girard-joseph-12345-lafrance.png")
        #expect(filenames.pages[0].record == "1845-b-girard-joseph-12345.png")
    }

    @Test("Sepulture filenames")
    func sepulture() {
        let person = Person(gender: .female, lastName: "Vanasse", firstName: "Marie Anne")
        var tab = RecordTab(recordType: .sepulture, personIDs: [person.id], year: "1800")
        tab.pages[0].recordID = "99999"

        let filenames = FilenameBuilder.filenames(for: tab, people: [person])

        #expect(filenames.lafrance == "1800-s-vanasse-marie-anne-99999-lafrance.png")
    }

    @Test("Names are lowercased and spaces become hyphens")
    func nameNormalization() {
        let person = Person(gender: .male, lastName: "TREMBLAY", firstName: "Jean Baptiste")
        var tab = RecordTab(recordType: .birth, personIDs: [person.id], year: "1900")
        tab.pages[0].recordID = "abc"

        let filenames = FilenameBuilder.filenames(for: tab, people: [person])

        #expect(filenames.lafrance == "1900-b-tremblay-jean-baptiste-abc-lafrance.png")
    }

    @Test("Single page with multiple closeups uses numbered suffixes")
    func multipleCloseupsSamePage() {
        let person = Person(gender: .male, lastName: "Girard", firstName: "Joseph")
        var tab = RecordTab(recordType: .birth, personIDs: [person.id], year: "1845")
        tab.pages[0].recordID = "12345"

        let filenames = FilenameBuilder.filenames(for: tab, people: [person], closeupCounts: [2])

        #expect(filenames.pages[0].closeups == [
            "1845-b-girard-joseph-12345-closeup-1.png",
            "1845-b-girard-joseph-12345-closeup-2.png",
        ])
    }
}
