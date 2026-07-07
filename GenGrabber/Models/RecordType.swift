import Foundation

enum RecordType: String, CaseIterable, Sendable {
    case birth = "b"
    case wedding = "w"
    case legal = "l"
    case sepulture = "s"
    case obituary = "o"
    case thanks = "th"
    case misc = "m"

    /// True for record types that concern two people joined by `__` in filenames
    /// (a wedding's groom/bride, a legal record's two parties).
    var isCouple: Bool { self == .wedding || self == .legal }

    var label: String {
        switch self {
        case .birth: "Birth"
        case .wedding: "Wedding"
        case .legal: "Legal"
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
        case .legal: "L"
        case .sepulture: "S"
        case .obituary: "O"
        case .thanks: "TH"
        case .misc: "M"
        }
    }
}
