import SwiftUI

struct PageGroupView: View {
    let pageNumber: Int
    @Binding var page: PageGroup
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("PAGE \(pageNumber)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)

                if !page.recordID.isEmpty {
                    Text("— \(page.recordID)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if canRemove {
                    Button { onRemove() } label: {
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Record slot
            ImageSlotView(label: "Record", image: $page.recordImage)

            // Closeup slots
            ForEach(Array(page.closeupImages.indices), id: \.self) { index in
                HStack(spacing: 4) {
                    ImageSlotView(
                        label: page.closeupImages.count > 1 ? "Closeup \(index + 1)" : "Closeup",
                        image: $page.closeupImages[index]
                    )
                    if page.closeupImages.count > 1 {
                        Button {
                            page.closeupImages.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                page.closeupImages.append(nil)
            } label: {
                Label("Add Closeup", systemImage: "plus")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .padding(8)
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
