import Foundation

/// Wraps the `brew` CLI for all local Homebrew operations.
@MainActor
final class BrewService: ObservableObject {
    static let shared = BrewService()

    @Published private(set) var isLoading = false

    private let runner = ProcessRunner.shared

    // MARK: - Query

    func listInstalled() async throws -> [BrewPackage] {
        let output = try await runner.brewOrThrow("info", "--json=v2", "--installed")
        guard let data = output.data(using: .utf8) else {
            throw BrewServiceError.invalidOutput("Could not decode brew output as UTF-8")
        }

        let response = try JSONDecoder().decode(BrewInfoResponse.self, from: data)

        let formulae = response.formulae.map { $0.toBrewPackage() }
        let casks = response.casks.map { $0.toBrewPackage() }

        return formulae + casks
    }

    func listOutdated() async throws -> [OutdatedResult] {
        let output = try await runner.brewOrThrow("outdated", "--json=v2")
        guard let data = output.data(using: .utf8) else {
            throw BrewServiceError.invalidOutput("Could not decode brew output as UTF-8")
        }

        let response = try JSONDecoder().decode(BrewOutdatedResponse.self, from: data)

        var results: [OutdatedResult] = []

        for f in response.formulae {
            results.append(OutdatedResult(
                name: f.name,
                type: .formula,
                installedVersion: f.installedVersions.first ?? "?",
                latestVersion: f.currentVersion,
                pinned: f.pinned
            ))
        }

        for c in response.casks ?? [] {
            results.append(OutdatedResult(
                name: c.name,
                type: .cask,
                installedVersion: c.installedVersions,
                latestVersion: c.currentVersion,
                pinned: false
            ))
        }

        return results
    }

    func info(name: String, type: PackageType) async throws -> BrewPackage? {
        let flag = type == .cask ? "--cask" : "--formula"
        let output = try await runner.brewOrThrow("info", "--json=v2", flag, name)
        guard let data = output.data(using: .utf8) else {
            throw BrewServiceError.invalidOutput("Could not decode brew output as UTF-8")
        }

        let response = try JSONDecoder().decode(BrewInfoResponse.self, from: data)

        switch type {
        case .formula:
            return response.formulae.first?.toBrewPackage()
        case .cask:
            return response.casks.first?.toBrewPackage()
        }
    }

    func search(query: String) async throws -> [BrewPackage] {
        let result = try await runner.brew("search", query)
        guard result.exitCode == 0 else { return [] }

        var packages: [BrewPackage] = []
        var section: PackageType = .formula

        for line in result.stdout.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("Formulae") {
                section = .formula
                continue
            } else if trimmed.contains("Casks") {
                section = .cask
                continue
            }
            guard !trimmed.isEmpty, !trimmed.hasPrefix("=") else { continue }

            packages.append(BrewPackage(
                name: trimmed,
                type: section,
                installedVersion: nil,
                latestVersion: nil,
                description: nil,
                homepage: nil,
                pinned: false,
                outdated: false,
                dependencies: []
            ))
        }

        return packages
    }

    // MARK: - Actions

    func install(name: String, type: PackageType) async throws {
        let flag = type == .cask ? "--cask" : "--formula"
        _ = try await runner.brewOrThrow("install", flag, name)
    }

    func uninstall(name: String, type: PackageType) async throws {
        let flag = type == .cask ? "--cask" : "--formula"
        _ = try await runner.brewOrThrow("uninstall", flag, name)
    }

    func upgrade(name: String, type: PackageType) async throws {
        let flag = type == .cask ? "--cask" : "--formula"
        _ = try await runner.brewOrThrow("upgrade", flag, name)
    }

    func upgradeAll() async throws {
        _ = try await runner.brewOrThrow("upgrade")
    }

    func pin(name: String) async throws {
        _ = try await runner.brewOrThrow("pin", name)
    }

    func unpin(name: String) async throws {
        _ = try await runner.brewOrThrow("unpin", name)
    }

    // MARK: - Brewfile

    func dumpBrewfile() async throws -> Brewfile {
        let output = try await runner.brewOrThrow("bundle", "dump", "--file=-", "--describe")
        return BrewfileParser.parse(output)
    }

    func installFromBrewfile(at path: String) async throws {
        try validateBrewfilePath(path)
        _ = try await runner.brewOrThrow("bundle", "install", "--file=\(path)")
    }

    func checkBrewfile(at path: String) async throws -> Bool {
        try validateBrewfilePath(path)
        let result = try await runner.brew("bundle", "check", "--file=\(path)")
        return result.exitCode == 0
    }

    // MARK: - Private

    private func validateBrewfilePath(_ path: String) throws {
        let resolved = (path as NSString).standardizingPath
        guard FileManager.default.fileExists(atPath: resolved) else {
            throw BrewServiceError.invalidPath("File does not exist: \(resolved)")
        }
        guard !resolved.contains("..") else {
            throw BrewServiceError.invalidPath("Path traversal not allowed: \(path)")
        }
    }
}

// MARK: - Errors

enum BrewServiceError: LocalizedError {
    case invalidOutput(String)
    case invalidPath(String)

    var errorDescription: String? {
        switch self {
        case .invalidOutput(let detail):
            return "Invalid brew output: \(detail)"
        case .invalidPath(let detail):
            return "Invalid Brewfile path: \(detail)"
        }
    }
}

// MARK: - Outdated Result

struct OutdatedResult {
    let name: String
    let type: PackageType
    let installedVersion: String
    let latestVersion: String
    let pinned: Bool
}
