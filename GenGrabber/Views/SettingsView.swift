import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AISettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Base URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("http://localhost:11434/v1", text: $settings.baseURL)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("API Token")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("Optional for local models", text: $settings.token)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. gpt-4o, llava", text: $settings.model)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(20)
        .frame(width: 350)
    }
}
