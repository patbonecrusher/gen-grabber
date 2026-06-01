import SwiftUI

struct MetadataColumnView: View {
    @Bindable var session: SessionModel
    let tabIndex: Int

    private var tab: RecordTab { session.tabs[tabIndex] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // People info (read-only)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(tab.personIDs, id: \.self) { personID in
                    if let person = session.person(for: personID) {
                        HStack(spacing: 4) {
                            Text(person.gender == .male ? "M" : "F")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(person.gender == .male ? .blue : .pink)
                            Text("\(person.lastName), \(person.firstName)")
                                .font(.caption)
                        }
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.windowBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Year
            VStack(alignment: .leading, spacing: 2) {
                Text("YEAR")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                TextField("Year", text: $session.tabs[tabIndex].year)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospacedDigit())
            }

            // Page groups
            ForEach(Array(session.tabs[tabIndex].pages.indices), id: \.self) { pageIndex in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("PAGE \(pageIndex + 1)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                        if pageIndex > 0 {
                            Button {
                                session.tabs[tabIndex].pages.remove(at: pageIndex)
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("SOURCE / ID")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        TextField("e.g. d1p_12345 or newspaper name", text: $session.tabs[tabIndex].pages[pageIndex].recordID)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospaced())
                    }
                }
                .padding(8)
                .background(Color(.windowBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Add page button
            Button {
                session.tabs[tabIndex].pages.append(PageGroup())
            } label: {
                Label("Add Page", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)

            Spacer()

            // Filename preview
            FilenamePreviewView(tab: tab, people: session.people)
        }
        .frame(width: 200)
    }
}
