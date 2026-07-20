import Foundation
import Testing
@testable import GenGrabber

@Suite("NameSplitting")
struct NameSplittingTests {
    // MARK: - "dit" heuristic

    @Test("dit alias stays with the surname")
    func ditWithSurname() {
        let n = FolderLoader.splitPersonName("hus-dit-cournoyer-charles")
        #expect(n.last == "hus-dit-cournoyer")
        #expect(n.first == "charles")
    }

    @Test("Saint-prefixed alias spans two tokens")
    func saintAlias() {
        let n = FolderLoader.splitPersonName("gazaille-dit-st-germain-francois")
        #expect(n.last == "gazaille-dit-st-germain")
        #expect(n.first == "francois")
    }

    @Test("Chained dit aliases all stay with the surname")
    func chainedDit() {
        let n = FolderLoader.splitPersonName("joyal-dit-quercy-dit-perrot-antoine")
        #expect(n.last == "joyal-dit-quercy-dit-perrot")
        #expect(n.first == "antoine")
    }

    @Test("dit variants and compound first names")
    func variantsAndCompoundFirst() {
        let a = FolderLoader.splitPersonName("dumais-dit-demers-marie-francoise")
        #expect(a.last == "dumais-dit-demers")
        #expect(a.first == "marie-francoise")

        let b = FolderLoader.splitPersonName("messier-ditte-st-francois-josephe")
        #expect(b.last == "messier-ditte-st-francois")
        #expect(b.first == "josephe")
    }

    @Test("Names without dit keep the original first-token-is-surname split")
    func noDit() {
        let n = FolderLoader.splitPersonName("duval-madeleine")
        #expect(n.last == "duval")
        #expect(n.first == "madeleine")
    }

    @Test("Saint-prefixed surname without dit spans two tokens")
    func saintSurname() {
        let a = FolderLoader.splitPersonName("st-martin-pierre-antoine")
        #expect(a.last == "st-martin")
        #expect(a.first == "pierre-antoine")

        let b = FolderLoader.splitPersonName("sainte-marie-josephe")
        #expect(b.last == "sainte-marie")
        #expect(b.first == "josephe")
    }

    // MARK: - summary.json overrides

    private func loadWith(_ filenames: [String], summaryJSON: String? = nil) throws -> FolderLoader.LoadResult {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gengrabber-names-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for name in filenames {
            try Data().write(to: dir.appendingPathComponent(name))
        }
        if let summaryJSON {
            try Data(summaryJSON.utf8).write(to: dir.appendingPathComponent("summary.json"))
        }
        return FolderLoader.load(from: dir)
    }

    @Test("Heuristic alone handles a dit birth name")
    func heuristicBirth() throws {
        let result = try loadWith(["1850--b--hus-dit-cournoyer-charles--d1p_1.png"])
        let person = try #require(result.people.first)
        #expect(person.lastName == "Hus dit Cournoyer")
        #expect(person.firstName == "Charles")
    }

    @Test("summary.json record persons override an ambiguous split")
    func recordOverride() throws {
        // Heuristic guesses last="X dit Foo", first="Bar Baptiste" (alias = one token);
        // the summary says the alias is two tokens.
        let summary = """
        {"records":[{"id":"00000000-0000-0000-0000-000000000001","recordType":"Birth","date":"","parish":"","region":"","documentFilename":"","persons":[{"id":"00000000-0000-0000-0000-000000000002","name":"X dit Foo Bar, Baptiste","role":"","maritalStatus":"","sex":"","age":"","occupation":""}]}]}
        """
        let result = try loadWith(["1850--b--x-dit-foo-bar-baptiste--d1p_1.png"], summaryJSON: summary)
        let person = try #require(result.people.first)
        #expect(person.lastName == "X dit Foo Bar")
        #expect(person.firstName == "Baptiste")
    }

    @Test("A stale mark with a wrong dit split is rejected and realigned to the person")
    func staleMarkReconciled() throws {
        // Saved before dit-aware parsing: lastName "Fontaine", firstName "Dit Bienvenue Pierre".
        let summary = """
        {"records":[],"markedPeople":[{"id":"00000000-0000-0000-0000-000000000004","lastName":"Fontaine","firstName":"Dit Bienvenue Pierre","statuses":["immigrant"],"origin":"France"}]}
        """
        let result = try loadWith(["1668--b--fontaine-dit-bienvenue-pierre--d1p_1.png"], summaryJSON: summary)

        let person = try #require(result.people.first)
        #expect(person.lastName == "Fontaine dit Bienvenue")
        #expect(person.firstName == "Pierre")

        // The mark is realigned to the corrected split, keeping its statuses/origin.
        let mark = try #require(result.summary.markedPeople.first)
        #expect(mark.lastName == "Fontaine dit Bienvenue")
        #expect(mark.firstName == "Pierre")
        #expect(mark.statuses == [.immigrant])
        #expect(mark.origin == "France")
    }

