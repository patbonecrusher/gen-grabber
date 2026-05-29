import Foundation

struct RecordPersonEntry: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var role: String
    var maritalStatus: String
    var sex: String
    var age: String
    var occupation: String

    init(
        id: UUID = UUID(),
        name: String = "",
        role: String = "",
        maritalStatus: String = "",
        sex: String = "",
        age: String = "",
        occupation: String = ""
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.maritalStatus = maritalStatus
        self.sex = sex
        self.age = age
        self.occupation = occupation
    }
}

struct RecordSummary: Codable, Identifiable, Sendable {
    let id: UUID
    var recordType: String
    var date: String
    var parish: String
    var region: String
    var documentFilename: String
    var persons: [RecordPersonEntry]

    init(
        id: UUID = UUID(),
        recordType: String = "",
        date: String = "",
        parish: String = "",
        region: String = "",
        documentFilename: String = "",
        persons: [RecordPersonEntry] = []
    ) {
        self.id = id
        self.recordType = recordType
        self.date = date
        self.parish = parish
        self.region = region
        self.documentFilename = documentFilename
        self.persons = persons
    }
}

struct SessionSummary: Codable, Sendable {
    var records: [RecordSummary]

    init(records: [RecordSummary] = []) {
        self.records = records
    }
}
