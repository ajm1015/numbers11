import Foundation

/// Manages git-backed version control for the Brewfile.
/// Maintains a local git repo at ~/.brew-manager/ that tracks
/// every change to the package list.
actor GitService {
    static let shared = GitService()

    private let runner = ProcessRunner.shared
    private let repoPath: String

    private static let hexChars = CharacterSet(charactersIn: "0123456789abcdefABCDEF")

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        repoPath = "\(home)/.brew-manager"
    }

    var brewfilePath: String { "\(repoPath)/Brewfile" }
    var lockfilePath: String { "\(repoPath)/Brewfile.lock.json" }

    // MARK: - Validation

    private func validateHash(_ hash: String) throws {
        guard (4...40).contains(hash.count),
              hash.unicodeScalars.allSatisfy({ GitService.hexChars.contains($0) }) else {
            throw GitError.invalidHash(hash)
        }
    }

    // MARK: - Setup

    func ensureRepo() async throws {
        let fm = FileManager.default

        if !fm.fileExists(atPath: repoPath) {
            try fm.createDirectory(atPath: repoPath, withIntermediateDirectories: true)
            _ = try await runner.gitOrThrow("-C", repoPath, "init")
            _ = try await runner.gitOrThrow("-C", repoPath, "checkout", "-b", "main")

            try "# Managed by BrewManager\n".write(
                toFile: brewfilePath, atomically: true, encoding: .utf8
            )
            _ = try await runner.gitOrThrow("-C", repoPath, "add", ".")
            _ = try await runner.gitOrThrow("-C", repoPath, "commit", "-m", "Initial Brewfile")
        }
    }

    // MARK: - Brewfile I/O

    func readBrewfile() async throws -> Brewfile {
        try await ensureRepo()
        let content = try String(contentsOfFile: brewfilePath, encoding: .utf8)
        return BrewfileParser.parse(content)
    }

    func writeBrewfile(_ brewfile: Brewfile, message: String) async throws {
        try await ensureRepo()

        let content = brewfile.serialize()
        try content.write(toFile: brewfilePath, atomically: true, encoding: .utf8)

        _ = try await runner.gitOrThrow("-C", repoPath, "add", "Brewfile")

        let status = try await runner.git("-C", repoPath, "diff", "--cached", "--quiet")
        guard status.exitCode != 0 else { return }

        _ = try await runner.gitOrThrow("-C", repoPath, "commit", "-m", message)
    }

    func writeLockfile(_ content: String) async throws {
        try await ensureRepo()
        try content.write(toFile: lockfilePath, atomically: true, encoding: .utf8)
        _ = try await runner.gitOrThrow("-C", repoPath, "add", "Brewfile.lock.json")

        let status = try await runner.git("-C", repoPath, "diff", "--cached", "--quiet")
        guard status.exitCode != 0 else { return }

        _ = try await runner.gitOrThrow("-C", repoPath, "commit", "-m", "Update Brewfile.lock.json")
    }

    // MARK: - Version History

    func log(limit: Int = 50) async throws -> [VersionEntry] {
        let clampedLimit = max(1, min(limit, 500))
        try await ensureRepo()

        let format = "%H%n%h%n%s%n%an%n%aI"
        let output = try await runner.gitOrThrow(
            "-C", repoPath, "log",
            "--format=\(format)",
            "-n", "\(clampedLimit)",
            "--", "Brewfile"
        )

        guard !output.isEmpty else { return [] }

        var entries: [VersionEntry] = []
        let lines = output.components(separatedBy: .newlines)
        let chunkSize = 5

        for i in stride(from: 0, to: lines.count - chunkSize + 1, by: chunkSize) {
            let hash = lines[i]
            let shortHash = lines[i + 1]
            let message = lines[i + 2]
            let author = lines[i + 3]
            let dateStr = lines[i + 4]

            let formatter = ISO8601DateFormatter()
            let date = formatter.date(from: dateStr) ?? Date()

            let (added, removed) = await parseDiff(hash: hash)

            entries.append(VersionEntry(
                id: hash,
                shortHash: shortHash,
                message: message,
                author: author,
                date: date,
                addedPackages: added,
                removedPackages: removed
            ))
        }

        return entries
    }

    func diffBetween(oldHash: String, newHash: String) async throws -> String {
        try validateHash(oldHash)
        try validateHash(newHash)
        return try await runner.gitOrThrow(
            "-C", repoPath, "diff", oldHash, newHash, "--", "Brewfile"
        )
    }

    func restore(hash: String) async throws {
        try validateHash(hash)
        try await ensureRepo()
        _ = try await runner.gitOrThrow("-C", repoPath, "checkout", hash, "--", "Brewfile")
        _ = try await runner.gitOrThrow("-C", repoPath, "add", "Brewfile")
        _ = try await runner.gitOrThrow(
            "-C", repoPath, "commit", "-m", "Restore Brewfile from \(hash.prefix(7))"
        )
    }

    // MARK: - Private

    private func parseDiff(hash: String) async -> (added: [String], removed: [String]) {
        guard let diff = try? await runner.gitOrThrow(
            "-C", repoPath, "diff", "\(hash)~1", hash, "--", "Brewfile"
        ) else {
            return ([], [])
        }

        var added: [String] = []
        var removed: [String] = []

        for line in diff.components(separatedBy: .newlines) {
            // Match lines like: +brew "jq" or +cask "cursor"
            if line.hasPrefix("+") && !line.hasPrefix("+++") {
                if let name = extractPackageName(from: String(line.dropFirst())) {
                    added.append(name)
                }
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                if let name = extractPackageName(from: String(line.dropFirst())) {
                    removed.append(name)
                }
            }
        }

        return (added, removed)
    }

    private func extractPackageName(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("brew ") || trimmed.hasPrefix("cask ") || trimmed.hasPrefix("tap ") else {
            return nil
        }
        guard let firstQuote = trimmed.firstIndex(of: "\"") else { return nil }
        let afterFirst = trimmed.index(after: firstQuote)
        guard let secondQuote = trimmed[afterFirst...].firstIndex(of: "\"") else { return nil }
        return String(trimmed[afterFirst..<secondQuote])
    }
}

// MARK: - Errors

enum GitError: LocalizedError {
    case invalidHash(String)

    var errorDescription: String? {
        switch self {
        case .invalidHash(let hash):
            return "Invalid git hash: '\(hash)'. Expected 4-40 hexadecimal characters."
        }
    }
}
