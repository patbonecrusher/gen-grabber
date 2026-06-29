import SwiftUI

/// Confirmation sheet shown before saving: lists what will be created / updated / removed,
/// skips unchanged files, and lets the user opt in/out of trashing superseded old files.
struct SavePreviewView: View {
    let plan: FileSaver.SavePlan
    @Binding var trashOldFiles: Bool
    let onSave: () -> Void
    let onChangeFolder: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review Changes")
                .font(.headline)

            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text(plan.folder.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Change…") { onChangeFolder() }
                    .controlSize(.small)
            }

            if !plan.hasChanges {
                ContentUnavailableView(
                    "No Changes to Save",
                    systemImage: "checkmark.circle",
                    description: Text("Everything in this folder is already up to date.")
                )
                .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        section("Created", icon: "plus.circle.fill", color: .green, files: plan.created)
                        section("Updated", icon: "pencil.circle.fill", color: .orange, files: plan.updated)
                        if !plan.removableOldFiles.isEmpty {
                            section("Removed → Trash", icon: "trash.circle.fill", color: .red,
                                    files: trashOldFiles ? plan.removableOldFiles : [],
                                    dimmedFiles: trashOldFiles ? [] : plan.removableOldFiles)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 180, maxHeight: 320)

                if !plan.unchanged.isEmpty {
                    Text("\(plan.unchanged.count) unchanged, skipped")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !plan.removableOldFiles.isEmpty {
                    Toggle("Move \(plan.removableOldFiles.count) old file(s) to Trash", isOn: $trashOldFiles)
                        .toggleStyle(.checkbox)
                        .font(.callout)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!plan.hasChanges)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    @ViewBuilder
    private func section(_ title: String, icon: String, color: Color,
                         files: [URL], dimmedFiles: [URL] = []) -> some View {
        let all = files + dimmedFiles
        if !all.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon).foregroundStyle(color)
                    Text("\(title) (\(all.count))")
                        .font(.subheadline.weight(.semibold))
                }
                ForEach(files, id: \.self) { url in
                    fileRow(url.lastPathComponent, dimmed: false)
                }
                ForEach(dimmedFiles, id: \.self) { url in
                    fileRow(url.lastPathComponent, dimmed: true)
                }
            }
        }
    }

    private func fileRow(_ name: String, dimmed: Bool) -> some View {
        Text(name)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(dimmed ? .tertiary : .secondary)
            .strikethrough(dimmed)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.leading, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
