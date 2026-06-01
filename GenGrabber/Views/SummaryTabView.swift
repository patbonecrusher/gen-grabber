import SwiftUI

struct SummaryTabView: View {
    @Bindable var session: SessionModel
    var aiSettings: AISettings

    @State private var isGenerating = false
    @State private var progressText = ""
    @State private var errorMessage: String?
    @State private var showOverwriteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Record Summary")
                    .font(.headline)

                Spacer()

                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                    Text(progressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Generate from AI") {
                        if session.summary.records.isEmpty {
                            generate()
                        } else {
                            showOverwriteConfirmation = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!aiSettings.isConfigured || session.tabs.isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if session.summary.records.isEmpty && !isGenerating {
                ContentUnavailableView(
                    "No Summary Yet",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Click \"Generate from AI\" to extract record details from LaFrance screenshots.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(session.summary.records) { record in
                            if let recordIndex = session.summary.records.firstIndex(where: { $0.id == record.id }) {
                                recordGroupBox(recordIndex: recordIndex)
                            }
                        }
                    }
                    .padding(12)
                }
            }

            if let errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss") {
                        self.errorMessage = nil
                    }
                    .controlSize(.mini)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.1))
            }
        }
        .alert("Overwrite Summary?", isPresented: $showOverwriteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Overwrite", role: .destructive) {
                generate()
            }
        } message: {
            Text("This will replace the existing summary data with new AI-extracted records.")
        }
    }

    @ViewBuilder
    private func recordGroupBox(recordIndex: Int) -> some View {
        let recordID = session.summary.records[recordIndex].id
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    LabeledTextField("Type", text: $session.summary.records[recordIndex].recordType)
                    LabeledTextField("Date", text: $session.summary.records[recordIndex].date)
                }
                HStack {
                    LabeledTextField("Parish", text: $session.summary.records[recordIndex].parish)
                    LabeledTextField("Region", text: $session.summary.records[recordIndex].region)
                }
                LabeledTextField("Document", text: $session.summary.records[recordIndex].documentFilename)

                Divider()

                ForEach(session.summary.records[recordIndex].persons) { person in
                    if let ri = session.summary.records.firstIndex(where: { $0.id == recordID }),
                       let pi = session.summary.records[ri].persons.firstIndex(where: { $0.id == person.id }) {
                        personFields(recordIndex: ri, personIndex: pi)
                        if pi < session.summary.records[ri].persons.count - 1 {
                            Divider()
                        }
                    }
                }

                HStack {
                    Button {
                        session.summary.records[recordIndex].persons.append(RecordPersonEntry())
                    } label: {
                        Label("Add Person", systemImage: "plus")
                    }
                    .controlSize(.small)

                    Spacer()

                    Button(role: .destructive) {
                        session.summary.records.removeAll { $0.id == recordID }
                    } label: {
                        Label("Remove Record", systemImage: "trash")
                    }
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 4)
        } label: {
            Text("Record \(recordIndex + 1)")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    @ViewBuilder
    private func personFields(recordIndex: Int, personIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                LabeledTextField("Name", text: $session.summary.records[recordIndex].persons[personIndex].name)
                LabeledTextField("Role", text: $session.summary.records[recordIndex].persons[personIndex].role)
            }
            HStack {
                LabeledTextField("Sex", text: $session.summary.records[recordIndex].persons[personIndex].sex)
                LabeledTextField("Age", text: $session.summary.records[recordIndex].persons[personIndex].age)
                LabeledTextField("Status", text: $session.summary.records[recordIndex].persons[personIndex].maritalStatus)
                LabeledTextField("Occupation", text: $session.summary.records[recordIndex].persons[personIndex].occupation)
            }

            HStack {
                Spacer()
                Button(role: .destructive) {
                    session.summary.records[recordIndex].persons.remove(at: personIndex)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .controlSize(.small)
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
    }

    private func generate() {
        guard aiSettings.isConfigured else { return }

        isGenerating = true
        errorMessage = nil
        session.summary.records = []

        Task {
            let tabsWithLafrance = session.tabs.enumerated().filter { $0.element.lafranceImage != nil }
            let total = tabsWithLafrance.count

            for (index, (_, tab)) in tabsWithLafrance.enumerated() {
                progressText = "Processing record \(index + 1) of \(total)..."

                guard let image = tab.lafranceImage else { continue }

                do {
                    let record = try await AIParserService.extractFullRecord(
                        image: image,
                        baseURL: aiSettings.baseURL,
                        token: aiSettings.token,
                        model: aiSettings.model,
                        timeout: aiSettings.requestTimeout
                    )
                    session.summary.records.append(record)
                } catch {
                    errorMessage = "Error on record \(index + 1): \(error.localizedDescription)"
                }

                // Delay between requests to avoid rate limits
                if index < total - 1 {
                    try? await Task.sleep(for: .seconds(3))
                }
            }

            isGenerating = false
            progressText = ""
        }
    }
}

private struct LabeledTextField: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
        }
    }
}
