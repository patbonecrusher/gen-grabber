import SwiftUI

struct MetadataColumnView: View {
    @Bindable var session: SessionModel
    let tabIndex: Int

    var body: some View {
        if session.tabs.indices.contains(tabIndex) {
            let tab = session.tabs[tabIndex]
            VStack(alignment: .leading, spacing: 10) {
                if tab.recordType == .misc {
                    // Custom label for misc records
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FILENAME")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        TextField("e.g. family-photo-1920", text: $session.tabs[tabIndex].customLabel)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospaced())
                    }
                } else {
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
                }

                // Page groups — iterate by ID to avoid stale index bindings on removal
                ForEach($session.tabs[tabIndex].pages) { $page in
                    let pageIndex = session.tabs[tabIndex].pages.firstIndex { $0.id == page.id } ?? 0
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("PAGE \(pageIndex + 1)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.accentColor)
                            Spacer()
                            if pageIndex > 0 {
                                Button {
                                    session.tabs[tabIndex].pages.removeAll { $0.id == page.id }
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
                            TextField("e.g. d1p_12345 or newspaper name", text: $page.recordID)
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
}
