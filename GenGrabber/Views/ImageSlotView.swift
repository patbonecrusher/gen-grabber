import SwiftUI

struct ImageSlotView: View {
    let label: String
    @Binding var image: NSImage?
    var onPreview: (() -> Void)?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            ZStack {
                if let image {
                    // Filled state
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 120)
                        .onTapGesture { onPreview?() }
                        .overlay(alignment: .topTrailing) {
                            Button {
                                self.image = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .padding(4)
                        }
                } else {
                    // Empty state
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isFocused ? Color.accentColor : Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [6])
                        )
                        .frame(minHeight: 60)
                        .overlay {
                            Text(isFocused ? "⌘V to paste" : "Click to paste")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { isFocused = true }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(image != nil ? Color.green.opacity(0.08) : Color.clear)
            )
            .focusable()
            .focused($isFocused)
            .onKeyPress(keys: ["v"]) { keyPress in
                guard keyPress.modifiers.contains(.command) else { return .ignored }
                pasteFromClipboard()
                return .handled
            }
        }
    }

    private func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        guard let pasteboardImage = NSImage(pasteboard: pasteboard) else { return }
        image = pasteboardImage
    }
}
