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

            // Todo tab — tinted orange while tasks are still open.
            TabButton(
                label: session.openTodoCount > 0 ? "To Do (\(session.openTodoCount))" : "To Do",
                isSelected: session.selection == .todo,
                isCloseable: false,
                tint: session.openTodoCount > 0 ? .orange : nil,
                onSelect: { session.selection = .todo },
                onClose: {}
            )

            // Lineage tab — only when the folder shipped a lineage.txt.
            if !session.lineage.isEmpty {
                TabButton(
                    label: "Lineage",
                    isSelected: session.selection == .lineage,
                    isCloseable: false,
                    onSelect: { session.selection = .lineage },
                    onClose: {}
                )
            }

            // Summary tab — tinted red when records exist but no summary was generated.
            TabButton(
                label: "Summary",
                isSelected: session.selection == .summary,
                isCloseable: false,
                tint: needsSummary ? .red : nil,
                onSelect: { session.selection = .summary },
                onClose: {}
            )

            // Other tab (only when there are other files)
            if !session.otherFiles.isEmpty {
                TabButton(
                    label: "Other (\(session.otherFiles.files.count))",
                    isSelected: session.selection == .other,
                    isCloseable: false,
                    onSelect: { session.selection = .other },
                    onClose: {}
                )
            }

            Spacer()

            // Creation menu
            Menu {
                Button("Birth") { showPickerFor = .birth }
                Button("Wedding") { showPickerFor = .wedding }
                Button("Legal") { showPickerFor = .legal }
                Button("Sepulture") { showPickerFor = .sepulture }
                Button("Census") { showPickerFor = .census }
                Divider()
                Button("Obituary") { showPickerFor = .obituary }
                Button("Thanks") { showPickerFor = .thanks }
                Divider()
                Button("Misc") { session.addTab(type: .misc, personIDs: []) }
            } label: {
                Label("Add Record", systemImage: "plus")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
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

    /// True when there are records to summarize but no AI summary has been generated yet.
    private var needsSummary: Bool {
        session.summary.records.isEmpty && !session.tabs.isEmpty
    }
}

private struct TabButton: View {
    let label: String
    let isSelected: Bool
    var isCloseable: Bool = true
    var tint: Color? = nil
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(tint ?? .primary)

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
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onTapGesture { onSelect() }
    }

    private var backgroundColor: Color {
        if let tint {
            return tint.opacity(isSelected ? 0.28 : 0.12)
        }
        return isSelected ? Color.accentColor.opacity(0.15) : Color.clear
    }
}
