import SwiftUI

struct NotesTabView: View {
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Notes")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextEditor(text: $notes)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(.windowBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Saved as notes.txt — leave empty to skip")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
    }
}
