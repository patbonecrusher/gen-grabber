import SwiftUI

struct ImageColumnView: View {
    @Bindable var session: SessionModel
    var aiSettings: AISettings
    let tabIndex: Int

    @State private var isParsing = false
    @State private var parseResult: ParsedRecord?
    @State private var showParseConfirmation = false
    @State private var parseError: String?
    @State private var showParseError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // LaFrance — always one
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("LAFRANCE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                        Spacer()
                        if session.tabs[tabIndex].lafranceImage != nil {
                            Button {
                                parseLatFrance()
                            } label: {
                                if isParsing {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Label("Parse", systemImage: "wand.and.stars")
                                        .font(.caption2)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(isParsing || !aiSettings.isConfigured)
                            .help(aiSettings.isConfigured ? "Extract year and record ID" : "Configure AI in Settings first")
                        }
                    }
                    ImageSlotView(
                        label: "",
                        image: $session.tabs[tabIndex].lafranceImage
                    )
                }

                // Page groups
                ForEach(Array(session.tabs[tabIndex].pages.indices), id: \.self) { pageIndex in
                    PageGroupView(
                        pageNumber: pageIndex + 1,
                        page: $session.tabs[tabIndex].pages[pageIndex],
                        canRemove: pageIndex > 0,
                        onRemove: {
                            session.tabs[tabIndex].pages.remove(at: pageIndex)
                        }
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .alert("Parsed Record", isPresented: $showParseConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Apply") {
                if let result = parseResult {
                    session.tabs[tabIndex].year = result.year
                    if session.tabs[tabIndex].pages.indices.contains(0) {
                        session.tabs[tabIndex].pages[0].recordID = result.recordID
                    }
                }
            }
        } message: {
            if let result = parseResult {
                Text("Year: \(result.year)\nRecord ID: \(result.recordID)")
            }
        }
        .alert("Parse Error", isPresented: $showParseError) {
            Button("OK") {}
        } message: {
            Text(parseError ?? "Unknown error")
        }
    }

    private func parseLatFrance() {
        guard let image = session.tabs[tabIndex].lafranceImage else { return }
        isParsing = true
        Task {
            do {
                let result = try await AIParserService.parse(
                    image: image,
                    baseURL: aiSettings.baseURL,
                    token: aiSettings.token,
                    model: aiSettings.model
                )
                parseResult = result
                showParseConfirmation = true
            } catch {
                parseError = error.localizedDescription
                showParseError = true
            }
            isParsing = false
        }
    }
}
