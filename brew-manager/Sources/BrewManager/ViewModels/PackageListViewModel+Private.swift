import Foundation

@MainActor
extension PackageListViewModel {
    func loadCachedPackages() async {
        guard installedPackages.isEmpty else { return }
        do {
            let brewfile = try await GitService.shared.readBrewfile()
            let cached = brewfile.entries.compactMap { entry -> BrewPackage? in
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
            if !cached.isEmpty {
                self.installedPackages = cached
                self.isCachedData = true
            }
        } catch {
            // No Brewfile yet -- fall through to spinner
        }
    }

    func showSuccess(_ message: String) {
        successGeneration &+= 1
        let expectedGeneration = successGeneration
        successMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if successGeneration == expectedGeneration {
                successMessage = nil
            }
        }
    }

    func snapshotBrewfile(message: String) async {
        do {
            let brewfile = try await BrewService.shared.dumpBrewfile()
            try await GitService.shared.writeBrewfile(brewfile, message: message)
        } catch {
            print("Brewfile snapshot failed: \(error)")
        }
    }
}
