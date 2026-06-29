import AppKit
import Foundation
import ImageIO

@Observable
final class SaveProgress {
    var total: Int = 0
    var completed: Int = 0
    var fraction: Double { total > 0 ? Double(completed) / Double(total) : 0 }
}

enum FileSaver {
    enum ChangeKind: Sendable { case created, updated, unchanged }

    struct PlannedWrite: Sendable {
        let url: URL
        let data: Data
        let kind: ChangeKind
    }

    /// The result of a dry-run: exactly what `apply` would write/remove, with nothing written yet.
    struct SavePlan: Sendable, Identifiable {
        let id = UUID()
        let folder: URL
        let writes: [PlannedWrite]          // every output, including unchanged
        let removableOldFiles: [URL]        // old, differently-named originals to trash

        var created: [URL] { writes.filter { $0.kind == .created }.map(\.url) }
        var updated: [URL] { writes.filter { $0.kind == .updated }.map(\.url) }
        var unchanged: [URL] { writes.filter { $0.kind == .unchanged }.map(\.url) }
        var hasChanges: Bool { !created.isEmpty || !updated.isEmpty || !removableOldFiles.isEmpty }
    }

    struct SaveResult: Sendable {
        let createdCount: Int
        let updatedCount: Int
        let removedCount: Int
        let folder: URL
    }

    // MARK: - Planning (dry run, no writes)

    /// Computes every file the current session would write into `folder`, classifies each as
    /// created/updated/unchanged by comparing the bytes against what is already on disk, and
    /// determines which old, differently-named originals would be superseded. Writes nothing.
    @MainActor
    static func makePlan(session: SessionModel, folder: URL) -> SavePlan {
        var writes: [PlannedWrite] = []
        let sources = session.sourceURLByImage
        var removable: Set<URL> = []

        func planImage(_ image: NSImage, named filename: String) {
            guard let data = pngData(for: image) else { return }
            let url = folder.appendingPathComponent(filename)
            writes.append(PlannedWrite(url: url, data: data, kind: changeKind(of: data, comparedToFileAt: url)))
            collectRemovable(image: image, newFilename: filename, newData: data,
                             folderURL: folder, sources: sources, into: &removable)
        }

        func planText(_ content: String, named filename: String) {
            let url = folder.appendingPathComponent(filename)
            let data = Data(content.utf8)
            writes.append(PlannedWrite(url: url, data: data, kind: changeKind(of: data, comparedToFileAt: url)))
        }

        for tab in session.tabs {
            let closeupCounts = tab.pages.map { $0.closeupImages.count }
            let filenames = FilenameBuilder.filenames(for: tab, people: session.people, closeupCounts: closeupCounts)

            if let lafranceFilename = filenames.lafrance, let image = tab.lafranceImage {
                planImage(image, named: lafranceFilename)
                if !tab.lafranceParsedText.isEmpty {
                    let parsedFilename = lafranceFilename.replacingOccurrences(of: ".png", with: "--parsed.txt")
                    planText(tab.lafranceParsedText, named: parsedFilename)
                }
            }

            for (pageIndex, page) in tab.pages.enumerated() {
                guard pageIndex < filenames.pages.count else { continue }
                let pageFilenames = filenames.pages[pageIndex]

                if let image = page.recordImage {
                    planImage(image, named: pageFilenames.record)
                }
                if !page.parsedText.isEmpty {
                    planText(page.parsedText, named: pageFilenames.parsed)
                }
                for (closeupIndex, closeupImage) in page.closeupImages.enumerated() {
                    if let image = closeupImage, closeupIndex < pageFilenames.closeups.count {
                        planImage(image, named: pageFilenames.closeups[closeupIndex])
                    }
                }
            }
        }

        // Other files (kept under their original names)
        for otherFile in session.otherFiles.files {
            if let image = otherFile.image {
                planImage(image, named: otherFile.filename)
            }
        }

        // Notes
        for note in session.notes {
            let content = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { continue }
            planText(note.content, named: note.filename)
        }

        // Summary JSON
        if !session.summary.records.isEmpty || !session.summary.markedPeople.isEmpty {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let jsonData = try? encoder.encode(session.summary) {
                let url = folder.appendingPathComponent("summary.json")
                writes.append(PlannedWrite(url: url, data: jsonData, kind: changeKind(of: jsonData, comparedToFileAt: url)))
            }
        }

        let removableSorted = removable.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        return SavePlan(folder: folder, writes: writes, removableOldFiles: removableSorted)
    }

