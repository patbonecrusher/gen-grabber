import SwiftUI

/// Popover content for marking a person's genealogical statuses + origin.
/// Reads/writes through SessionModel so the People row and Summary tab stay in sync.
struct PersonStatusEditor: View {
    @Bindable var session: SessionModel
    let last: String
    let first: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Genealogical Status")
                .font(.headline)

            ForEach(GenealogicalStatus.allCases) { status in
                Toggle(status.label, isOn: binding(for: status))
                    .toggleStyle(.checkbox)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Origin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        ForEach(PersonMark.originSuggestions, id: \.self) { country in
                            Button(country) { session.setOrigin(country, last: last, first: first) }
                        }
                        Divider()
                        Button("Clear") { session.setOrigin("", last: last, first: first) }
                    } label: {
                        Image(systemName: "chevron.down.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                TextField("Country (e.g. France)", text: originBinding)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(14)
        .frame(width: 240)
    }

    private func binding(for status: GenealogicalStatus) -> Binding<Bool> {
        Binding(
            get: { session.isMarked(status, last: last, first: first) },
            set: { session.setStatus(status, $0, last: last, first: first) }
        )
    }

    private var originBinding: Binding<String> {
        Binding(
            get: { session.origin(last: last, first: first) },
            set: { session.setOrigin($0, last: last, first: first) }
        )
    }
}

/// A tag button that opens the status editor; the icon fills in when the person is marked.
struct PersonStatusButton: View {
    @Bindable var session: SessionModel
    let last: String
    let first: String
    @State private var show = false

    private var isMarked: Bool {
        !session.statuses(last: last, first: first).isEmpty
            || !session.origin(last: last, first: first).trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Button {
            show = true
        } label: {
            Image(systemName: isMarked ? "tag.fill" : "tag")
                .foregroundStyle(isMarked ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .help("Mark genealogical status")
        .popover(isPresented: $show) {
            PersonStatusEditor(session: session, last: last, first: first)
        }
    }
}

/// Inline pills summarising a person's marks. Renders nothing when there are none.
struct StatusBadgeRow: View {
    let statuses: Set<GenealogicalStatus>
    let origin: String

    private var ordered: [GenealogicalStatus] {
        GenealogicalStatus.allCases.filter { statuses.contains($0) }
    }
    private var hasOrigin: Bool {
        !origin.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        if !ordered.isEmpty || hasOrigin {
            HStack(spacing: 4) {
                ForEach(ordered) { status in
                    pill(status.badge, color: .accentColor)
                }
                if hasOrigin {
                    pill("↗ \(origin)", color: .gray)
                }
            }
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
