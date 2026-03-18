import Foundation

@MainActor
final class VersionHistoryViewModel: ObservableObject {
    @Published var entries: [VersionEntry] = []
    @Published var selectedEntry: VersionEntry?
    @Published var diffContent: String?
    @Published var isLoading = false
    @Published var error: String?

    private let git = GitService.shared

    func loadHistory() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            entries = try await git.log()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadDiff(for entry: VersionEntry) async {
        selectedEntry = entry
        diffContent = nil

        do {
            diffContent = try await git.diffForCommit(hash: entry.id)
        } catch {
            diffContent = "(Unable to load diff)"
        }
    }

    func restoreVersion(_ entry: VersionEntry) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await git.restore(hash: entry.id)
            await loadHistory()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
