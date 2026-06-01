import SwiftUI

struct ContentView: View {
    @State private var session = SessionModel()
    @State private var aiSettings = AISettings()
    @State private var showClearConfirmation = false
    @State private var showOpenConfirmation = false
    @State private var saveResult: FileSaver.SaveResult?
    @State private var showSaveConfirmation = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // People list
            PeopleListView(session: session)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Tab bar
            TabBarView(session: session)

            Divider()

            // Tab content
            Group {
                switch session.selection {
                case .record(let id):
                    if let tabIndex = session.tabs.firstIndex(where: { $0.id == id }) {
                        RecordTabView(session: session, aiSettings: aiSettings, tabIndex: tabIndex)
                            .id(id)
                    }
                case .notes:
                    NotesTabView(session: session)
                case .summary:
                    SummaryTabView(session: session, aiSettings: aiSettings)
                case .other:
                    OtherFilesTabView(session: session)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Bottom bar
            HStack {
                Text("\(session.tabs.count) records, \(session.totalImageCount) images")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                }
                .controlSize(.small)

                Button("Open Folder...") {
                    openFolder()
                }
                .controlSize(.small)

                Button("Clear All") {
                    showClearConfirmation = true
                }
                .controlSize(.small)

                Button("Save All...") {
                    Task {
                        if let result = await FileSaver.saveAll(session: session) {
                            saveResult = result
                            showSaveConfirmation = true
                        }
                    }
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 700, minHeight: 500)
        .alert("Clear All?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                session.clearAll()
            }
        } message: {
            Text("This will remove all people, records, and images. This cannot be undone.")
        }
        .alert("Open Folder?", isPresented: $showOpenConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Open", role: .destructive) {
                if let result = FolderLoader.pickAndLoad() {
                    session.loadFromResult(result)
                }
            }
        } message: {
            Text("This will clear the current session and load from the selected folder.")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: aiSettings)
        }
        .alert("Saved", isPresented: $showSaveConfirmation) {
            Button("OK") {}
        } message: {
            if let result = saveResult {
                Text("Saved \(result.fileCount) files to \(result.folder.lastPathComponent)/")
            }
        }
    }

    private func openFolder() {
        if session.tabs.isEmpty && session.people.isEmpty {
            if let result = FolderLoader.pickAndLoad() {
                session.loadFromResult(result)
            }
        } else {
            showOpenConfirmation = true
        }
    }
}
