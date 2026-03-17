import XCTest
@testable import BrewManager

final class ModelTests: XCTestCase {

    // MARK: - BrewPackage

    func testBrewPackageIdUniqueness() {
        let formula = BrewPackage(
            name: "python", type: .formula,
            installedVersion: "3.12", latestVersion: nil,
            description: nil, homepage: nil,
            pinned: false, outdated: false, dependencies: []
        )
        let cask = BrewPackage(
            name: "python", type: .cask,
            installedVersion: "3.12", latestVersion: nil,
            description: nil, homepage: nil,
            pinned: false, outdated: false, dependencies: []
        )

        // Same name, different type → different IDs
        XCTAssertNotEqual(formula.id, cask.id)
        XCTAssertEqual(formula.id, "formula:python")
        XCTAssertEqual(cask.id, "cask:python")
    }

    func testBrewPackageIsInstalled() {
        let installed = BrewPackage(
            name: "jq", type: .formula,
            installedVersion: "1.7", latestVersion: "1.7",
            description: nil, homepage: nil,
            pinned: false, outdated: false, dependencies: []
        )
        let notInstalled = BrewPackage(
            name: "jq", type: .formula,
            installedVersion: nil, latestVersion: "1.7",
            description: nil, homepage: nil,
            pinned: false, outdated: false, dependencies: []
        )

        XCTAssertTrue(installed.isInstalled)
        XCTAssertFalse(notInstalled.isInstalled)
    }

    func testBrewPackageHashable() {
        let pkg1 = BrewPackage(
            name: "jq", type: .formula,
            installedVersion: "1.7", latestVersion: "1.7",
            description: nil, homepage: nil,
            pinned: false, outdated: false, dependencies: []
        )
        let pkg2 = BrewPackage(
            name: "jq", type: .formula,
            installedVersion: "1.6", latestVersion: "1.7",
            description: "different", homepage: nil,
            pinned: true, outdated: true, dependencies: ["foo"]
        )

        // Hashable is based on all fields — these should be different
        let set: Set<BrewPackage> = [pkg1, pkg2]
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - BrewfileEntry

    func testBrewfileEntryId() {
        let entry = BrewfileEntry(type: .brew, name: "jq", options: [])
        XCTAssertEqual(entry.id, "brew:jq")
    }

    func testBrewfileEntryBrewfileLine() {
        let simple = BrewfileEntry(type: .brew, name: "jq", options: [])
        XCTAssertEqual(simple.brewfileLine, "brew \"jq\"")

        let withOptions = BrewfileEntry(
            type: .cask, name: "cursor",
            options: ["args: { appdir: \"/Applications\" }"]
        )
        XCTAssertEqual(
            withOptions.brewfileLine,
            "cask \"cursor\", args: { appdir: \"/Applications\" }"
        )

        let tap = BrewfileEntry(type: .tap, name: "homebrew/cask-fonts", options: [])
        XCTAssertEqual(tap.brewfileLine, "tap \"homebrew/cask-fonts\"")
    }

    // MARK: - Brewfile

    func testBrewfileFilters() {
        let brewfile = Brewfile(entries: [
            BrewfileEntry(type: .tap, name: "homebrew/core", options: []),
            BrewfileEntry(type: .brew, name: "jq", options: []),
            BrewfileEntry(type: .brew, name: "fd", options: []),
            BrewfileEntry(type: .cask, name: "ghostty", options: []),
        ])

        XCTAssertEqual(brewfile.taps.count, 1)
        XCTAssertEqual(brewfile.formulae.count, 2)
        XCTAssertEqual(brewfile.casks.count, 1)
    }

    func testBrewfileSerializeEmpty() {
        let brewfile = Brewfile(entries: [])
        XCTAssertEqual(brewfile.serialize(), "\n")
    }

    func testBrewfileSerializeSingleType() {
        let brewfile = Brewfile(entries: [
            BrewfileEntry(type: .brew, name: "zoxide", options: []),
            BrewfileEntry(type: .brew, name: "jq", options: []),
        ])
        let serialized = brewfile.serialize()

        XCTAssertTrue(serialized.contains("# Formulae"))
        XCTAssertFalse(serialized.contains("# Taps"))
        XCTAssertFalse(serialized.contains("# Casks"))

        // jq should come before zoxide (alphabetical)
        let jqRange = serialized.range(of: "jq")!
        let zoxideRange = serialized.range(of: "zoxide")!
        XCTAssertTrue(jqRange.lowerBound < zoxideRange.lowerBound)
    }

    // MARK: - VersionEntry

    func testVersionEntryIdentifiable() {
        let entry = VersionEntry(
            id: "abc123",
            shortHash: "abc1234",
            message: "Install jq",
            author: "BrewManager",
            date: Date(),
            addedPackages: ["jq"],
            removedPackages: []
        )

        XCTAssertEqual(entry.id, "abc123")
    }

    // MARK: - PackageType

    func testPackageTypeRawValues() {
        XCTAssertEqual(PackageType.formula.rawValue, "formula")
        XCTAssertEqual(PackageType.cask.rawValue, "cask")
    }

    // MARK: - Error Types

    func testProcessErrorDescription() {
        let error = ProcessError.executionFailed(command: "brew install jq", exitCode: 1, stderr: "not found")
        let desc = error.localizedDescription
        XCTAssertTrue(desc.contains("brew install jq"))
        XCTAssertTrue(desc.contains("not found"))
    }

    func testProcessErrorCommandNotFound() {
        let error = ProcessError.commandNotFound("/nonexistent")
        XCTAssertTrue(error.localizedDescription.contains("/nonexistent"))
    }

    func testBrewServiceErrorDescriptions() {
        let outputError = BrewServiceError.invalidOutput("bad data")
        XCTAssertTrue(outputError.localizedDescription.contains("bad data"))

        let pathError = BrewServiceError.invalidPath("traversal detected")
        XCTAssertTrue(pathError.localizedDescription.contains("traversal detected"))
    }
}
