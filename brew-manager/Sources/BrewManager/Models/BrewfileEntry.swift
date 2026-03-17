import Foundation

enum BrewfileEntryType: String, Codable {
    case tap
    case brew
    case cask
}

struct BrewfileEntry: Identifiable, Hashable {
    var id: String { "\(type.rawValue):\(name)" }
    let type: BrewfileEntryType
    let name: String
    let options: [String]

    var brewfileLine: String {
        let optionString = options.isEmpty ? "" : ", \(options.joined(separator: ", "))"
        return "\(type.rawValue) \"\(name)\"\(optionString)"
    }
}

struct Brewfile {
    var entries: [BrewfileEntry]

    var taps: [BrewfileEntry] { entries.filter { $0.type == .tap } }
    var formulae: [BrewfileEntry] { entries.filter { $0.type == .brew } }
    var casks: [BrewfileEntry] { entries.filter { $0.type == .cask } }

    func serialize() -> String {
        var lines: [String] = []

        let grouped: [(BrewfileEntryType, String)] = [
            (.tap, "# Taps"),
            (.brew, "# Formulae"),
            (.cask, "# Casks"),
        ]

        for (type, header) in grouped {
            let matching = entries.filter { $0.type == type }
            guard !matching.isEmpty else { continue }
            if !lines.isEmpty { lines.append("") }
            lines.append(header)
            for entry in matching.sorted(by: { $0.name < $1.name }) {
                lines.append(entry.brewfileLine)
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }
}
