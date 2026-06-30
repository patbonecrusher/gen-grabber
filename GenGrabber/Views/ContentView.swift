import SwiftUI

struct ContentView: View {
    @State private var session = SessionModel()
    @State private var aiSettings = AISettings()
    @State private var showClearConfirmation = false
    @State private var showOpenConfirmation = false
    @State private var saveResult: FileSaver.SaveResult?
    @State private var showSaveConfirmation = false
    @State private var showSettings = false
    @State private var saveProgress: SaveProgress?
    @State private var showMissingSummaryWarning = false
    @State private var pendingFolderURL: URL?
    @State private var showNavConfirmation = false
    @State private var savePlan: FileSaver.SavePlan?
    @State private var trashOldFiles = true

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
                    if session.tabs.contains(where: { $0.id == id }) {
                        RecordTabView(session: session, aiSettings: aiSettings, tabID: id)
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

                if session.hasLegacyFiles {
                    Label("Old naming", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .help("This folder has records using the old single-dash naming. Saving converts them to the new -- / __ format.")
                }

                Spacer()

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                }
                .controlSize(.small)

                Button {
                    goPreviousFolder()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .controlSize(.small)
                .disabled(session.previousFolderURL == nil)
                .keyboardShortcut("[", modifiers: .command)
                .help(session.previousFolderURL.map { "Previous folder: \($0.lastPathComponent)" }
                    ?? "No previous folder")

                if let position = session.folderPositionText {
                    Text(position)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Button {
                    goNextFolder()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .controlSize(.small)
                .disabled(session.nextFolderURL == nil)
                .keyboardShortcut("]", modifiers: .command)
                .help(session.nextFolderURL.map { "Next folder: \($0.lastPathComponent)" }
                    ?? "No next folder")

                Button("Open Folder...") {
                    openFolder()
                }
                .controlSize(.small)

                Button("Clear All") {
                    showClearConfirmation = true
                }
                .controlSize(.small)

                Button("Save All...") {
                    if session.summary.records.isEmpty && !session.tabs.isEmpty {
                        showMissingSummaryWarning = true
                    } else {
                        performSave()
                    }
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 700, minHeight: 500)
        .navigationTitle(session.currentFolderURL?.lastPathComponent ?? "Gen Grabber")
        .background {
            // Extra keyboard shortcuts: ⌘← / ⌘→ for previous/next folder (alongside ⌘[ / ⌘]).
            Group {
                Button("", action: goPreviousFolder)
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                    .disabled(session.previousFolderURL == nil)
                Button("", action: goNextFolder)
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                    .disabled(session.nextFolderURL == nil)
            }
            .opacity(0)
            .allowsHitTesting(false)
        }
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
        .sheet(item: $savePlan) { plan in
            SavePreviewView(
                plan: plan,
                trashOldFiles: $trashOldFiles,
                onSave: {
                    savePlan = nil
                    applySave(plan)
                },
                onChangeFolder: { changeSaveFolder() },
                onCancel: { savePlan = nil }
            )
        }
        .alert("Saved", isPresented: $showSaveConfirmation) {
            Button("OK") {}
        } message: {
            if let result = saveResult {
                Text(savedSummary(result))
            }
        }
        .alert("Unsaved Changes", isPresented: $showNavConfirmation) {
            Button("Cancel", role: .cancel) { pendingFolderURL = nil }
            Button("Discard & Continue", role: .destructive) {
                if let url = pendingFolderURL { navigateFolder(to: url) }
                pendingFolderURL = nil
            }
        } message: {
            Text("This folder has unsaved changes. Switch folders without saving?")
        }
        .alert("No Summary", isPresented: $showMissingSummaryWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Save Anyway") { performSave() }
        } message: {
            Text("The AI summary has not been generated. Save without it?")
        }
        .overlay {
            if let progress = saveProgress {
                ZStack {
                    Color.black.opacity(0.3)
                    VStack(spacing: 12) {
                        Text(progress.label)
                            .font(.headline)
                        if progress.total > 0 {
                            ProgressView(value: progress.fraction)
                                .frame(width: 200)
                            Text("\(progress.completed) / \(progress.total)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func performSave() {
        // Preview against the currently-open folder without prompting; only ask for a folder
        // when none is open (a manual/empty session).
        guard let folder = session.currentFolderURL ?? FileSaver.pickSaveFolder(session: session) else { return }
        trashOldFiles = true
        buildPlan(for: folder)
    }

    /// Computes the save plan (showing a progress bar, since encoding images can be slow), then
    /// shows the preview — or, when nothing would change, marks the session clean and confirms.
    private func buildPlan(for folder: URL) {
        let progress = SaveProgress()
        progress.label = "Analyzing changes…"
        saveProgress = progress
        Task {
            let plan = await FileSaver.makePlan(session: session, folder: folder, progress: progress)
            saveProgress = nil
            guard plan.hasChanges else {
                session.markSaved()
                saveResult = FileSaver.SaveResult(createdCount: 0, updatedCount: 0, removedCount: 0, folder: folder)
                savePlan = nil
                showSaveConfirmation = true
                return
            }
            savePlan = plan
        }
    }

    /// Invoked from the preview's "Change Folder…" button — pick a different destination and
    /// recompute the preview against it (the open sheet updates in place).
    private func changeSaveFolder() {
        guard let folder = FileSaver.pickSaveFolder(session: session) else { return }
        buildPlan(for: folder)
    }

    private func applySave(_ plan: FileSaver.SavePlan) {
        let progress = SaveProgress()
        saveProgress = progress
        Task {
            let result = FileSaver.apply(plan, trashOldFiles: trashOldFiles, progress: progress)
            session.markSaved()
            saveResult = result
            saveProgress = nil
            showSaveConfirmation = true
        }
    }

    private func savedSummary(_ result: FileSaver.SaveResult) -> String {
        var parts: [String] = []
        if result.createdCount > 0 { parts.append("\(result.createdCount) created") }
        if result.updatedCount > 0 { parts.append("\(result.updatedCount) updated") }
        if result.removedCount > 0 { parts.append("\(result.removedCount) moved to Trash") }
        let detail = parts.isEmpty ? "No changes" : parts.joined(separator: ", ")
        return "\(detail) in \(result.folder.lastPathComponent)/"
    }

    private func goPreviousFolder() {
        if let url = session.previousFolderURL { requestNavigate(to: url) }
    }

    private func goNextFolder() {
        if let url = session.nextFolderURL { requestNavigate(to: url) }
    }

    private func requestNavigate(to url: URL) {
        if session.hasUnsavedChanges {
            pendingFolderURL = url
            showNavConfirmation = true
        } else {
            navigateFolder(to: url)
        }
    }

    private func navigateFolder(to url: URL) {
        let result = FolderLoader.load(from: url)
        session.loadFromResult(result)
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
