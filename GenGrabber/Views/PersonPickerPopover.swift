import SwiftUI

struct PersonPickerPopover: View {
    let recordType: RecordType
    let people: [Person]
    let onSelect: ([UUID]) -> Void
    let onCancel: () -> Void

    @State private var selectedFirst: UUID?
    @State private var selectedSecond: UUID?

    private var isTwoPerson: Bool { recordType.isCouple }
    private var isWedding: Bool { recordType == .wedding }

    private var firstLabel: String { isWedding ? "Groom" : "First person" }
    private var secondLabel: String { isWedding ? "Bride" : "Second person" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select \(isTwoPerson ? "\(firstLabel) & \(secondLabel)" : "Person")")
                .font(.headline)

            if isTwoPerson && selectedFirst == nil {
                Text("Select \(firstLabel.lowercased()):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if isTwoPerson && selectedFirst != nil && selectedSecond == nil {
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
                        if selectedFirst == person.id {
                            Text(isTwoPerson ? firstLabel : "Selected")
                                .font(.caption2)
                                .foregroundStyle(Color.accentColor)
                        }
                        if selectedSecond == person.id {
                            Text(secondLabel)
                                .font(.caption2)
                                .foregroundStyle(.pink)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        (selectedFirst == person.id || selectedSecond == person.id)
                            ? Color.accentColor.opacity(0.1)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }

            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") {
                    if isTwoPerson, let first = selectedFirst, let second = selectedSecond {
                        onSelect([first, second])
                    } else if !isTwoPerson, let first = selectedFirst {
                        onSelect([first])
                    }
                }
                .disabled(isTwoPerson ? (selectedFirst == nil || selectedSecond == nil) : selectedFirst == nil)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 260)
    }

    private func handleSelection(_ id: UUID) {
        if !isTwoPerson {
            // Single person selection - toggle
            selectedFirst = (selectedFirst == id) ? nil : id
        } else {
            // Two-person: pick the first person, then the second
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
        }
    }
}
