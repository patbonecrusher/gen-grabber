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

                for (closeupIndex, closeupImage) in page.closeupImages.enumerated() {
                    if let image = closeupImage, closeupIndex < pageFilenames.closeups.count {
                        if saveImage(image, named: pageFilenames.closeups[closeupIndex], to: folderURL) {
                            fileCount += 1
                        }
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
