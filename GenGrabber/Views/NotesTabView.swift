import SwiftUI

struct NotesTabView: View {
    @Bindable var session: SessionModel
    @State private var selectedNoteID: UUID?
    @State private var isPreviewing = false

    var body: some View {
        HSplitView {
            // Left pane — note list
            VStack(spacing: 0) {
                List(selection: $selectedNoteID) {
                    ForEach(session.notes) { note in
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text(note.title.isEmpty ? "Untitled" : note.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .tag(note.id)
                        .contextMenu {
                            if session.notes.count > 1 {
                                Button("Delete", role: .destructive) {
                                    if selectedNoteID == note.id {
                                        selectedNoteID = session.notes.first(where: { $0.id != note.id })?.id
                                    }
                                    session.removeNote(note.id)
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)

                Divider()

                Button {
                    session.addNote()
                    selectedNoteID = session.notes.last?.id
                } label: {
                    Label("Add Note", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(8)
            }
            .frame(minWidth: 150, maxWidth: 200)

            // Right pane — note editor
            if let noteIndex = session.notes.firstIndex(where: { $0.id == selectedNoteID }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Title:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Note title (used as filename)", text: $session.notes[noteIndex].title)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 300)

                        Spacer()

                        Picker("", selection: $isPreviewing) {
                            Text("Edit").tag(false)
                            Text("Preview").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }

                    if isPreviewing {
                        ScrollView {
                            MarkdownPreview(text: session.notes[noteIndex].content)
                                .padding(14)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(MarkdownPreview.pageBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        TextEditor(text: $session.notes[noteIndex].content)
                            .font(.body.monospaced())
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color(.windowBackgroundColor).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Text("Saved as \(session.notes[noteIndex].filename)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
            } else {
                ContentUnavailableView {
                    Label("Select a Note", systemImage: "doc.text")
                } description: {
                    Text("Choose a note from the list or add a new one")
                }
            }
        }
        .onAppear {
            if selectedNoteID == nil {
                selectedNoteID = session.notes.first?.id
            }
        }
        .onChange(of: session.notes.map(\.id)) {
            // When a new folder is loaded the notes change out from under us; a
            // stale selection from the previous folder would show the empty state.
            if !session.notes.contains(where: { $0.id == selectedNoteID }) {
                selectedNoteID = session.notes.first?.id
            }
        }
    }
}
