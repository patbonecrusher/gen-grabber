import Foundation
import Testing
@testable import GenGrabber

@Suite("Lineage")
struct LineageTests {
    private let sample = """
    Lineage to Patrick Laplante (Sosa 1):

    Patrick Laplante (Sosa 1, gen 01, you)
      Jean-Claude Joseph Fernand Laplante (Sosa 2, gen 02, father)  [spouse: Marie-Claire Phaneuf]
        Laurette Seyer (Sosa 5, gen 03, mother)
          Gabriel-Antoine IMMIGRANT Martin dit Versailles (Sosa 346, gen 09, father)
    """

    @Test("Parses the header, depth, sosa, generation, and relation")
    func parsesChain() {
        let chain = LineageParser.parse(sample)

        #expect(chain.rootName == "Patrick Laplante")
        #expect(chain.entries.count == 4)

        let you = chain.entries[0]
        #expect(you.name == "Patrick Laplante")
        #expect(you.sosa == 1)
        #expect(you.generation == 1)
        #expect(you.depth == 0)
        #expect(you.relation == .you)

        let father = chain.entries[1]
        #expect(father.depth == 1)
        #expect(father.relation == .father)
        #expect(father.spouse == "Marie-Claire Phaneuf")

        // A line without [spouse: …] leaves it nil.
        #expect(chain.entries[2].spouse == nil)
    }

    @Test("IMMIGRANT and END markers become flags, not part of the name")
    func extractsMarkers() {
        let chain = LineageParser.parse(sample)
        let immigrant = try! #require(chain.entries.first { $0.sosa == 346 })
        #expect(immigrant.name == "Gabriel-Antoine Martin dit Versailles")
        #expect(immigrant.isImmigrant)
        #expect(!immigrant.isEndOfLine)

        let end = LineageParser.parse("Antoine IMMIGRANT END Joyal (Sosa 322, gen 09, father)")
        #expect(end.entries.first?.name == "Antoine Joyal")
        #expect(end.entries.first?.isImmigrant == true)
        #expect(end.entries.first?.isEndOfLine == true)
    }

    @Test("The subject is the deepest entry in the chain")
    func subjectIsDeepest() {
        let chain = LineageParser.parse(sample)
        #expect(chain.subject?.sosa == 346)
        #expect(chain.subject?.generation == 9)
    }

    @Test("Non-lineage text parses to an empty chain")
    func ignoresJunk() {
        let chain = LineageParser.parse("just some notes\nwith no lineage")
        #expect(chain.isEmpty)
    }

    @Test("lineage.txt loads from a folder and is not left as a note")
    func loadsFromFolderAndLeavesNotes() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gengrabber-lin-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try sample.write(to: dir.appendingPathComponent("lineage.txt"), atomically: true, encoding: .utf8)
        try "some research".write(to: dir.appendingPathComponent("research.txt"), atomically: true, encoding: .utf8)

        let result = FolderLoader.load(from: dir)
        #expect(result.lineage.entries.count == 4)
        // lineage.txt must not double as a note; other .txt notes are unaffected.
        #expect(result.notes.allSatisfy { $0.title.lowercased() != "lineage" })
        #expect(result.notes.contains { $0.title == "research" })
    }
}
