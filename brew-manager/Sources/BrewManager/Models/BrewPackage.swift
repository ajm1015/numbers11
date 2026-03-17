import Foundation

enum PackageType: String, Codable, CaseIterable {
    case formula
    case cask
}

struct BrewPackage: Identifiable, Hashable {
    var id: String { "\(type.rawValue):\(name)" }
    let name: String
    let type: PackageType
    let installedVersion: String?
    let latestVersion: String?
    let description: String?
    let homepage: String?
    let pinned: Bool
    let outdated: Bool
    let dependencies: [String]

    var isInstalled: Bool { installedVersion != nil }
}

// MARK: - brew info --json=v2 --installed

/// Formula entry from `brew info --json=v2 --installed`
struct BrewFormulaJSON: Decodable {
    let name: String
    let fullName: String?
    let desc: String?
    let homepage: String?
    let versions: FormulaVersions?
    let pinned: Bool?
    let outdated: Bool?
    let installed: [InstalledInfo]?
    let dependencies: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case desc
        case homepage
        case versions
        case pinned
        case outdated
        case installed
        case dependencies
    }

    struct FormulaVersions: Decodable {
        let stable: String?
        let head: String?
    }

    struct InstalledInfo: Decodable {
        let version: String
    }

    func toBrewPackage() -> BrewPackage {
        BrewPackage(
            name: name,
            type: .formula,
            installedVersion: installed?.first?.version,
            latestVersion: versions?.stable,
            description: desc,
            homepage: homepage,
            pinned: pinned ?? false,
            outdated: outdated ?? false,
            dependencies: dependencies ?? []
        )
    }
}

/// Cask entry from `brew info --json=v2 --installed`
/// Note: `installed` is a version string (not an array like formulae)
struct BrewCaskJSON: Decodable {
    let token: String
    let name: [String]?
    let desc: String?
    let homepage: String?
    let version: String?
    let installed: String?
    let outdated: Bool?

    func toBrewPackage() -> BrewPackage {
        BrewPackage(
            name: token,
            type: .cask,
            installedVersion: installed,
            latestVersion: version,
            description: desc,
            homepage: homepage,
            pinned: false,
            outdated: outdated ?? false,
            dependencies: []
        )
    }
}

/// Top-level response from `brew info --json=v2 --installed`
struct BrewInfoResponse: Decodable {
    let formulae: [BrewFormulaJSON]
    let casks: [BrewCaskJSON]
}

// MARK: - brew outdated --json=v2

/// Formula entry from `brew outdated --json=v2`
struct OutdatedFormulaJSON: Decodable {
    let name: String
    let installedVersions: [String]
    let currentVersion: String
    let pinned: Bool
    let pinnedVersion: String?

    enum CodingKeys: String, CodingKey {
        case name
        case installedVersions = "installed_versions"
        case currentVersion = "current_version"
        case pinned
        case pinnedVersion = "pinned_version"
    }
}

/// Cask entry from `brew outdated --json=v2`
struct OutdatedCaskJSON: Decodable {
    let name: String
    let installedVersions: String
    let currentVersion: String

    enum CodingKeys: String, CodingKey {
        case name
        case installedVersions = "installed_versions"
        case currentVersion = "current_version"
    }
}

/// Top-level response from `brew outdated --json=v2`
struct BrewOutdatedResponse: Decodable {
    let formulae: [OutdatedFormulaJSON]
    let casks: [OutdatedCaskJSON]?
}
