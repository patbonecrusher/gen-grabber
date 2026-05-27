import SwiftUI

struct ContentView: View {
    @State private var session = SessionModel()
    @State private var showClearConfirmation = false
    @State private var saveResult: FileSaver.SaveResult?
    @State private var showSaveConfirmation = false

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
                if let selectedID = session.selectedTabID,
                   let tabIndex = session.tabs.firstIndex(where: { $0.id == selectedID }) {
                    RecordTabView(session: session, tabIndex: tabIndex)
                } else {
                    NotesTabView(notes: $session.notes)
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
        .alert("Saved", isPresented: $showSaveConfirmation) {
            Button("OK") {}
        } message: {
            if let result = saveResult {
                Text("Saved \(result.fileCount) files to \(result.folder.lastPathComponent)/")
            }
        }
    }
}
