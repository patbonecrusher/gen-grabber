import SwiftUI

struct OtherFilesTabView: View {
    @Bindable var session: SessionModel

    @State private var promotingFile: OtherFile?
    @State private var promoteType: RecordType?

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            if session.otherFiles.isEmpty {
                ContentUnavailableView("No Other Files", systemImage: "photo.on.rectangle.angled")
                    .padding(.top, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(session.otherFiles.files) { file in
                        VStack(spacing: 4) {
                            if let image = file.image {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 120)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundStyle(.secondary)
                                    }
                            }

                            Text(file.filename)
                                .font(.caption2)
                                .lineLimit(2)
                                .foregroundStyle(.secondary)

                            Menu {
                                Button("Birth") { startPromote(file, as: .birth) }
                                Button("Wedding") { startPromote(file, as: .wedding) }
                                Button("Legal") { startPromote(file, as: .legal) }
                                Button("Sepulture") { startPromote(file, as: .sepulture) }
                                Button("Census") { startPromote(file, as: .census) }
                                Divider()
                                Button("Obituary") { startPromote(file, as: .obituary) }
                                Button("Thanks") { startPromote(file, as: .thanks) }
                            } label: {
                                Label("Assign to Record", systemImage: "arrow.up.doc")
                                    .font(.caption2)
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                        }
                    }
                }
                .padding(12)
            }
        }
        .popover(item: $promoteType) { type in
            PersonPickerPopover(
                recordType: type,
                people: session.people,
                onSelect: { personIDs in
                    if let file = promotingFile {
                        session.promoteOtherFile(file.id, type: type, personIDs: personIDs)
                    }
                    promoteType = nil
                    promotingFile = nil
                },
                onCancel: {
                    promoteType = nil
                    promotingFile = nil
                }
            )
        }
    }

    private func startPromote(_ file: OtherFile, as type: RecordType) {
        promotingFile = file
        promoteType = type
    }
}
