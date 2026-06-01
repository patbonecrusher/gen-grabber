import AppKit
import Foundation

struct PageGroup: Identifiable, Sendable {
    let id: UUID
    var recordID: String
    var recordImage: NSImage?
    var closeupImages: [NSImage?]
    var parsedText: String = ""

    init(id: UUID = UUID(), recordID: String = "", recordImage: NSImage? = nil) {
        self.id = id
        self.recordID = recordID
        self.recordImage = recordImage
        self.closeupImages = [nil] // Start with one empty closeup slot
    }
}
