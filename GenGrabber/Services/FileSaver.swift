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
            let closeupCounts = tab.pages.map { $0.closeupImages.count }
            let filenames = FilenameBuilder.filenames(for: tab, people: people, closeupCounts: closeupCounts)

            // Save LaFrance
            if let lafranceFilename = filenames.lafrance, let image = tab.lafranceImage {
                if saveImage(image, named: lafranceFilename, to: folderURL) {
                    fileCount += 1
                }
            }

            // Save page images and parsed text
            for (pageIndex, page) in tab.pages.enumerated() {
                guard pageIndex < filenames.pages.count else { continue }
                let pageFilenames = filenames.pages[pageIndex]

                if let image = page.recordImage {
                    if saveImage(image, named: pageFilenames.record, to: folderURL) {
                        fileCount += 1
                    }
                }

                if !page.parsedText.isEmpty {
                    let parsedURL = folderURL.appendingPathComponent(pageFilenames.parsed)
                    try? page.parsedText.write(to: parsedURL, atomically: true, encoding: .utf8)
                    fileCount += 1
                }

                for (closeupIndex, closeupImage) in page.closeupImages.enumerated() {
                    if let image = closeupImage, closeupIndex < pageFilenames.closeups.count {
                        if saveImage(image, named: pageFilenames.closeups[closeupIndex], to: folderURL) {
                            fileCount += 1
                        }
                    }
                }
            }
        }

        // Save other files (copy with original filenames)
        for otherFile in session.otherFiles.files {
            if let image = otherFile.image {
                if saveImage(image, named: otherFile.filename, to: folderURL) {
                    fileCount += 1
                }
            }
        }

        // Save notes
        for note in session.notes {
            let content = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { continue }
            let noteURL = folderURL.appendingPathComponent(note.filename)
            try? note.content.write(to: noteURL, atomically: true, encoding: .utf8)
            fileCount += 1
        }

        // Save summary JSON
        if !session.summary.records.isEmpty {
            let jsonURL = folderURL.appendingPathComponent("summary.json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let jsonData = try? encoder.encode(session.summary) {
                try? jsonData.write(to: jsonURL)
                fileCount += 1
            }
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
