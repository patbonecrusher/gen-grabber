import SwiftUI

struct PersonPickerPopover: View {
    let recordType: RecordType
    let people: [Person]
    let onSelect: ([UUID]) -> Void
    let onCancel: () -> Void

    // Wedding / single-person selection.
    @State private var selectedFirst: UUID?
    @State private var selectedSecond: UUID?
    // Legal: any number of parties, in the order they were tapped.
    @State private var multiSelected: [UUID] = []

    private var isWedding: Bool { recordType == .wedding }
    private var isLegal: Bool { recordType.allowsMultiplePeople }
    private var isTwoPerson: Bool { isWedding }

    private var firstLabel: String { "Groom" }
    private var secondLabel: String { "Bride" }

    private var title: String {
        if isLegal { return "Select People" }
        if isWedding { return "Select \(firstLabel) & \(secondLabel)" }
        return "Select Person"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            if isLegal {
                Text("Tap each party involved (in order):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if isWedding && selectedFirst == nil {
                Text("Select \(firstLabel.lowercased()):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if isWedding && selectedFirst != nil && selectedSecond == nil {
                Text("Select \(secondLabel.lowercased()):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(people) { person in
                Button {
                    handleSelection(person.id)
                } label: {
                    HStack {
                        Text(person.gender.rawValue)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(person.gender == .male ? .blue : .pink)
                            .frame(width: 20)
                        Text("\(person.lastName), \(person.firstName)")
                        Spacer()
                        rowAccessory(for: person.id)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        isSelected(person.id) ? Color.accentColor.opacity(0.1) : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }

            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(createLabel) { create() }
                    .disabled(!canCreate)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 260)
    }

    @ViewBuilder
    private func rowAccessory(for id: UUID) -> some View {
        if isLegal {
            if let idx = multiSelected.firstIndex(of: id) {
                Image(systemName: "\(idx + 1).circle.fill")
                    .foregroundStyle(Color.accentColor)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            }
        } else if selectedFirst == id {
            Text(isWedding ? firstLabel : "Selected")
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
        } else if selectedSecond == id {
            Text(secondLabel)
                .font(.caption2)
                .foregroundStyle(.pink)
        }
    }

    private func isSelected(_ id: UUID) -> Bool {
        if isLegal { return multiSelected.contains(id) }
        return selectedFirst == id || selectedSecond == id
    }

    private var createLabel: String {
        isLegal && !multiSelected.isEmpty ? "Create (\(multiSelected.count))" : "Create"
    }

    private var canCreate: Bool {
        if isLegal { return !multiSelected.isEmpty }
        if isWedding { return selectedFirst != nil && selectedSecond != nil }
        return selectedFirst != nil
    }

    private func create() {
        if isLegal {
            guard !multiSelected.isEmpty else { return }
            onSelect(multiSelected)
        } else if isWedding, let first = selectedFirst, let second = selectedSecond {
            onSelect([first, second])
        } else if let first = selectedFirst {
            onSelect([first])
        }
    }

    private func handleSelection(_ id: UUID) {
        if isLegal {
            // Toggle, preserving tap order.
            if let idx = multiSelected.firstIndex(of: id) {
                multiSelected.remove(at: idx)
            } else {
                multiSelected.append(id)
            }
        } else if isWedding {
            // Pick the groom first, then the bride.
            if selectedFirst == id {
                selectedFirst = nil
                selectedSecond = nil
            } else if selectedSecond == id {
                selectedSecond = nil
            } else if selectedFirst == nil {
                selectedFirst = id
            } else {
                selectedSecond = id
            }
        } else {
            // Single person selection - toggle
            selectedFirst = (selectedFirst == id) ? nil : id
        }
    }
}
