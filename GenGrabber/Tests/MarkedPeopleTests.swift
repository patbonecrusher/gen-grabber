import Foundation
import Testing
@testable import GenGrabber

@Suite("MarkedPeople")
struct MarkedPeopleTests {
    // MARK: - Query contract

    @Test("GenealogicalStatus raw values are the stable queryable contract")
    func rawValuesLocked() {
        #expect(GenealogicalStatus.immigrant.rawValue == "immigrant")
        #expect(GenealogicalStatus.filleDuRoy.rawValue == "fille_du_roy")
        #expect(GenealogicalStatus.filleAMarier.rawValue == "fille_a_marier")
        #expect(GenealogicalStatus.soldat.rawValue == "soldat")
        #expect(GenealogicalStatus.engage.rawValue == "engage")
    }

    // MARK: - Backward / forward compatibility

    @Test("Old summary.json without markedPeople decodes to an empty array")
    func decodesLegacySummary() throws {
        let json = """
        { "records": [] }
        """
        let summary = try JSONDecoder().decode(SessionSummary.self, from: Data(json.utf8))
        #expect(summary.markedPeople.isEmpty)
        #expect(summary.records.isEmpty)
    }

    @Test("Summary with marks survives an encode/decode round-trip")
    func roundTrip() throws {
        let mark = PersonMark(
            lastName: "Roy", firstName: "Joseph",
            statuses: [.immigrant, .soldat], origin: "France"
        )
        let original = SessionSummary(records: [], markedPeople: [mark])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SessionSummary.self, from: data)

        #expect(decoded.markedPeople.count == 1)
        let m = try #require(decoded.markedPeople.first)
        #expect(m.lastName == "Roy")
        #expect(m.firstName == "Joseph")
        #expect(m.statuses == [.immigrant, .soldat])
        #expect(m.origin == "France")
    }

    @Test("Statuses are encoded as their raw-value strings")
    func encodesRawValues() throws {
        let summary = SessionSummary(
            markedPeople: [PersonMark(lastName: "X", firstName: "Y", statuses: [.filleDuRoy])]
        )
        let data = try JSONEncoder().encode(summary)
        let string = String(decoding: data, as: UTF8.self)
        #expect(string.contains("fille_du_roy"))
    }

    // MARK: - SessionModel helpers

    @Test("setStatus upserts a mark and isMarked reflects it")
    @MainActor
    func setStatusUpserts() {
        let session = SessionModel()
        #expect(session.statuses(last: "Roy", first: "Joseph").isEmpty)

        session.setStatus(.immigrant, true, last: "Roy", first: "Joseph")
        #expect(session.isMarked(.immigrant, last: "Roy", first: "Joseph"))
        #expect(session.summary.markedPeople.count == 1)
    }

    @Test("Clearing the last status and origin prunes the mark")
    @MainActor
    func prunesEmptyMark() {
        let session = SessionModel()
        session.setStatus(.soldat, true, last: "Roy", first: "Joseph")
        #expect(session.summary.markedPeople.count == 1)

        session.setStatus(.soldat, false, last: "Roy", first: "Joseph")
        #expect(session.summary.markedPeople.isEmpty)
    }

    @Test("Origin survives even with no status, and clearing both prunes")
    @MainActor
    func originLifecycle() {
        let session = SessionModel()
        session.setOrigin("England", last: "Smith", first: "John")
        #expect(session.origin(last: "Smith", first: "John") == "England")
        #expect(session.summary.markedPeople.count == 1)

        session.setOrigin("", last: "Smith", first: "John")
        #expect(session.summary.markedPeople.isEmpty)
    }

    @Test("Name matching is case-insensitive")
    @MainActor
    func caseInsensitiveMatch() {
        let session = SessionModel()
        session.setStatus(.filleDuRoy, true, last: "Roy", first: "Marie")
        // A record name like "ROY, Marie" must match the People-row entry.
        #expect(session.isMarked(.filleDuRoy, last: "ROY", first: "marie"))
    }

    @Test("setStatus is dirty-tracked for saving")
    @MainActor
    func marksDirty() {
        let session = SessionModel()
        #expect(session.hasUnsavedChanges == false)
        session.setStatus(.immigrant, true, last: "Roy", first: "Joseph")
        #expect(session.hasUnsavedChanges == true)
    }
}
