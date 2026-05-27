import Foundation

@Observable
final class AISettings {
    var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "ai_baseURL") }
    }
    var token: String {
        didSet { UserDefaults.standard.set(token, forKey: "ai_token") }
    }
    var model: String {
        didSet { UserDefaults.standard.set(model, forKey: "ai_model") }
    }

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty &&
        !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init() {
        self.baseURL = UserDefaults.standard.string(forKey: "ai_baseURL") ?? ""
        self.token = UserDefaults.standard.string(forKey: "ai_token") ?? ""
        self.model = UserDefaults.standard.string(forKey: "ai_model") ?? ""
    }
}
