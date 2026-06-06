import Foundation

enum RecordType: String, CaseIterable, Sendable {
    case birth = "b"
    case wedding = "w"
    case sepulture = "s"
    case obituary = "o"
    case thanks = "th"
    case misc = "m"

    var label: String {
        switch self {
        case .birth: "Birth"
        case .wedding: "Wedding"
        case .sepulture: "Sepulture"
        case .obituary: "Obituary"
        case .thanks: "Thanks"
        case .misc: "Misc"
        }
    }

    var shortLabel: String {
        switch self {
        case .birth: "B"
        case .wedding: "W"
        case .sepulture: "S"
        case .obituary: "O"
        case .thanks: "TH"
        case .misc: "M"
        }
    }
}
