import Foundation

enum RecordType: String, CaseIterable, Sendable {
    case birth = "b"
    case wedding = "w"
    case legal = "l"
    case sepulture = "s"
    case census = "c"
    case obituary = "o"
    case thanks = "th"
    case misc = "m"

    /// True for record types whose filenames join several people with `__`
    /// (a wedding's groom/bride, a legal record's one-or-more parties).
    var usesPersonSeparator: Bool { self == .wedding || self == .legal }

    /// True when the record can name more than two people (a legal act may tie together
    /// any number of parties). Weddings and single-person records do not.
    var allowsMultiplePeople: Bool { self == .legal }

    var label: String {
        switch self {
        case .birth: "Birth"
        case .wedding: "Wedding"
        case .legal: "Legal"
        case .sepulture: "Sepulture"
        case .census: "Census"
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
        case .census: "C"
        case .obituary: "O"
        case .thanks: "TH"
        case .misc: "M"
        }
    }
}
