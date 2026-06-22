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
        case .notConfigured: "AI settings not configured. Open Settings to choose a provider and set the required fields."
        case .imageConversionFailed: "Failed to convert image to PNG data."
        case .invalidURL: "Invalid AI Base URL."
        case .requestFailed(let msg): "AI request failed: \(msg)"
        case .parseFailed(let msg): "Failed to parse AI response: \(msg)"
        }
    }
}

enum AIParserService {
    /// Fixed endpoint for the Anthropic provider; the Base URL field is OpenAI-only.
    private static let anthropicBaseURL = "https://api.anthropic.com"

    static func parse(image: NSImage, provider: AIProvider, baseURL: String, token: String, model: String, timeout: Double = 180) async throws -> ParsedRecord {
        let prompt = """
            Look at this genealogy record screenshot carefully. \
            Find the date in the top-right area and extract ONLY the 4-digit year. \
            Find the original document filename link (looks like d1p_NNNNNNN.jpg) and extract the ID without .jpg. \
            Return ONLY a JSON object with the actual values you see: {"year": "YYYY", "recordID": "d1p_NNNNNNN"}
            """

        let content = try await messageText(
            provider: provider, baseURL: baseURL, token: token, model: model,
            prompt: prompt, images: [image], maxTokens: 100, timeout: timeout
        )

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

    static func extractFullRecord(image: NSImage, provider: AIProvider, baseURL: String, token: String, model: String, timeout: Double = 180) async throws -> RecordSummary {
        let prompt = """
            Look at this genealogy record screenshot carefully. Extract ALL visible information into structured JSON. \
            Return a JSON object with these fields: \
            "recordType" (one of "Marriage", "Baptism", "Burial"), \
            "date" (the date of the event, normalized to MM/DD/YYYY format, e.g. "01/21/1808"), \
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

        let content = try await messageText(
            provider: provider, baseURL: baseURL, token: token, model: model,
            prompt: prompt, images: [image], maxTokens: 2000, timeout: timeout
        )

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

    static func extractText(images: [NSImage], provider: AIProvider, baseURL: String, token: String, model: String, timeout: Double = 180) async throws -> String {
        let prompt = """
            Look at this genealogy record image(s) carefully. \
            Transcribe ALL the text you can see in the image(s) as faithfully as possible. \
            Include names, dates, places, roles, and any other details. \
            If the text is in French, keep it in French. \
            Format the output as clean readable text, preserving the logical structure of the record. \
            Do not add any commentary or interpretation — just the transcribed text.
            """

        let content = try await messageText(
            provider: provider, baseURL: baseURL, token: token, model: model,
            prompt: prompt, images: images, maxTokens: 4000, timeout: timeout
        )
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Networking

    /// Builds and sends the request for the given provider, returning the assistant's text content.
    private static func messageText(
        provider: AIProvider, baseURL: String, token: String, model: String,
        prompt: String, images: [NSImage], maxTokens: Int, timeout: Double
    ) async throws -> String {
        guard !model.trimmingCharacters(in: .whitespaces).isEmpty else { throw AIParserError.notConfigured }
        switch provider {
        case .openAICompatible:
            guard !baseURL.trimmingCharacters(in: .whitespaces).isEmpty else { throw AIParserError.notConfigured }
        case .anthropic:
            guard !token.trimmingCharacters(in: .whitespaces).isEmpty else { throw AIParserError.notConfigured }
        }

        let base64Images = try images.map { try pngBase64($0) }
        guard !base64Images.isEmpty else { throw AIParserError.imageConversionFailed }

        let request = try makeRequest(
            provider: provider, baseURL: baseURL, token: token, model: model,
            prompt: prompt, base64Images: base64Images, maxTokens: maxTokens, timeout: timeout
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIParserError.requestFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        return try assistantText(from: data, provider: provider)
    }

    private static func makeRequest(
        provider: AIProvider, baseURL: String, token: String, model: String,
        prompt: String, base64Images: [String], maxTokens: Int, timeout: Double
    ) throws -> URLRequest {
        var content: [[String: Any]] = [["type": "text", "text": prompt]]
        let url: URL
        let body: [String: Any]
        var request: URLRequest

        switch provider {
        case .openAICompatible:
            let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let u = URL(string: "\(trimmed)/chat/completions") else { throw AIParserError.invalidURL }
            url = u
            for b64 in base64Images {
                content.append(["type": "image_url", "image_url": ["url": "data:image/png;base64,\(b64)"]])
            }
            body = [
                "model": model,
                "messages": [["role": "user", "content": content] as [String: Any]],
                "max_tokens": maxTokens,
            ]
            request = URLRequest(url: url, timeoutInterval: timeout)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

        case .anthropic:
            guard let u = URL(string: "\(anthropicBaseURL)/v1/messages") else { throw AIParserError.invalidURL }
            url = u
            for b64 in base64Images {
                content.append([
                    "type": "image",
                    "source": ["type": "base64", "media_type": "image/png", "data": b64],
                ])
            }
            body = [
                "model": model,
                "max_tokens": maxTokens,
                "messages": [["role": "user", "content": content] as [String: Any]],
            ]
            request = URLRequest(url: url, timeoutInterval: timeout)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(token, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }

        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Extracts the assistant's text from a provider-specific response payload.
    private static func assistantText(from data: Data, provider: AIProvider) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIParserError.parseFailed("Unexpected response format")
        }

        switch provider {
        case .openAICompatible:
            guard let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String
            else {
                throw AIParserError.parseFailed("Unexpected response format")
            }
            return content

        case .anthropic:
            guard let blocks = json["content"] as? [[String: Any]] else {
                throw AIParserError.parseFailed("Unexpected response format")
            }
            let text = blocks.compactMap { block -> String? in
                guard (block["type"] as? String) == "text" else { return nil }
                return block["text"] as? String
            }.joined()
            guard !text.isEmpty else {
                throw AIParserError.parseFailed("Unexpected response format")
            }
            return text
        }
    }

    private static func pngBase64(_ image: NSImage) throws -> String {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else { throw AIParserError.imageConversionFailed }
        return pngData.base64EncodedString()
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
