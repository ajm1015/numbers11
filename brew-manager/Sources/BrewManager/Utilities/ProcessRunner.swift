import Foundation

enum ProcessError: LocalizedError {
    case executionFailed(command: String, exitCode: Int32, stderr: String)
    case commandNotFound(String)

    var errorDescription: String? {
        switch self {
        case .executionFailed(let cmd, let code, let stderr):
            return "Command '\(cmd)' failed (exit \(code)): \(stderr)"
        case .commandNotFound(let cmd):
            return "Command not found: \(cmd)"
        }
    }
}

struct ProcessResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

actor ProcessRunner {
    static let shared = ProcessRunner()

    private let brewPath: String

    private init() {
        // Detect Homebrew path (Apple Silicon vs Intel)
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") {
            brewPath = "/opt/homebrew/bin/brew"
        } else {
            brewPath = "/usr/local/bin/brew"
        }
    }

    var resolvedBrewPath: String { brewPath }

    func run(_ executable: String, arguments: [String] = []) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        // Inherit Homebrew environment
        var env = ProcessInfo.processInfo.environment
        let homebrewPrefix = brewPath.replacingOccurrences(of: "/bin/brew", with: "")
        env["HOMEBREW_PREFIX"] = homebrewPrefix
        env["PATH"] = "\(homebrewPrefix)/bin:\(homebrewPrefix)/sbin:\(env["PATH"] ?? "/usr/bin:/bin")"
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        // Read pipes BEFORE waitUntilExit to avoid deadlock.
        // If the process writes more than the pipe buffer (64KB on macOS),
        // waitUntilExit() blocks forever because the pipe is full and nobody is draining it.
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return ProcessResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
    }

    func brew(_ arguments: String...) async throws -> ProcessResult {
        try await run(brewPath, arguments: Array(arguments))
    }

    func brewOrThrow(_ arguments: String...) async throws -> String {
        let result = try await run(brewPath, arguments: Array(arguments))
        guard result.exitCode == 0 else {
            throw ProcessError.executionFailed(
                command: "brew \(arguments.joined(separator: " "))",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
        return result.stdout
    }

    func git(_ arguments: String...) async throws -> ProcessResult {
        try await run("/usr/bin/git", arguments: Array(arguments))
    }

    func gitOrThrow(_ arguments: String...) async throws -> String {
        let result = try await run("/usr/bin/git", arguments: Array(arguments))
        guard result.exitCode == 0 else {
            throw ProcessError.executionFailed(
                command: "git \(arguments.joined(separator: " "))",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
        return result.stdout
    }
}
