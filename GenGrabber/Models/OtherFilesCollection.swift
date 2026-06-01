import AppKit
import Foundation

struct OtherFile: Identifiable, Sendable {
    let id: UUID
    let url: URL
    let filename: String
    var image: NSImage?

    init(id: UUID = UUID(), url: URL, filename: String, image: NSImage? = nil) {
        self.id = id
        self.url = url
        self.filename = filename
        self.image = image
    }
}

struct OtherFilesCollection: Sendable {
    var files: [OtherFile] = []
    var isEmpty: Bool { files.isEmpty }
}
