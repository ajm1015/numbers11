import XCTest
@testable import BrewManager

final class BrewfileParserEdgeCaseTests: XCTestCase {

    func testParseEmptyString() {
        let brewfile = BrewfileParser.parse("")
        XCTAssertTrue(brewfile.entries.isEmpty)
    }

    func testParseOnlyComments() {
        let content = """
        # This is a comment
        # Another comment
        """
        let brewfile = BrewfileParser.parse(content)
        XCTAssertTrue(brewfile.entries.isEmpty)
    }

    func testParseOnlyWhitespace() {
        let content = "   \n\n   \n   "
        let brewfile = BrewfileParser.parse(content)
        XCTAssertTrue(brewfile.entries.isEmpty)
    }

    func testParseMalformedLineNoQuotes() {
        let content = "brew jq"
        let brewfile = BrewfileParser.parse(content)
        XCTAssertTrue(brewfile.entries.isEmpty)
    }

    func testParseMalformedLineUnclosedQuote() {
        let content = "brew \"jq"
        let brewfile = BrewfileParser.parse(content)
        XCTAssertTrue(brewfile.entries.isEmpty)
    }

    func testParseUnrecognizedType() {
        let content = """
        unknown "something"
        brew "jq"
        """
        let brewfile = BrewfileParser.parse(content)
        XCTAssertEqual(brewfile.entries.count, 1)
        XCTAssertEqual(brewfile.entries[0].name, "jq")
    }

    func testParseLeadingWhitespace() {
        let content = "    brew \"jq\""
        let brewfile = BrewfileParser.parse(content)
        XCTAssertEqual(brewfile.entries.count, 1)
        XCTAssertEqual(brewfile.entries[0].name, "jq")
    }

    func testParseMultipleOptions() {
        let content = """
        cask "virtualbox", args: { appdir: "/Applications" }, greedy: true
        """
        let brewfile = BrewfileParser.parse(content)
        XCTAssertEqual(brewfile.casks.count, 1)
        XCTAssertEqual(brewfile.casks[0].name, "virtualbox")
        // Options after the name+comma are captured as a single string
        XCTAssertFalse(brewfile.casks[0].options.isEmpty)
    }

    func testParseNameWithSlash() {
        // Taps commonly have slashes
        let content = "tap \"homebrew/cask-versions\""
        let brewfile = BrewfileParser.parse(content)
        XCTAssertEqual(brewfile.taps.count, 1)
        XCTAssertEqual(brewfile.taps[0].name, "homebrew/cask-versions")
    }

    func testParseNameWithHyphens() {
        let content = "brew \"node@20\""
        let brewfile = BrewfileParser.parse(content)
        XCTAssertEqual(brewfile.entries.count, 1)
        XCTAssertEqual(brewfile.entries[0].name, "node@20")
    }

    func testParseDuplicateEntries() {
        let content = """
        brew "jq"
        brew "jq"
        """
        let brewfile = BrewfileParser.parse(content)
        // Parser doesn't deduplicate — that's the caller's job
        XCTAssertEqual(brewfile.entries.count, 2)
    }

    func testParseMixedWithComments() {
        let content = """
        # Development tools
        brew "jq"
        # brew "unused-tool"
        cask "ghostty"
        # End of file
        """
        let brewfile = BrewfileParser.parse(content)
        XCTAssertEqual(brewfile.entries.count, 2)
        XCTAssertEqual(brewfile.formulae[0].name, "jq")
        XCTAssertEqual(brewfile.casks[0].name, "ghostty")
    }

    func testSerializeAndReparsePreservesData() {
        let entries = [
            BrewfileEntry(type: .tap, name: "homebrew/cask-fonts", options: []),
            BrewfileEntry(type: .tap, name: "homebrew/core", options: []),
            BrewfileEntry(type: .brew, name: "zoxide", options: []),
            BrewfileEntry(type: .brew, name: "jq", options: []),
            BrewfileEntry(type: .brew, name: "fd", options: []),
            BrewfileEntry(type: .cask, name: "ghostty", options: []),
            BrewfileEntry(type: .cask, name: "cursor", options: []),
        ]

        let original = Brewfile(entries: entries)
        let serialized = original.serialize()
        let reparsed = BrewfileParser.parse(serialized)

        XCTAssertEqual(reparsed.taps.map(\.name).sorted(), ["homebrew/cask-fonts", "homebrew/core"])
        XCTAssertEqual(reparsed.formulae.map(\.name).sorted(), ["fd", "jq", "zoxide"])
        XCTAssertEqual(reparsed.casks.map(\.name).sorted(), ["cursor", "ghostty"])
    }
}
