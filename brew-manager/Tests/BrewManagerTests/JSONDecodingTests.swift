import XCTest
@testable import BrewManager

final class JSONDecodingTests: XCTestCase {

    // MARK: - BrewInfoResponse (brew info --json=v2 --installed)

    func testDecodeFormulaBasic() throws {
        let json = """
        {
            "formulae": [{
                "name": "jq",
                "full_name": "jq",
                "desc": "Lightweight JSON processor",
                "homepage": "https://jqlang.github.io/jq/",
                "versions": { "stable": "1.7.1", "head": null },
                "pinned": false,
                "outdated": false,
                "installed": [{ "version": "1.7.1" }],
                "dependencies": ["oniguruma"]
            }],
            "casks": []
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(BrewInfoResponse.self, from: json)
        XCTAssertEqual(response.formulae.count, 1)
        XCTAssertEqual(response.casks.count, 0)

        let pkg = response.formulae[0].toBrewPackage()
        XCTAssertEqual(pkg.name, "jq")
        XCTAssertEqual(pkg.type, .formula)
        XCTAssertEqual(pkg.installedVersion, "1.7.1")
        XCTAssertEqual(pkg.latestVersion, "1.7.1")
        XCTAssertEqual(pkg.description, "Lightweight JSON processor")
        XCTAssertEqual(pkg.pinned, false)
        XCTAssertEqual(pkg.outdated, false)
        XCTAssertEqual(pkg.dependencies, ["oniguruma"])
        XCTAssertTrue(pkg.isInstalled)
    }

    func testDecodeCaskBasic() throws {
        let json = """
        {
            "formulae": [],
            "casks": [{
                "token": "ghostty",
                "name": ["Ghostty"],
                "desc": "Terminal emulator",
                "homepage": "https://ghostty.org",
                "version": "1.0.0",
                "installed": "1.0.0",
                "outdated": false
            }]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(BrewInfoResponse.self, from: json)
        XCTAssertEqual(response.casks.count, 1)

        let pkg = response.casks[0].toBrewPackage()
        XCTAssertEqual(pkg.name, "ghostty")
        XCTAssertEqual(pkg.type, .cask)
        XCTAssertEqual(pkg.installedVersion, "1.0.0")
        XCTAssertEqual(pkg.latestVersion, "1.0.0")
        XCTAssertFalse(pkg.pinned) // Casks are never pinned
    }

    func testDecodeFormulaNotInstalled() throws {
        let json = """
        {
            "formulae": [{
                "name": "wget",
                "desc": "Internet file retriever",
                "homepage": "https://www.gnu.org/software/wget/",
                "versions": { "stable": "1.24.5" },
                "installed": []
            }],
            "casks": []
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(BrewInfoResponse.self, from: json)
        let pkg = response.formulae[0].toBrewPackage()
        XCTAssertNil(pkg.installedVersion)
        XCTAssertFalse(pkg.isInstalled)
    }

    func testDecodeCaskNotInstalled() throws {
        let json = """
        {
            "formulae": [],
            "casks": [{
                "token": "firefox",
                "name": ["Firefox"],
                "desc": "Web browser",
                "homepage": "https://www.mozilla.org/firefox/",
                "version": "130.0",
                "installed": null,
                "outdated": false
            }]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(BrewInfoResponse.self, from: json)
        let pkg = response.casks[0].toBrewPackage()
        XCTAssertNil(pkg.installedVersion)
        XCTAssertFalse(pkg.isInstalled)
    }

    func testDecodeFormulaMinimalFields() throws {
        // Some fields may be missing from real API responses
        let json = """
        {
            "formulae": [{
                "name": "something"
            }],
            "casks": []
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(BrewInfoResponse.self, from: json)
        let pkg = response.formulae[0].toBrewPackage()
        XCTAssertEqual(pkg.name, "something")
        XCTAssertNil(pkg.installedVersion)
        XCTAssertNil(pkg.latestVersion)
        XCTAssertNil(pkg.description)
        XCTAssertEqual(pkg.pinned, false)
        XCTAssertEqual(pkg.outdated, false)
        XCTAssertEqual(pkg.dependencies, [])
    }

    func testDecodeMultipleFormulaeAndCasks() throws {
        let json = """
        {
            "formulae": [
                { "name": "jq", "installed": [{ "version": "1.7" }] },
                { "name": "fd", "installed": [{ "version": "10.1" }] },
                { "name": "ripgrep", "installed": [{ "version": "14.0" }] }
            ],
            "casks": [
                { "token": "ghostty", "installed": "1.0.0" },
                { "token": "cursor", "installed": "0.45" }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(BrewInfoResponse.self, from: json)
        XCTAssertEqual(response.formulae.count, 3)
        XCTAssertEqual(response.casks.count, 2)
    }

    // MARK: - BrewOutdatedResponse (brew outdated --json=v2)

    func testDecodeOutdatedFormula() throws {
        let json = """
        {
            "formulae": [{
                "name": "node",
                "installed_versions": ["20.0.0"],
                "current_version": "22.0.0",
                "pinned": false,
                "pinned_version": null
            }],
            "casks": []
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(BrewOutdatedResponse.self, from: json)
        XCTAssertEqual(response.formulae.count, 1)
        XCTAssertEqual(response.formulae[0].name, "node")
        XCTAssertEqual(response.formulae[0].installedVersions, ["20.0.0"])
        XCTAssertEqual(response.formulae[0].currentVersion, "22.0.0")
        XCTAssertFalse(response.formulae[0].pinned)
    }

    func testDecodeOutdatedCask() throws {
        let json = """
        {
            "formulae": [],
            "casks": [{
                "name": "firefox",
                "installed_versions": "129.0",
                "current_version": "130.0"
            }]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(BrewOutdatedResponse.self, from: json)
        XCTAssertEqual(response.casks?.count, 1)
        XCTAssertEqual(response.casks?[0].name, "firefox")
        XCTAssertEqual(response.casks?[0].installedVersions, "129.0")
        XCTAssertEqual(response.casks?[0].currentVersion, "130.0")
    }

    func testDecodeOutdatedNoCasks() throws {
        // casks key might be missing entirely
        let json = """
        {
            "formulae": []
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(BrewOutdatedResponse.self, from: json)
        XCTAssertNil(response.casks)
    }

    func testDecodeOutdatedPinnedFormula() throws {
        let json = """
        {
            "formulae": [{
                "name": "python",
                "installed_versions": ["3.11.0"],
                "current_version": "3.12.0",
                "pinned": true,
                "pinned_version": "3.11.0"
            }],
            "casks": []
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(BrewOutdatedResponse.self, from: json)
        XCTAssertTrue(response.formulae[0].pinned)
        XCTAssertEqual(response.formulae[0].pinnedVersion, "3.11.0")
    }

    // MARK: - Invalid JSON

    func testDecodeInvalidJSON() {
        let json = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(BrewInfoResponse.self, from: json))
    }

    func testDecodeEmptyObject() {
        let json = "{}".data(using: .utf8)!
        // formulae and casks are required fields
        XCTAssertThrowsError(try JSONDecoder().decode(BrewInfoResponse.self, from: json))
    }
}
