import Foundation

struct RecordPersonEntry: Codable, Identifiable, Sendable, Equatable {
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

struct RecordSummary: Codable, Identifiable, Sendable, Equatable {
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

struct SessionSummary: Codable, Sendable, Equatable {
    var records: [RecordSummary]
    /// Manually-applied genealogical statuses, keyed by person name. Optional in the JSON so
    /// older summary.json files (which lack this key) still decode.
    var markedPeople: [PersonMark]

    init(records: [RecordSummary] = [], markedPeople: [PersonMark] = []) {
        self.records = records
        self.markedPeople = markedPeople
    }

    private enum CodingKeys: String, CodingKey {
        case records
        case markedPeople
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.records = try container.decodeIfPresent([RecordSummary].self, forKey: .records) ?? []
        self.markedPeople = try container.decodeIfPresent([PersonMark].self, forKey: .markedPeople) ?? []
    }
}