    @Test("markedPeople override an ambiguous split")
    func markedPeopleOverride() throws {
        let summary = """
        {"records":[],"markedPeople":[{"id":"00000000-0000-0000-0000-000000000003","lastName":"X dit Foo Bar","firstName":"Baptiste","statuses":[],"origin":""}]}
        """
        let result = try loadWith(["1850--b--x-dit-foo-bar-baptiste--d1p_1.png"], summaryJSON: summary)
        let person = try #require(result.people.first)
        #expect(person.lastName == "X dit Foo Bar")
        #expect(person.firstName == "Baptiste")
    }

    // MARK: - Folder-name couple unification

    private func loadFolder(named name: String, files: [String]) throws -> FolderLoader.LoadResult {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("gengrabber-couple-\(UUID().uuidString)")
        let dir = parent.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        for file in files {
            try Data().write(to: dir.appendingPathComponent(file))
        }
        return FolderLoader.load(from: dir)
    }

    @Test("A folder spouse with no records still appears in the people list")
    func folderSpouseWithoutRecords() throws {
        // Only the husband has a record; the wife (Gagnon Marie) has none.
        let result = try loadFolder(
            named: "0100-0101--tremblay-jean__gagnon-marie",
            files: ["1800-b-tremblay-jean-d1p_1.jpg"]
        )

        #expect(result.people.count == 2)
        let husband = try #require(result.people.first { $0.lastName == "Tremblay" })
        #expect(husband.firstName == "Jean")
        #expect(husband.gender == .male)

        let wife = try #require(result.people.first { $0.lastName == "Gagnon" })
        #expect(wife.firstName == "Marie")
        #expect(wife.gender == .female)
    }

    @Test("An empty note is auto-created for each person, titled by name")
    func autoNotePerPerson() throws {
        let result = try loadFolder(
            named: "0100-0101--tremblay-jean__gagnon-marie",
            files: ["1800-b-tremblay-jean-d1p_1.jpg"]  // only Jean has a record
        )

        // A note per person (both spouses), even the one with no records.
        let jean = try #require(result.notes.first { $0.title == "tremblay-jean" })
        #expect(jean.content.isEmpty)
        let marie = try #require(result.notes.first { $0.title == "gagnon-marie" })
        #expect(marie.content.isEmpty)
    }

    @Test("An existing note for a person is reused, not duplicated")
    func autoNoteReusesExisting() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gengrabber-notes-\(UUID().uuidString)/0100-0101--tremblay-jean__gagnon-marie")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
        try Data().write(to: dir.appendingPathComponent("1800-b-tremblay-jean-d1p_1.jpg"))
        try "Born in Sorel.".write(to: dir.appendingPathComponent("tremblay-jean.txt"), atomically: true, encoding: .utf8)

        let result = FolderLoader.load(from: dir)

