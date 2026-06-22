import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case openAICompatible
    case anthropic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAICompatible: "OpenAI-compatible"
        case .anthropic: "Claude (Anthropic)"
        }
    }
}

/// A selectable Claude model: the API model ID plus a friendly display name.
struct ClaudeModel: Identifiable, Hashable {
    let id: String
    let name: String
}

extension AISettings {
    /// Vision-capable Claude models offered in the Settings dropdown.
    static let claudeModels: [ClaudeModel] = [
        ClaudeModel(id: "claude-opus-4-8", name: "Claude Opus 4.8 (most capable)"),
        ClaudeModel(id: "claude-opus-4-7", name: "Claude Opus 4.7"),
        ClaudeModel(id: "claude-sonnet-4-6", name: "Claude Sonnet 4.6 (balanced)"),
        ClaudeModel(id: "claude-haiku-4-5", name: "Claude Haiku 4.5 (fastest)"),
    ]

    static let defaultClaudeModel = "claude-opus-4-8"

    /// Ensures `model` holds a valid Claude model ID when the Anthropic provider is active,
    /// defaulting any empty or non-Claude value (e.g. a leftover OpenAI model name).
    func normalizeClaudeModel() {
        guard provider == .anthropic else { return }
        if !Self.claudeModels.contains(where: { $0.id == model }) {
            model = Self.defaultClaudeModel
        }
    }
}

@Observable
final class AISettings {
    var provider: AIProvider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: "ai_provider") }
    }
    var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "ai_baseURL") }
    }
    var token: String {
        didSet { KeychainHelper.set(token, account: "ai_token") }
    }
    var model: String {
        didSet { UserDefaults.standard.set(model, forKey: "ai_model") }
    }
    var requestTimeout: Double {
        didSet { UserDefaults.standard.set(requestTimeout, forKey: "ai_requestTimeout") }
    }

    var isConfigured: Bool {
        guard !model.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch provider {
        case .openAICompatible:
            return !baseURL.trimmingCharacters(in: .whitespaces).isEmpty
        case .anthropic:
            return !token.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    init() {
        self.provider = UserDefaults.standard.string(forKey: "ai_provider")
            .flatMap(AIProvider.init(rawValue:)) ?? .openAICompatible
        self.baseURL = UserDefaults.standard.string(forKey: "ai_baseURL") ?? ""
        // Migrate any token previously stored in UserDefaults into the Keychain.
        if let legacy = UserDefaults.standard.string(forKey: "ai_token"), !legacy.isEmpty {
            KeychainHelper.set(legacy, account: "ai_token")
            UserDefaults.standard.removeObject(forKey: "ai_token")
        }
        self.token = KeychainHelper.get("ai_token") ?? ""
        self.model = UserDefaults.standard.string(forKey: "ai_model") ?? ""
        let saved = UserDefaults.standard.double(forKey: "ai_requestTimeout")
        self.requestTimeout = saved > 0 ? saved : 180
    }
}
