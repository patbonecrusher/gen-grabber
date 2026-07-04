import Foundation

/// A manually-applied genealogical status. Raw values are the stable, machine-queryable
/// contract written to summary.json — do not change them (locked by tests).
enum GenealogicalStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case immigrant = "immigrant"          // Immigrant / Pionnier
    case filleDuRoy = "fille_du_roy"
    case filleAMarier = "fille_a_marier"
    case soldat = "soldat"
    case engage = "engage"
    case acadian = "acadian"

    var id: String { rawValue }

    /// Full name shown in the status editor.
    var label: String {
        switch self {
        case .immigrant: "Immigrant / Pionnier"
        case .filleDuRoy: "Fille du Roy"
        case .filleAMarier: "Fille à marier"
        case .soldat: "Soldat"
        case .engage: "Engagé"
        case .acadian: "Acadien"
        }
    }

    /// Short text used for inline badge pills.
    var badge: String {
        switch self {
        case .immigrant: "Immigrant"
        case .filleDuRoy: "Fille du Roy"
        case .filleAMarier: "Fille à marier"
        case .soldat: "Soldat"
        case .engage: "Engagé"
        case .acadian: "Acadien"
        }
    }
}

/// A name-keyed set of statuses + origin for one person, persisted in summary.json.
struct PersonMark: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    var lastName: String
    var firstName: String
    var statuses: [GenealogicalStatus]
    var origin: String

    init(
        id: UUID = UUID(),
        lastName: String = "",
        firstName: String = "",
        statuses: [GenealogicalStatus] = [],
        origin: String = ""
    ) {
        self.id = id
        self.lastName = lastName
        self.firstName = firstName
        self.statuses = statuses
        self.origin = origin
    }

    /// Common origin countries offered as suggestions in the editor (field stays free-text).
    static let originSuggestions = ["France", "England", "Ireland", "Scotland", "New England", "Acadia"]
}
