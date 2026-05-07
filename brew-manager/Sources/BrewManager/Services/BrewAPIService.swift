import Foundation

/// HTTP client for the Homebrew Formulae API (formulae.brew.sh).
/// Used for searching, fetching metadata, and checking latest versions
/// without invoking the brew CLI.
actor BrewAPIService {
    static let shared = BrewAPIService()

    private let baseURL = URL(string: "https://formulae.brew.sh/api")!
    private let session: URLSession
    private let decoder: JSONDecoder

    private var cachedFormulae: [FormulaAPIResponse]?
    private var formulaeCacheTime: Date?
    private var cachedCasks: [CaskAPIResponse]?
    private var casksCacheTime: Date?
    private let cacheTTL: TimeInterval = 3600 // 1 hour

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
    }

    // MARK: - Cache

    func invalidateCache() {
        cachedFormulae = nil
        formulaeCacheTime = nil
        cachedCasks = nil
        casksCacheTime = nil
    }

    private func isCacheValid(for time: Date?) -> Bool {
        guard let time else { return false }
        return Date().timeIntervalSince(time) < cacheTTL
    }

    private func getAllFormulae() async throws -> [FormulaAPIResponse] {
        if let cached = cachedFormulae, isCacheValid(for: formulaeCacheTime) {
            return cached
        }
        let url = baseURL.appendingPathComponent("formula.json")
        let (data, _) = try await session.data(from: url)
        let all = try decoder.decode([FormulaAPIResponse].self, from: data)
        cachedFormulae = all
        formulaeCacheTime = Date()
        return all
    }

    private func getAllCasks() async throws -> [CaskAPIResponse] {
        if let cached = cachedCasks, isCacheValid(for: casksCacheTime) {
            return cached
        }
        let url = baseURL.appendingPathComponent("cask.json")
        let (data, _) = try await session.data(from: url)
        let all = try decoder.decode([CaskAPIResponse].self, from: data)
        cachedCasks = all
        casksCacheTime = Date()
        return all
    }

    // MARK: - Formula

    func fetchFormula(name: String) async throws -> FormulaAPIResponse {
        let url = baseURL.appendingPathComponent("formula/\(name).json")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(FormulaAPIResponse.self, from: data)
    }

    func searchFormulae(query: String) async throws -> [FormulaAPIResponse] {
        let all = try await getAllFormulae()
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
        let all = try await getAllCasks()
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
