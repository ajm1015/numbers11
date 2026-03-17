import Foundation

enum BrewfileParser {
    static func parse(_ content: String) -> Brewfile {
        var entries: [BrewfileEntry] = []

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            if let entry = parseLine(trimmed) {
                entries.append(entry)
            }
        }

        return Brewfile(entries: entries)
    }

    private static func parseLine(_ line: String) -> BrewfileEntry? {
        // Match: type "name"[, options...]
        // e.g.: brew "jq"
        //        cask "cursor", args: { appdir: "/Applications" }
        //        tap "homebrew/cask-fonts"

        let typeStrings: [String: BrewfileEntryType] = [
            "tap": .tap,
            "brew": .brew,
            "cask": .cask,
        ]

        for (prefix, type) in typeStrings {
            guard line.hasPrefix(prefix) else { continue }

            let rest = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)

            // Extract the quoted name
            guard let firstQuote = rest.firstIndex(of: "\"") else { return nil }
            let afterFirst = rest.index(after: firstQuote)
            guard let secondQuote = rest[afterFirst...].firstIndex(of: "\"") else { return nil }

            let name = String(rest[afterFirst..<secondQuote])

            // Extract options (everything after the closing quote + comma)
            var options: [String] = []
            let afterName = rest.index(after: secondQuote)
            if afterName < rest.endIndex {
                let optionString = String(rest[afterName...]).trimmingCharacters(in: .whitespaces)
                if optionString.hasPrefix(",") {
                    let cleaned = String(optionString.dropFirst()).trimmingCharacters(in: .whitespaces)
                    if !cleaned.isEmpty {
                        options.append(cleaned)
                    }
                }
            }

            return BrewfileEntry(type: type, name: name, options: options)
        }

        return nil
    }
}
