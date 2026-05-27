import SwiftUI

struct FilenamePreviewView: View {
    let tab: RecordTab
    let people: [Person]

    var body: some View {
        let filenames = FilenameBuilder.filenames(for: tab, people: people)

        VStack(alignment: .leading, spacing: 2) {
            Text("FILENAMES")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 1) {
                filenameRow(filenames.lafrance)
                ForEach(Array(filenames.pages.enumerated()), id: \.offset) { _, page in
                    filenameRow(page.record)
                    ForEach(page.closeups, id: \.self) { closeup in
                        filenameRow(closeup)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func filenameRow(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.green.opacity(0.8))
            .lineLimit(1)
            .truncationMode(.middle)
    }
}