    /// Classifies a planned write against the file currently on disk.
    static func changeKind(of data: Data, comparedToFileAt url: URL) -> ChangeKind {
        guard let existing = try? Data(contentsOf: url) else { return .created }
        return existing == data ? .unchanged : .updated
    }

    // MARK: - Apply

    /// Writes every created/updated file (skipping unchanged) and, if requested, trashes the
    /// superseded old originals. Returns counts for the confirmation.
    static func apply(_ plan: SavePlan, trashOldFiles: Bool, progress: SaveProgress? = nil) -> SaveResult {
        let toWrite = plan.writes.filter { $0.kind != .unchanged }
        progress?.total = toWrite.count
        progress?.completed = 0

        var created = 0, updated = 0
        for write in toWrite {
            do {
                try write.data.write(to: write.url)
                if write.kind == .created { created += 1 } else { updated += 1 }
            } catch {
                // Skip files that fail to write; counts reflect what succeeded.
            }
            progress?.completed += 1
        }

        var removed = 0
        if trashOldFiles {
            removed = trashFiles(plan.removableOldFiles)
        }

        return SaveResult(createdCount: created, updatedCount: updated, removedCount: removed, folder: plan.folder)
    }

    /// Moves the given files to the Trash (recoverable). Returns the number removed.
    static func trashFiles(_ urls: [URL]) -> Int {
        let fm = FileManager.default
        var count = 0
        for url in urls where (try? fm.trashItem(at: url, resultingItemURL: nil)) != nil {
            count += 1
        }
        return count
    }

    // MARK: - Old-file detection

    /// Records `source` for removal when an image came from an old, differently-named file in the
    /// same folder we are saving into, and the freshly-encoded bytes are the same image.
    private static func collectRemovable(
        image: NSImage, newFilename: String, newData: Data, folderURL: URL,
        sources: [ObjectIdentifier: URL], into removable: inout Set<URL>
    ) {
        guard let source = sources[ObjectIdentifier(image)] else { return }
        // Only when saving back into the folder the file came from.
        guard source.deletingLastPathComponent().standardizedFileURL == folderURL.standardizedFileURL else { return }
        // Never flag the file we are about to (over)write.
        guard source.lastPathComponent != newFilename else { return }
        guard isSameImage(old: source, newData: newData) else { return }
        removable.insert(source)
    }

    /// True when the old file on disk matches the new bytes by exact byte size OR by pixel dimensions.
    private static func isSameImage(old: URL, newData: Data) -> Bool {
        if let a = byteSize(of: old), a == newData.count { return true }
        if let a = pixelSize(of: old), let b = pixelSize(ofData: newData), a == b { return true }
        return false
    }

    private static func byteSize(of url: URL) -> Int? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int
    }

    private static func pixelSize(of url: URL) -> [Int]? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return pixelSize(from: src)
    }

    private static func pixelSize(ofData data: Data) -> [Int]? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return pixelSize(from: src)
    }

    private static func pixelSize(from src: CGImageSource) -> [Int]? {
        guard let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return [w, h]
    }

    // MARK: - Encoding

    private static func pngData(for image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else { return nil }
        return pngData
    }

    // MARK: - Folder picker

    @MainActor
    static func pickSaveFolder(session: SessionModel) -> URL? {
        pickFolder(defaultDirectory: session.currentFolderURL)
    }

    @MainActor
    private static func pickFolder(defaultDirectory: URL? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        panel.message = "Choose a folder to save all record images"

        // Default to the currently-open folder so it targets it (e.g. after stepping through
        // folders with the next/previous arrows).
        if let defaultDirectory {
            panel.directoryURL = defaultDirectory
        }

        return panel.runModal() == .OK ? panel.url : nil
    }
}
