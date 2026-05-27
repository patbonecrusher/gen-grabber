import SwiftUI

struct PersonPickerPopover: View {
    let recordType: RecordType
    let people: [Person]
    let onSelect: ([UUID]) -> Void
    let onCancel: () -> Void

    @State private var selectedFirst: UUID?
    @State private var selectedSecond: UUID?

    private var isWedding: Bool { recordType == .wedding }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select \(isWedding ? "Groom & Bride" : "Person")")
                .font(.headline)

            if isWedding && selectedFirst == nil {
                Text("Select groom:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if isWedding && selectedFirst != nil && selectedSecond == nil {
                Text("Select bride:")
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
                            Text(isWedding ? "Groom" : "Selected")
                                .font(.caption2)
                                .foregroundStyle(Color.accentColor)
                        }
                        if selectedSecond == person.id {
                            Text("Bride")
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
                Spacer()
                Button("Create") {
                    if isWedding, let first = selectedFirst, let second = selectedSecond {
                        onSelect([first, second])
                    } else if !isWedding, let first = selectedFirst {
                        onSelect([first])
                    }
                }
                .disabled(isWedding ? (selectedFirst == nil || selectedSecond == nil) : selectedFirst == nil)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 260)
    }

    private func handleSelection(_ id: UUID) {
        if !isWedding {
            // Single person selection - toggle
            selectedFirst = (selectedFirst == id) ? nil : id
        } else {
            // Wedding: pick groom first, then bride
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
