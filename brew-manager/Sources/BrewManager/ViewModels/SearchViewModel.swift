import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [BrewPackage] = []
    @Published var isSearching = false
    @Published var error: String?

    private let api = BrewAPIService.shared
    private var searchTask: Task<Void, Never>?

    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            return
        }

        // Debounce: cancel previous search
        searchTask?.cancel()

        searchTask = Task {
            isSearching = true
            error = nil
            defer { isSearching = false }

            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce

                guard !Task.isCancelled else { return }

                async let formulae = api.searchFormulae(query: trimmed)
                async let casks = api.searchCasks(query: trimmed)

                let (formulaeResults, caskResults) = try await (formulae, casks)

                guard !Task.isCancelled else { return }

                let formulaePackages = formulaeResults.prefix(25).map { $0.toBrewPackage() }
                let caskPackages = caskResults.prefix(25).map { $0.toBrewPackage() }

                self.results = formulaePackages + caskPackages
            } catch is CancellationError {
                // Expected when debouncing
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func clear() {
        query = ""
        results = []
        searchTask?.cancel()
    }
}
