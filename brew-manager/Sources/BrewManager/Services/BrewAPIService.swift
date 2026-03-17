import Foundation

/// HTTP client for the Homebrew Formulae API (formulae.brew.sh).
/// Used for searching, fetching metadata, and checking latest versions
/// without invoking the brew CLI.
actor BrewAPIService {
    static let shared = BrewAPIService()

    private let baseURL = URL(string: "https://formulae.brew.sh/api")!
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
    }

    // MARK: - Formula

    func fetchFormula(name: String) async throws -> FormulaAPIResponse {
        let url = baseURL.appendingPathComponent("formula/\(name).json")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(FormulaAPIResponse.self, from: data)
    }

    func searchFormulae(query: String) async throws -> [FormulaAPIResponse] {
        // The API doesn't have a search endpoint — fetch all and filter locally.
        // Results are cached by URLSession so subsequent calls are fast.
        let url = baseURL.appendingPathComponent("formula.json")
        let (data, _) = try await session.data(from: url)
        let all = try decoder.decode([FormulaAPIResponse].self, from: data)
        let lowered = query.lowercased()
        return all.filter {
            $0.name.lowercased().contains(lowered)
            || ($0.desc?.lowercased().contains(lowered) ?? false)
        }
    }

    // MARK: - Cask

    func fetchCask(name: String) async throws -> CaskAPIResponse {
        let url = baseURL.appendingPathComponent("cask/\(name).json")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(CaskAPIResponse.self, from: data)
    }

    func searchCasks(query: String) async throws -> [CaskAPIResponse] {
        let url = baseURL.appendingPathComponent("cask.json")
        let (data, _) = try await session.data(from: url)
        let all = try decoder.decode([CaskAPIResponse].self, from: data)
        let lowered = query.lowercased()
        return all.filter {
            $0.token.lowercased().contains(lowered)
            || ($0.desc?.lowercased().contains(lowered) ?? false)
        }
    }
}

// MARK: - API Response Models

struct FormulaAPIResponse: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let fullName: String?
    let desc: String?
    let homepage: String?
    let versions: Versions
    let dependencies: [String]?
    let buildDependencies: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case desc
        case homepage
        case versions
        case dependencies
        case buildDependencies = "build_dependencies"
    }

    struct Versions: Decodable {
        let stable: String?
        let head: String?
    }

    func toBrewPackage(installed: Bool = false, installedVersion: String? = nil) -> BrewPackage {
        BrewPackage(
            name: name,
            type: .formula,
            installedVersion: installedVersion,
            latestVersion: versions.stable,
            description: desc,
            homepage: homepage,
            pinned: false,
            outdated: false,
            dependencies: dependencies ?? []
        )
    }
}

struct CaskAPIResponse: Decodable, Identifiable {
    var id: String { token }
    let token: String
    let name: [String]?
    let desc: String?
    let homepage: String?
    let version: String?

    func toBrewPackage(installed: Bool = false, installedVersion: String? = nil) -> BrewPackage {
        BrewPackage(
            name: token,
            type: .cask,
            installedVersion: installedVersion,
            latestVersion: version,
            description: desc,
            homepage: homepage,
            pinned: false,
            outdated: false,
            dependencies: []
        )
    }
}
