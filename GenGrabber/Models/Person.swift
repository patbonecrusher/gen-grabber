import Foundation

enum Gender: String, CaseIterable, Sendable {
    case male = "M"
    case female = "F"
}

struct Person: Identifiable, Sendable, Equatable {
    let id: UUID
    var gender: Gender
    var lastName: String
    var firstName: String

    init(id: UUID = UUID(), gender: Gender = .male, lastName: String = "", firstName: String = "") {
        self.id = id
        self.gender = gender
        self.lastName = lastName
        self.firstName = firstName
    }
}
