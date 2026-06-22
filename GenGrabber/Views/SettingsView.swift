import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AISettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Provider")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Provider", selection: $settings.provider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            if settings.provider == .openAICompatible {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Base URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("http://localhost:11434/v1", text: $settings.baseURL)
                        .textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(settings.provider == .anthropic ? "API Key" : "API Token")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField(
                    settings.provider == .anthropic ? "sk-ant-…" : "Optional for local models",
                    text: $settings.token
                )
                .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if settings.provider == .anthropic {
                    Picker("Model", selection: $settings.model) {
                        ForEach(AISettings.claudeModels) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                    .labelsHidden()
                } else {
                    TextField("e.g. gpt-4o, llava", text: $settings.model)
                        .textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Request Timeout (seconds)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("180", value: $settings.requestTimeout, format: .number)
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
        .onAppear { settings.normalizeClaudeModel() }
        .onChange(of: settings.provider) { settings.normalizeClaudeModel() }
    }
}
