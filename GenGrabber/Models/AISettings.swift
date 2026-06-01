import Foundation

@Observable
final class AISettings {
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
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty &&
        !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init() {
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