        let jeanNotes = result.notes.filter { $0.title == "tremblay-jean" }
        #expect(jeanNotes.count == 1)
        #expect(jeanNotes.first?.content == "Born in Sorel.")
    }

    @Test("A folder spouse is not duplicated when they do have records")
    func folderSpouseNotDuplicated() throws {
        let result = try loadFolder(
            named: "0100-0101--tremblay-jean__gagnon-marie",
            files: [
                "1800-b-tremblay-jean-d1p_1.jpg",
                "1802-b-gagnon-marie-d1p_2.jpg",
            ]
        )
        #expect(result.people.count == 2)
    }

    @Test("dit-alias surnames across records unify to one spouse from the folder name")
    func ditAliasUnification() throws {
        // Husband recorded as "jared" in one record and "beauregard" in another; the folder
        // name "jared-dit-beauregard-pierre" says they're the same man.
        let result = try loadFolder(
            named: "0450-0451--jared-dit-beauregard-pierre__burelle-marguerite",
            files: [
                "1735-b-jared-pierre-d1p_1.jpg",
                "1811-s-beauregard-pierre-d1p_2.jpg",
                "1737-b-burelle-marguerite-d1p_3.jpg",
            ]
        )

        // Two people — the husband is not split into Jared + Beauregard.
        #expect(result.people.count == 2)
        let husband = try #require(result.people.first { $0.gender == .male })
        #expect(husband.lastName == "Jared dit Beauregard")
        #expect(husband.firstName == "Pierre")
        #expect(husband.gender == .male)
        #expect(!result.people.contains { $0.lastName == "Beauregard" })

        // Both of his records (birth + sepulture) reference the same person.
        let hisTabs = result.tabs.filter { $0.personIDs == [husband.id] }
        #expect(hisTabs.count == 2)
    }

    @Test("Legacy wedding with a multi-word dit groom splits correctly using the folder couple")
    func legacyWeddingDitSplit() throws {
        let result = try loadFolder(
            named: "0448-0449--meunier-dit-lapierre-pierre__lussier-marguerite",
            files: [
                "1693-b-meunier-dit-lapierre-pierre-d1p_1.jpg",
                "1743-w-meunier-dit-lapierre-pierre-charron-jeanne-d1p_2.jpg",  // first marriage
                "1749-w-meunier-dit-lapierre-pierre-lussier-marguerite-d1p_3.jpg",  // folder couple
                "1731-b-lussier-marguerite-d1p_4.jpg",
            ]
        )

        // Exactly three people: Pierre, his first wife Jeanne, and Marguerite.
        #expect(result.people.count == 3)

        let husband = try #require(result.people.first { $0.gender == .male })
        #expect(husband.lastName == "Meunier dit Lapierre")
        #expect(husband.firstName == "Pierre")

        #expect(result.people.contains { $0.lastName == "Charron" && $0.firstName == "Jeanne" })
        #expect(result.people.contains { $0.lastName == "Lussier" && $0.firstName == "Marguerite" })

        // None of the old broken splits.
        #expect(!result.people.contains { $0.firstName == "dit" })
        #expect(!result.people.contains { $0.lastName == "Lapierre" })
    }

    @Test("Legacy wedding where the folder bride remarried an outside dit-alias groom")
    func legacyWeddingRemarriedBride() throws {
        let result = try loadFolder(
            named: "0184-0185--chicoine-augustin__dion-dit-dutily-therese",
            files: [
                "1755-b-chicoine-augustin-d1p_1.jpg",
                "1764-b-dion-therese-d1p_2.jpg",
                "1786-w-chicoine-augustin-dion-therese-d1p_3.jpg",  // folder couple
                // Thérèse's second marriage: the groom is an outside name with a dit alias,
                // and the matching spouse (dion-therese) is at the END of the wedding name.
                "1816-w-benoit-dit-livernoit-vincent-dion-therese-d1p_4.jpg",
            ]
        )

        // Exactly three people: Augustin, Thérèse, and her second husband Vincent.
        #expect(result.people.count == 3)

        let vincent = try #require(result.people.first { $0.firstName == "Vincent" })
        #expect(vincent.lastName == "Benoit dit Livernoit")
        #expect(vincent.gender == .male)

        // Thérèse is unified to one person across both weddings + her birth.
        let therese = try #require(result.people.first { $0.firstName == "Therese" })
        #expect(therese.lastName == "Dion dit Dutily")
        #expect(therese.gender == .female)

        // None of the old broken splits.
        #expect(!result.people.contains { $0.firstName == "dit" })
        #expect(!result.people.contains { $0.lastName == "Livernoit" })
        #expect(!result.people.contains { $0.lastName == "Benoit" })
    }

    @Test("Legacy record with a non-d1p ID (FamilySearch ARK) parses, not dumped to Other")
    func nonD1pRecordID() throws {
        let result = try loadFolder(
            named: "0500-0501--langevin-michel__fontaine-victoire",
            files: ["1766-w-langevin-michel-fontaine-victoire-3QSQ-G993-F93K-J.jpg"]
        )

        #expect(result.otherFiles.files.isEmpty)   // recognized, not "Other"
        #expect(result.tabs.count == 1)
        let tab = try #require(result.tabs.first)
        #expect(tab.recordType == .wedding)
        #expect(tab.pages.first?.recordID == "3QSQ-G993-F93K-J")
        #expect(result.people.contains { $0.lastName == "Langevin" && $0.firstName == "Michel" })
        #expect(result.people.contains { $0.lastName == "Fontaine" && $0.firstName == "Victoire" })
    }

    @Test("Records that drop the 'Marie' prefix unify to the folder's canonical first name")
    func droppedMariePrefix() throws {
        let result = try loadFolder(
            named: "0456-0457--dupres-charles__menard-marie-amable",
            files: [
                "1735-b-dupres-charles-d1p_1.jpg",
                "1743-b-menard-amable-d1p_2.jpg",                       // wife, no "Marie"
                "1761-w-dupres-charles-menard-marie-amable-d1p_3.jpg",  // wife, with "Marie"
                "1826-s-menard-amable-d1p_4.jpg",                       // wife, no "Marie"
            ]
        )

        // Two people — the wife is not split into "Amable" and "Marie Amable".
        #expect(result.people.count == 2)
        let wife = try #require(result.people.first { $0.gender == .female })
        #expect(wife.lastName == "Menard")
        #expect(wife.firstName == "Marie Amable")
        #expect(!result.people.contains { $0.lastName == "Menard" && $0.firstName == "Amable" })
    }
}
