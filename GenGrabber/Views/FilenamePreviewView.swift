import SwiftUI

struct FilenamePreviewView: View {
    let tab: RecordTab
    let people: [Person]

    var body: some View {
        let closeupCounts = tab.pages.map { $0.closeupImages.count }
        let filenames = FilenameBuilder.filenames(for: tab, people: people, closeupCounts: closeupCounts)

        VStack(alignment: .leading, spacing: 2) {
            Text("FILENAMES")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 1) {
                if let lafrance = filenames.lafrance {
                    filenameRow(lafrance)
                }
                ForEach(Array(zip(tab.pages, filenames.pages).enumerated()), id: \.offset) { _, pair in
                    let (tabPage, pageFilenames) = pair
                    filenameRow(pageFilenames.record)
                    if !tabPage.parsedText.isEmpty {
                        filenameRow(pageFilenames.parsed)
                    }
                    ForEach(pageFilenames.closeups, id: \.self) { closeup in
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
