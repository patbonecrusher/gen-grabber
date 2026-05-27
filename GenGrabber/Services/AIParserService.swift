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
    static func parse(image: NSImage, baseURL: String, token: String, model: String) async throws -> ParsedRecord {
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

        var request = URLRequest(url: url)
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
