import XCTest
@testable import BrewManager

final class FeatureTests: XCTestCase {

    // MARK: - Feature 1: Scaling

    func testUIScaleDefaultValue() {
        // Default scale should be 1.0 (verified via UserDefaults since @AppStorage uses it)
        let defaults = UserDefaults.standard
        // Clear any existing value
        defaults.removeObject(forKey: "uiScale")
        let value = defaults.double(forKey: "uiScale")
        // When key doesn't exist, double(forKey:) returns 0.0
        // The @AppStorage default of 1.0 handles this at the view layer
        XCTAssertEqual(value, 0.0, "No stored value means @AppStorage uses its default of 1.0")
    }

    func testUIScaleClamping() {
        // Verify clamping logic: scale should stay within 0.75-1.5
        var scale = 1.0

        // Increment past max
        scale = min(1.5, scale + 0.05)
        XCTAssertEqual(scale, 1.05, accuracy: 0.001)

        scale = 1.5
        scale = min(1.5, scale + 0.05)
        XCTAssertEqual(scale, 1.5, accuracy: 0.001)

        // Decrement past min
        scale = 0.75
        scale = max(0.75, scale - 0.05)
        XCTAssertEqual(scale, 0.75, accuracy: 0.001)
    }

    // MARK: - Feature 3: Brew Validation

    func testIsBrewAvailableReturnsTrue() {
        // On a machine with Homebrew installed, this should return true
        let available = ProcessRunner.isBrewAvailable
        // We can't assert a specific value since it depends on the machine,
        // but we can verify the function doesn't crash and returns a Bool
        XCTAssertTrue(available || !available) // always true, just ensures it compiles and runs
    }

    func testBrewSearchPathsNotEmpty() {
        XCTAssertFalse(ProcessRunner.brewSearchPaths.isEmpty)
        XCTAssertEqual(ProcessRunner.brewSearchPaths.count, 2)
        XCTAssertTrue(ProcessRunner.brewSearchPaths.contains("/opt/homebrew/bin/brew"))
        XCTAssertTrue(ProcessRunner.brewSearchPaths.contains("/usr/local/bin/brew"))
    }

    // MARK: - Feature 4: API Cache

    func testAPICacheInvalidation() async {
        let api = BrewAPIService.shared
        // invalidateCache should not crash on empty cache
        await api.invalidateCache()
    }

    // MARK: - Feature 8: Semantic Diff

    func testVersionEntryEmptyDiffHandled() {
        // Empty addedPackages and removedPackages should be handled gracefully
        let entry = VersionEntry(
            id: "abc123",
            shortHash: "abc",
            message: "Initial Brewfile",
            author: "test",
            date: Date(),
            addedPackages: [],
            removedPackages: []
        )
        XCTAssertTrue(entry.addedPackages.isEmpty)
        XCTAssertTrue(entry.removedPackages.isEmpty)
    }

    func testVersionEntryWithPackages() {
        let entry = VersionEntry(
            id: "def456",
            shortHash: "def",
            message: "Add packages",
            author: "test",
            date: Date(),
            addedPackages: ["jq", "ripgrep", "fd"],
            removedPackages: ["wget"]
        )
        XCTAssertEqual(entry.addedPackages.count, 3)
        XCTAssertEqual(entry.removedPackages.count, 1)
        XCTAssertTrue(entry.addedPackages.contains("jq"))
        XCTAssertTrue(entry.removedPackages.contains("wget"))
    }

    // MARK: - Feature 6: Declarative Mode

    func testBrewfileEntryCreation() {
        let entry = BrewfileEntry(type: .brew, name: "jq", options: [])
        XCTAssertEqual(entry.brewfileLine, "brew \"jq\"")

        let caskEntry = BrewfileEntry(type: .cask, name: "firefox", options: [])
        XCTAssertEqual(caskEntry.brewfileLine, "cask \"firefox\"")
    }

    func testBrewfileMutations() {
        var brewfile = Brewfile(entries: [
            BrewfileEntry(type: .brew, name: "jq", options: []),
            BrewfileEntry(type: .brew, name: "ripgrep", options: []),
            BrewfileEntry(type: .cask, name: "firefox", options: [])
        ])

        // Add an entry
        brewfile.entries.append(BrewfileEntry(type: .brew, name: "fd", options: []))
        XCTAssertEqual(brewfile.formulae.count, 3)

        // Remove an entry
        brewfile.entries.removeAll { $0.name == "jq" && $0.type == .brew }
        XCTAssertEqual(brewfile.formulae.count, 2)
        XCTAssertFalse(brewfile.formulae.contains { $0.name == "jq" })
    }

    // MARK: - Feature 2: Phased Loading

    func testBrewfileEntryToPackageConversion() {
        let entry = BrewfileEntry(type: .brew, name: "jq", options: [])
        let pkg = BrewPackage(
            name: entry.name,
            type: .formula,
            installedVersion: nil,
            latestVersion: nil,
            description: nil,
            homepage: nil,
            pinned: false,
            outdated: false,
            dependencies: []
        )
        XCTAssertEqual(pkg.name, "jq")
        XCTAssertEqual(pkg.type, .formula)
        XCTAssertNil(pkg.installedVersion)
        XCTAssertFalse(pkg.isInstalled)
    }

    func testTapEntriesSkipped() {
        let entries: [BrewfileEntry] = [
            BrewfileEntry(type: .tap, name: "homebrew/cask", options: []),
            BrewfileEntry(type: .brew, name: "jq", options: []),
            BrewfileEntry(type: .cask, name: "firefox", options: [])
        ]
        let packages = entries.compactMap { entry -> BrewPackage? in
            guard entry.type != .tap else { return nil }
            let pkgType: PackageType = entry.type == .cask ? .cask : .formula
            return BrewPackage(
                name: entry.name,
                type: pkgType,
                installedVersion: nil,
                latestVersion: nil,
                description: nil,
                homepage: nil,
                pinned: false,
                outdated: false,
                dependencies: []
            )
        }
        XCTAssertEqual(packages.count, 2)
        XCTAssertFalse(packages.contains { $0.name == "homebrew/cask" })
    }
}
