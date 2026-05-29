import SwiftUI

struct ImageColumnView: View {
    @Bindable var session: SessionModel
    var aiSettings: AISettings
    let tabIndex: Int

    @State private var isParsing = false
    @State private var parseResult: ParsedRecord?
    @State private var parseTabID: UUID?
    @State private var parseTabLabel: String = ""
    @State private var showParseConfirmation = false
    @State private var parseError: String?
    @State private var showParseError = false

    private var tabID: UUID { session.tabs[tabIndex].id }

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
                                parseLaFrance()
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
                applyParseResult()
            }
        } message: {
            if let result = parseResult {
                Text("Tab: \(parseTabLabel)\nYear: \(result.year)\nRecord ID: \(result.recordID)")
            }
        }
        .alert("Parse Error", isPresented: $showParseError) {
            Button("OK") {}
        } message: {
            Text(parseError ?? "Unknown error")
        }
    }

    private func parseLaFrance() {
        // Capture the tab ID and image snapshot NOW, before the async call
        let currentTabID = tabID
        guard let image = session.tabs[tabIndex].lafranceImage else { return }
        let baseURL = aiSettings.baseURL
        let token = aiSettings.token
        let model = aiSettings.model

        // Debug: save the image being sent so we can verify
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            let debugURL = URL(fileURLWithPath: "/tmp/gengrabber-parse-debug.png")
            try? pngData.write(to: debugURL)
            print("DEBUG: Saved parse image to /tmp/gengrabber-parse-debug.png (\(pngData.count) bytes)")
        }

        isParsing = true
        parseTabID = currentTabID
        parseTabLabel = session.tabLabel(for: session.tabs[tabIndex])

        Task {
            do {
                let result = try await AIParserService.parse(
                    image: image,
                    baseURL: baseURL,
                    token: token,
                    model: model,
                    timeout: aiSettings.requestTimeout
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

    private func applyParseResult() {
        guard let result = parseResult, let savedTabID = parseTabID else { return }
        // Apply to the tab that was parsed, not whatever tab is currently selected
        guard let idx = session.tabs.firstIndex(where: { $0.id == savedTabID }) else { return }
        session.tabs[idx].year = result.year
        if session.tabs[idx].pages.indices.contains(0) {
            session.tabs[idx].pages[0].recordID = result.recordID
        }
    }
}
