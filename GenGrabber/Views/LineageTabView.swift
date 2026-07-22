import SwiftUI

/// A pretty descent chain, from Sosa 1 at the top down to the folder's ancestor. Each generation
/// is a node on a connected timeline, tinted by whether the step was through the father or mother.
struct LineageTabView: View {
    let lineage: LineageChain

    private var subjectID: LineageEntry.ID? { lineage.subject?.id }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if lineage.isEmpty {
                ContentUnavailableView(
                    "No Lineage",
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                    description: Text("This folder has no lineage.txt.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(lineage.entries) { entry in
                            LineageRow(
                                entry: entry,
                                isFirst: entry.id == lineage.entries.first?.id,
                                isLast: entry.id == lineage.entries.last?.id,
                                isSubject: entry.id == subjectID
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Lineage")
                    .font(.headline)
                if !lineage.rootName.isEmpty {
                    Text("Descent to \(lineage.rootName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let subject = lineage.subject {
                Text("\(subject.generation) generations")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// A single ancestor: an indented card hung off a vertical timeline.
private struct LineageRow: View {
    let entry: LineageEntry
    let isFirst: Bool
    let isLast: Bool
    let isSubject: Bool

    private var accent: Color {
        switch entry.relation {
        case .you: return .accentColor
        case .father: return Color(red: 0.29, green: 0.51, blue: 0.75)   // slate blue
        case .mother: return Color(red: 0.78, green: 0.42, blue: 0.51)   // dusty rose
        case .unknown: return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Indent grows one step per generation, giving the cascading descent shape.
            Spacer().frame(width: CGFloat(entry.depth) * 22)

            timeline
            card
        }
    }

    /// The connector line + node dot down the left edge of the card.
    private var timeline: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? .clear : accent.opacity(0.35))
                .frame(width: 2, height: 12)
            Circle()
                .fill(accent)
                .frame(width: 11, height: 11)
                .overlay(Circle().stroke(.background, lineWidth: 2))
            Rectangle()
                .fill(isLast ? .clear : accent.opacity(0.35))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 11)
        .padding(.trailing, 10)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.name)
                    .font(.system(.body, design: .serif))
                    .fontWeight(isSubject ? .bold : .medium)

                if entry.isImmigrant {
                    badge("Immigrant", systemImage: "sailboat.fill", tint: .teal)
                }
                if entry.isEndOfLine {
                    badge("End of line", systemImage: "flag.checkered", tint: .secondary)
                }
            }

            HStack(spacing: 8) {
                relationTag
                Text("Sosa \(entry.sosa)")
                Text("·")
                Text("Gen \(String(format: "%02d", entry.generation))")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            if let spouse = entry.spouse {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill").font(.system(size: 8))
                    Text(spouse)
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSubject ? accent.opacity(0.12) : Color(.textBackgroundColor).opacity(0.4))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSubject ? accent.opacity(0.6) : .clear, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 8)
    }

    private var relationTag: some View {
        Text(entry.relation == .you ? "You" : entry.relation.rawValue.capitalized)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(accent.opacity(0.15), in: Capsule())
    }

    private func badge(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(tint.opacity(0.15), in: Capsule())
    }
}
