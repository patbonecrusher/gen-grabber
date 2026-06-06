import AppKit
import Foundation

struct RecordTab: Identifiable, Sendable {
    let id: UUID
    let recordType: RecordType
    /// For wedding: [groomID, brideID]. For birth/sepulture: [personID].
    let personIDs: [UUID]
    var year: String
    var lafranceImage: NSImage?
    var pages: [PageGroup]
    var customLabel: String
    var lafranceParsedText: String

    init(
        id: UUID = UUID(),
        recordType: RecordType,
        personIDs: [UUID],
        year: String = "",
        lafranceImage: NSImage? = nil,
        customLabel: String = ""
    ) {
        self.id = id
        self.recordType = recordType
        self.personIDs = personIDs
        self.year = year
        self.lafranceImage = lafranceImage
        self.pages = [PageGroup()]
        self.customLabel = customLabel
        self.lafranceParsedText = ""
    }
}
