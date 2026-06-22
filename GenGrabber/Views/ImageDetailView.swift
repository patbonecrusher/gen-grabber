import SwiftUI

struct ImagePreview: Identifiable {
    let id = UUID()
    let image: NSImage
    let pageIndex: Int?  // nil for LaFrance
}

struct ImageDetailView: View {
    let image: NSImage
    @Binding var parsedText: String
    let aiSettings: AISettings
    let onDismiss: () -> Void

    @State private var isExtracting = false
    @State private var extractError: String?
    @State private var showError = false
    @State private var zoom: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Document Preview")
                    .font(.headline)

                Spacer()

                // Zoom controls
                HStack(spacing: 4) {
                    Button {
                        zoom = max(0.25, zoom - 0.25)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(.borderless)

                    Text("\(Int(zoom * 100))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 40)

                    Button {
                        zoom = min(5.0, zoom + 0.25)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(.borderless)

                    Button {
                        zoom = 1.0
                    } label: {
                        Text("Fit")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                Button {
                    extractText()
                } label: {
                    if isExtracting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Extract Text", systemImage: "doc.text.magnifyingglass")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isExtracting || !aiSettings.isConfigured)
                .help(aiSettings.isConfigured ? "Transcribe text from this image" : "Configure AI in Settings first")

                Button("Close") { onDismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(10)

            Divider()

            // Content: image + parsed text side by side
            HSplitView {
                // Image (zoomable, scrollable)
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(zoom)
                        .frame(
                            width: image.size.width * zoom,
                            height: image.size.height * zoom
                        )
                        .padding(20)
                }
                .frame(minWidth: 300)

                // Parsed text
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("PARSED TEXT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                        Spacer()
                        if !parsedText.isEmpty {
                            Button {
                                parsedText = ""
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if parsedText.isEmpty && !isExtracting {
                        ContentUnavailableView {
                            Label("No Text Yet", systemImage: "doc.text")
                        } description: {
                            Text("Click \"Extract Text\" to transcribe this document")
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        TextEditor(text: $parsedText)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(10)
                .frame(minWidth: 250)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(WindowResizableHelper())
        .alert("Extract Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(extractError ?? "Unknown error")
        }
    }

    private struct WindowResizableHelper: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            DispatchQueue.main.async {
                if let window = view.window {
                    window.styleMask.insert(.resizable)
                }
            }
            return view
        }
        func updateNSView(_ nsView: NSView, context: Context) {}
    }

    private func extractText() {
        isExtracting = true
        let baseURL = aiSettings.baseURL
        let token = aiSettings.token
        let model = aiSettings.model

        Task {
            do {
                let text = try await AIParserService.extractText(
                    images: [image],
                    provider: aiSettings.provider,
                    baseURL: baseURL,
                    token: token,
                    model: model,
                    timeout: aiSettings.requestTimeout
                )
                parsedText = text
            } catch {
                extractError = error.localizedDescription
                showError = true
            }
            isExtracting = false
        }
    }
}
