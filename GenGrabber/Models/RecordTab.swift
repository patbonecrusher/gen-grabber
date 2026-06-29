import AppKit
import Foundation

struct RecordTab: Identifiable, Sendable {
    let id: UUID
    let recordType: RecordType
    /// For wedding: [groomID, brideID]. For birth/sepulture: [personID].
    let personIDs: [UUID]
    var year: String
    var lafranceImage: NSImage?
    /// The recordID the LaFrance image belongs to, so it keeps its own id in the filename even
    /// when the tab spans several records (e.g. a d1p record plus a FamilySearch ARK one).
    var lafranceRecordID: String?
    var pages: [PageGroup]
    var customLabel: String
    var lafranceParsedText: String
    var isUnsure: Bool

    init(
        id: UUID = UUID(),
        recordType: RecordType,
        personIDs: [UUID],
        year: String = "",
        lafranceImage: NSImage? = nil,
        customLabel: String = "",
        isUnsure: Bool = false
    ) {
        self.id = id
        self.recordType = recordType
        self.personIDs = personIDs
        self.year = year
        self.lafranceImage = lafranceImage
        self.pages = [PageGroup()]
        self.customLabel = customLabel
        self.lafranceParsedText = ""
        self.isUnsure = isUnsure
    }
}
