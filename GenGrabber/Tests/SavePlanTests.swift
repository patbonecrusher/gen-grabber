import Foundation
import Testing
@testable import GenGrabber

@Suite("SavePlan")
struct SavePlanTests {
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gengrabber-save-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - changeKind

    @Test("changeKind: missing file is created")
    func created() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("new.txt")
        #expect(FileSaver.changeKind(of: Data("hello".utf8), comparedToFileAt: url) == .created)
    }

    @Test("changeKind: identical bytes are unchanged")
    func unchanged() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("same.txt")
        let data = Data("hello".utf8)
        try data.write(to: url)
        #expect(FileSaver.changeKind(of: data, comparedToFileAt: url) == .unchanged)
    }

    @Test("changeKind: different bytes are updated")
    func updated() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("diff.txt")
        try Data("hello".utf8).write(to: url)
        #expect(FileSaver.changeKind(of: Data("world".utf8), comparedToFileAt: url) == .updated)
    }

    // MARK: - apply

    @Test("apply writes created/updated and skips unchanged")
    func applySkipsUnchanged() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let createdURL = dir.appendingPathComponent("created.txt")
        let unchangedURL = dir.appendingPathComponent("unchanged.txt")
        let updatedURL = dir.appendingPathComponent("updated.txt")

        // Pre-existing files on disk.
        try Data("keep".utf8).write(to: unchangedURL)
        try Data("old".utf8).write(to: updatedURL)

        let plan = FileSaver.SavePlan(
            folder: dir,
            writes: [
                .init(url: createdURL, data: Data("new".utf8), kind: .created),
                .init(url: unchangedURL, data: Data("keep".utf8), kind: .unchanged),
                .init(url: updatedURL, data: Data("fresh".utf8), kind: .updated),
            ],
            removableOldFiles: []
        )

        let result = FileSaver.apply(plan, trashOldFiles: false)

        #expect(result.createdCount == 1)
        #expect(result.updatedCount == 1)
        #expect(try String(contentsOf: createdURL, encoding: .utf8) == "new")
        #expect(try String(contentsOf: updatedURL, encoding: .utf8) == "fresh")
        // The unchanged file is left exactly as it was (not rewritten by apply).
        #expect(try String(contentsOf: unchangedURL, encoding: .utf8) == "keep")
    }

    @Test("apply trashes old files only when requested")
    func applyTrashToggle() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let oldFile = dir.appendingPathComponent("old-name.png")
        try Data("img".utf8).write(to: oldFile)

        let plan = FileSaver.SavePlan(folder: dir, writes: [], removableOldFiles: [oldFile])

        // Toggle off: file stays.
        let kept = FileSaver.apply(plan, trashOldFiles: false)
        #expect(kept.removedCount == 0)
        #expect(FileManager.default.fileExists(atPath: oldFile.path))

        // Toggle on: file is trashed.
        let removed = FileSaver.apply(plan, trashOldFiles: true)
        #expect(removed.removedCount == 1)
        #expect(!FileManager.default.fileExists(atPath: oldFile.path))
    }
}
