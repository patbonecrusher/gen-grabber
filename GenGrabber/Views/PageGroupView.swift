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

            HStack(spacing: 8) {
                ImageSlotView(label: "Record", image: $page.recordImage)
                ImageSlotView(label: "Closeup", image: $page.closeupImage)
            }
        }
        .padding(8)
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
