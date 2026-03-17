import XCTest
@testable import BrewManager

final class BrewfileParserTests: XCTestCase {

    func testParseBasicBrewfile() {
        let content = """
        # Taps
        tap "homebrew/cask-fonts"

        # Formulae
        brew "jq"
        brew "ripgrep"
        brew "fd"

        # Casks
        cask "ghostty"
        cask "cursor"
        """

        let brewfile = BrewfileParser.parse(content)

        XCTAssertEqual(brewfile.taps.count, 1)
        XCTAssertEqual(brewfile.formulae.count, 3)
        XCTAssertEqual(brewfile.casks.count, 2)

        XCTAssertEqual(brewfile.taps.first?.name, "homebrew/cask-fonts")
        XCTAssertEqual(brewfile.formulae.map(\.name).sorted(), ["fd", "jq", "ripgrep"])
        XCTAssertEqual(brewfile.casks.map(\.name).sorted(), ["cursor", "ghostty"])
    }

    func testParseEntryWithOptions() {
        let content = """
        cask "cursor", args: { appdir: "/Applications" }
        """

        let brewfile = BrewfileParser.parse(content)
        XCTAssertEqual(brewfile.casks.count, 1)
        XCTAssertEqual(brewfile.casks.first?.name, "cursor")
        XCTAssertEqual(brewfile.casks.first?.options.count, 1)
    }

    func testSkipsCommentsAndEmptyLines() {
        let content = """

        # This is a comment
        brew "jq"

        # Another comment
        brew "fd"

        """

        let brewfile = BrewfileParser.parse(content)
        XCTAssertEqual(brewfile.entries.count, 2)
    }

    func testSerializeRoundTrip() {
        let entries = [
            BrewfileEntry(type: .tap, name: "homebrew/cask-fonts", options: []),
            BrewfileEntry(type: .brew, name: "jq", options: []),
            BrewfileEntry(type: .brew, name: "ripgrep", options: []),
            BrewfileEntry(type: .cask, name: "ghostty", options: []),
        ]

        let original = Brewfile(entries: entries)
        let serialized = original.serialize()
        let parsed = BrewfileParser.parse(serialized)

        XCTAssertEqual(parsed.taps.count, original.taps.count)
        XCTAssertEqual(parsed.formulae.count, original.formulae.count)
        XCTAssertEqual(parsed.casks.count, original.casks.count)
    }

    func testSerializeOrdering() {
        let entries = [
            BrewfileEntry(type: .brew, name: "zoxide", options: []),
            BrewfileEntry(type: .cask, name: "ghostty", options: []),
            BrewfileEntry(type: .tap, name: "homebrew/cask-fonts", options: []),
            BrewfileEntry(type: .brew, name: "jq", options: []),
        ]

        let brewfile = Brewfile(entries: entries)
        let serialized = brewfile.serialize()
        let lines = serialized.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // Taps first, then formulae, then casks — all sorted alphabetically
        XCTAssertTrue(lines[0].contains("# Taps"))
        XCTAssertTrue(lines[1].contains("homebrew/cask-fonts"))
        XCTAssertTrue(lines[2].contains("# Formulae"))
        XCTAssertTrue(lines[3].contains("jq"))
        XCTAssertTrue(lines[4].contains("zoxide"))
        XCTAssertTrue(lines[5].contains("# Casks"))
        XCTAssertTrue(lines[6].contains("ghostty"))
    }
}
