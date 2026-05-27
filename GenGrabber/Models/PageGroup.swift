import AppKit
import Foundation

struct PageGroup: Identifiable, Sendable {
    let id: UUID
    var recordID: String
    var recordImage: NSImage?
    var closeupImage: NSImage?

    init(id: UUID = UUID(), recordID: String = "", recordImage: NSImage? = nil, closeupImage: NSImage? = nil) {
        self.id = id
        self.recordID = recordID
        self.recordImage = recordImage
        self.closeupImage = closeupImage
    }
}
