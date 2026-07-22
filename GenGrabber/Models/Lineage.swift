import Foundation

/// One ancestor in a descent chain, as written in a folder's `lineage.txt`, e.g.
///
///     Ernest Joseph Pierre Laplante (Sosa 4, gen 03, father)  [spouse: Laurette Seyer]
struct LineageEntry: Identifiable, Sendable, Equatable {
    enum Relation: String, Sendable {
        case you, father, mother, unknown
    }

    /// Sosa (Ahnentafel) numbers are unique within a chain, so they double as the identity.
    var id: Int { sosa }
    var depth: Int          // 0 = Sosa 1 (you); one deeper per generation
    var name: String        // cleaned of the IMMIGRANT / END markers
    var sosa: Int
    var generation: Int
    var relation: Relation
    var spouse: String?     // the other parent, when the line records one
    var isImmigrant: Bool   // first of the line to arrive in New France
    var isEndOfLine: Bool   // no documented ancestors beyond this person
}

/// A parsed `lineage.txt`: the descent from Sosa 1 down to the folder's ancestor.
struct LineageChain: Sendable, Equatable {
    /// The person the whole tree descends to (Sosa 1), taken from the header line.
    var rootName: String
    var entries: [LineageEntry]

    var isEmpty: Bool { entries.isEmpty }

    /// The folder's ancestor — the deepest entry in the chain.
    var subject: LineageEntry? { entries.max { $0.depth < $1.depth } }
}

enum LineageParser {
    static let filename = "lineage.txt"

    // <indent><name> (Sosa N, gen NN, relation)  [spouse: name]
    private static let lineRegex = try! NSRegularExpression(
        pattern: #"^(\s*)(.*?)\s*\(Sosa\s+(\d+),\s*gen\s+(\d+),\s*(\w+)\)(?:\s*\[spouse:\s*(.*?)\])?\s*$"#
    )

    static func load(from folderURL: URL) -> LineageChain {
        let url = folderURL.appendingPathComponent(filename)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return LineageChain(rootName: "", entries: [])
        }
        return parse(text)
    }

    static func parse(_ text: String) -> LineageChain {
        var rootName = ""
        var entries: [LineageEntry] = []

        for rawLine in text.components(separatedBy: .newlines) {
            // Header: "Lineage to Patrick Laplante (Sosa 1):"
            if entries.isEmpty, rootName.isEmpty,
               let header = parseHeader(rawLine) {
                rootName = header
                continue
            }
            if let entry = parseLine(rawLine) {
                entries.append(entry)
            }
        }

        // Fall back to the "you" entry's name when there was no recognizable header.
        if rootName.isEmpty { rootName = entries.first { $0.relation == .you }?.name ?? "" }
        return LineageChain(rootName: rootName, entries: entries)
    }

    private static func parseHeader(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.lowercased().hasPrefix("lineage to ") else { return nil }
        var name = String(trimmed.dropFirst("lineage to ".count))
        // Drop a trailing "(Sosa 1):" and any punctuation.
        if let paren = name.firstIndex(of: "(") { name = String(name[..<paren]) }
        return name.trimmingCharacters(in: CharacterSet(charactersIn: " :"))
    }

    private static func parseLine(_ rawLine: String) -> LineageEntry? {
        let range = NSRange(rawLine.startIndex..., in: rawLine)
        guard let match = lineRegex.firstMatch(in: rawLine, range: range) else { return nil }

        func group(_ i: Int) -> String? {
            guard let r = Range(match.range(at: i), in: rawLine) else { return nil }
            return String(rawLine[r])
        }

        let indent = group(1) ?? ""
        guard let sosa = group(3).flatMap(Int.init),
              let generation = group(4).flatMap(Int.init) else { return nil }

        let (name, isImmigrant, isEndOfLine) = cleanName(group(2) ?? "")
        let relation = LineageEntry.Relation(rawValue: (group(5) ?? "").lowercased()) ?? .unknown
        let spouse = group(6).map { $0.trimmingCharacters(in: .whitespaces) }.flatMap { $0.isEmpty ? nil : $0 }

        return LineageEntry(
            depth: indent.count / 2,
            name: name,
            sosa: sosa,
            generation: generation,
            relation: relation,
            spouse: spouse,
            isImmigrant: isImmigrant,
            isEndOfLine: isEndOfLine
        )
    }

    /// Strips the standalone IMMIGRANT / END markers from a name and reports them as flags.
    private static func cleanName(_ raw: String) -> (name: String, immigrant: Bool, endOfLine: Bool) {
        var tokens = raw.split(separator: " ").map(String.init)
        let immigrant = tokens.contains("IMMIGRANT")
        let endOfLine = tokens.contains("END")
        tokens.removeAll { $0 == "IMMIGRANT" || $0 == "END" }
        return (tokens.joined(separator: " "), immigrant, endOfLine)
    }
}
