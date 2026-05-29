import AppKit
import Foundation

struct ParsedRecord: Sendable {
    let year: String
    let recordID: String
}

enum AIParserError: LocalizedError {
    case notConfigured
    case imageConversionFailed
    case invalidURL
    case requestFailed(String)
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "AI settings not configured. Open Settings to set Base URL and Model."
        case .imageConversionFailed: "Failed to convert image to PNG data."
        case .invalidURL: "Invalid AI Base URL."
        case .requestFailed(let msg): "AI request failed: \(msg)"
        case .parseFailed(let msg): "Failed to parse AI response: \(msg)"
        }
    }
}

enum AIParserService {
    static func parse(image: NSImage, baseURL: String, token: String, model: String, timeout: Double = 180) async throws -> ParsedRecord {
        guard !baseURL.trimmingCharacters(in: .whitespaces).isEmpty,
              !model.trimmingCharacters(in: .whitespaces).isEmpty
        else { throw AIParserError.notConfigured }

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else { throw AIParserError.imageConversionFailed }

        let base64 = pngData.base64EncodedString()

        let baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIParserError.invalidURL
        }

        let prompt = """
            Look at this genealogy record screenshot carefully. \
            Find the date in the top-right area and extract ONLY the 4-digit year. \
            Find the original document filename link (looks like d1p_NNNNNNN.jpg) and extract the ID without .jpg. \
            Return ONLY a JSON object with the actual values you see: {"year": "YYYY", "recordID": "d1p_NNNNNNN"}
            """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64)"]],
                    ],
                ] as [String: Any],
            ],
            "max_tokens": 100,
        ]

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIParserError.requestFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        return try parseResponse(data)
    }

    static func extractFullRecord(image: NSImage, baseURL: String, token: String, model: String, timeout: Double = 180) async throws -> RecordSummary {
        guard !baseURL.trimmingCharacters(in: .whitespaces).isEmpty,
              !model.trimmingCharacters(in: .whitespaces).isEmpty
        else { throw AIParserError.notConfigured }

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else { throw AIParserError.imageConversionFailed }

        let base64 = pngData.base64EncodedString()

        let baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIParserError.invalidURL
        }

        let prompt = """
            Look at this genealogy record screenshot carefully. Extract ALL visible information into structured JSON. \
            Return a JSON object with these fields: \
            "recordType" (one of "Marriage", "Baptism", "Burial"), \
            "date" (the date of the event, e.g. "21-Jan-1808"), \
            "parish" (the parish name), \
            "region" (the region/location), \
            "documentFilename" (the original document filename if visible, e.g. "d1p_1234567"), \
            "persons" (an array of person objects). \
            Each person object should have: \
            "name" (format "LASTNAME, Firstname"), \
            "role" (e.g. "Subject", "Father of groom", "Mother of groom", "Father of bride", "Mother of bride", "Groom", "Bride", "Witness"), \
            "maritalStatus" (e.g. "Single", "Married", "Widowed", or empty), \
            "sex" (e.g. "M", "F", or empty), \
            "age" (e.g. "25" or empty), \
            "occupation" (or empty). \
            Extract every person mentioned in the record. Return ONLY the JSON object, no other text.
            """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64)"]],
                    ],
                ] as [String: Any],
            ],
            "max_tokens": 2000,
        ]

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIParserError.requestFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        return try parseFullRecordResponse(data)
    }

    private static func parseFullRecordResponse(_ data: Data) throws -> RecordSummary {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw AIParserError.parseFailed("Unexpected response format")
        }

        let jsonString = extractJSON(from: content)

        guard let jsonData = jsonString.data(using: .utf8),
              let record = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else {
            throw AIParserError.parseFailed("Could not parse JSON: \(content)")
        }

        let persons: [RecordPersonEntry]
        if let personsArray = record["persons"] as? [[String: Any]] {
            persons = personsArray.map { p in
                RecordPersonEntry(
                    name: flexString(p["name"]),
                    role: flexString(p["role"]),
                    maritalStatus: flexString(p["maritalStatus"] ?? p["marital_status"] ?? p["mar_st"]),
                    sex: flexString(p["sex"]),
                    age: flexString(p["age"]),
                    occupation: flexString(p["occupation"])
                )
            }
        } else {
            persons = []
        }

        return RecordSummary(
            recordType: flexString(record["recordType"] ?? record["record_type"]),
            date: flexString(record["date"]),
            parish: flexString(record["parish"]),
            region: flexString(record["region"]),
            documentFilename: flexString(record["documentFilename"] ?? record["document_filename"] ?? record["filename"]),
            persons: persons
        )
    }

    private static func flexString(_ value: Any?) -> String {
        switch value {
        case let s as String: return s
        case let n as Int: return String(n)
        case let n as Double:
            if n == n.rounded() && !n.isNaN && !n.isInfinite {
                return String(Int(n))
            }
            return String(n)
        case let b as Bool: return String(b)
        default: return ""
        }
    }

    private static func parseResponse(_ data: Data) throws -> ParsedRecord {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw AIParserError.parseFailed("Unexpected response format")
        }

        // Extract JSON from the content (may be wrapped in markdown code blocks)
        let jsonString = extractJSON(from: content)

        guard let jsonData = jsonString.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: String],
              let year = parsed["year"],
              let recordID = parsed["recordID"]
        else {
            throw AIParserError.parseFailed("Could not parse: \(content)")
        }

        return ParsedRecord(year: year, recordID: recordID)
    }

    private static func extractJSON(from text: String) -> String {
        // Strip markdown code blocks if present
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find JSON object boundaries
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            return String(cleaned[start...end])
        }
        return cleaned
    }
}

