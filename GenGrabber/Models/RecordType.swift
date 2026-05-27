import Foundation

enum RecordType: String, CaseIterable, Sendable {
    case birth = "b"
    case wedding = "w"
    case sepulture = "s"

    var label: String {
        switch self {
        case .birth: "Birth"
        case .wedding: "Wedding"
        case .sepulture: "Sepulture"
        }
    }

    var shortLabel: String {
        switch self {
        case .birth: "B"
        case .wedding: "W"
        case .sepulture: "S"
        }
    }
}
