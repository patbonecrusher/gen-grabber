import SwiftUI

extension RecordType: Identifiable {
    var id: String { rawValue }
}

struct TabBarView: View {
    @Bindable var session: SessionModel
    @State private var showPickerFor: RecordType?

    var body: some View {
        HStack(spacing: 0) {
            // Record tabs
            ForEach(session.tabs) { tab in
                TabButton(
                    label: session.tabLabel(for: tab),
                    isSelected: session.selection == .record(tab.id),
                    onSelect: { session.selection = .record(tab.id) },
                    onClose: { session.removeTab(tab.id) }
                )
            }

            // Notes tab
            TabButton(
                label: "Notes",
                isSelected: session.selection == .notes,
                isCloseable: false,
                onSelect: { session.selection = .notes },
                onClose: {}
            )

            // Summary tab
            TabButton(
                label: "Summary",
                isSelected: session.selection == .summary,
                isCloseable: false,
                onSelect: { session.selection = .summary },
                onClose: {}
            )

            Spacer()

            // Creation buttons
            HStack(spacing: 4) {
                AddTabButton(label: "+ Birth", color: .green) {
                    showPickerFor = .birth
                }
                AddTabButton(label: "+ Wedding", color: .blue) {
                    showPickerFor = .wedding
                }
                AddTabButton(label: "+ Sepulture", color: .red) {
                    showPickerFor = .sepulture
                }
            }
            .popover(item: $showPickerFor) { type in
                PersonPickerPopover(
                    recordType: type,
                    people: session.people,
                    onSelect: { personIDs in
                        session.addTab(type: type, personIDs: personIDs)
                        showPickerFor = nil
                    },
                    onCancel: { showPickerFor = nil }
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

private struct TabButton: View {
    let label: String
    let isSelected: Bool
    var isCloseable: Bool = true
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .lineLimit(1)

            if isCloseable {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onTapGesture { onSelect() }
    }
}

private struct AddTabButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .buttonStyle(.bordered)
        .tint(color)
        .controlSize(.small)
    }
}
