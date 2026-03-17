import Foundation
import SwiftUI

@MainActor
final class PackageListViewModel: ObservableObject {
    @Published var installedPackages: [BrewPackage] = []
    @Published var outdatedPackages: [OutdatedResult] = []
    @Published var selectedPackage: BrewPackage?
    @Published var filterText = ""
    @Published var filterType: PackageTypeFilter = .all
    @Published var isLoading = false
    @Published var error: String?

    /// Tracks in-flight operations — shown as a status bar overlay
    @Published var activeOperation: String?
    /// Set when an operation completes successfully
    @Published var successMessage: String?
    private var successGeneration: UInt64 = 0
    /// Confirmation dialog state for uninstall
    @Published var showUninstallConfirm = false
    @Published var pendingUninstall: BrewPackage?

    enum PackageTypeFilter: String, CaseIterable {
        case all = "All"
        case formulae = "Formulae"
        case casks = "Casks"
        case outdated = "Outdated"
        case pinned = "Pinned"
    }

    var filteredPackages: [BrewPackage] {
        var result = installedPackages

        switch filterType {
        case .all: break
        case .formulae: result = result.filter { $0.type == .formula }
        case .casks: result = result.filter { $0.type == .cask }
        case .outdated: result = result.filter { $0.outdated }
        case .pinned: result = result.filter { $0.pinned }
        }

        if !filterText.isEmpty {
            let query = filterText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query)
                || ($0.description?.lowercased().contains(query) ?? false)
            }
        }

        return result.sorted { $0.name < $1.name }
    }

    var packageCounts: (formulae: Int, casks: Int, outdated: Int) {
        let formulae = installedPackages.filter { $0.type == .formula }.count
        let casks = installedPackages.filter { $0.type == .cask }.count
        let outdated = installedPackages.filter { $0.outdated }.count
        return (formulae, casks, outdated)
    }

    // MARK: - Actions

    func loadPackages() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let installed = BrewService.shared.listInstalled()
            async let outdated = BrewService.shared.listOutdated()

            let (installedResult, outdatedResult) = try await (installed, outdated)

            var outdatedMap: [String: OutdatedResult] = [:]
            for o in outdatedResult {
                outdatedMap[o.name] = o
            }

            self.installedPackages = installedResult.map { pkg in
                if let outdated = outdatedMap[pkg.name] {
                    return BrewPackage(
                        name: pkg.name,
                        type: pkg.type,
                        installedVersion: pkg.installedVersion,
                        latestVersion: outdated.latestVersion,
                        description: pkg.description,
                        homepage: pkg.homepage,
                        pinned: pkg.pinned,
                        outdated: true,
                        dependencies: pkg.dependencies
                    )
                }
                return pkg
            }
            self.outdatedPackages = outdatedResult
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() async {
        await loadPackages()
    }

    func install(name: String, type: PackageType) async {
        activeOperation = "Installing \(name)..."
        error = nil

        do {
            try await BrewService.shared.install(name: name, type: type)
            activeOperation = "Refreshing package list..."
            await loadPackages()
            activeOperation = nil
            showSuccess("Installed \(name)")
            await snapshotBrewfile(message: "Install \(name)")
        } catch {
            activeOperation = nil
            self.error = "Failed to install \(name): \(error.localizedDescription)"
        }
    }

    func uninstall(_ package: BrewPackage) async {
        activeOperation = "Uninstalling \(package.name)..."
        error = nil

        do {
            try await BrewService.shared.uninstall(name: package.name, type: package.type)
            if selectedPackage?.id == package.id {
                selectedPackage = nil
            }
            activeOperation = "Refreshing package list..."
            await loadPackages()
            activeOperation = nil
            showSuccess("Uninstalled \(package.name)")
            await snapshotBrewfile(message: "Uninstall \(package.name)")
        } catch {
            activeOperation = nil
            self.error = "Failed to uninstall \(package.name): \(error.localizedDescription)"
        }
    }

    func upgrade(_ package: BrewPackage) async {
        activeOperation = "Upgrading \(package.name)..."
        error = nil

        do {
            try await BrewService.shared.upgrade(name: package.name, type: package.type)
            activeOperation = "Refreshing package list..."
            await loadPackages()
            activeOperation = nil
            showSuccess("Upgraded \(package.name)")
            await snapshotBrewfile(message: "Upgrade \(package.name)")
        } catch {
            activeOperation = nil
            self.error = "Failed to upgrade \(package.name): \(error.localizedDescription)"
        }
    }

    func upgradeAll() async {
        activeOperation = "Upgrading all packages..."
        error = nil

        do {
            try await BrewService.shared.upgradeAll()
            activeOperation = "Refreshing package list..."
            await loadPackages()
            activeOperation = nil
            showSuccess("All packages upgraded")
            await snapshotBrewfile(message: "Upgrade all packages")
        } catch {
            activeOperation = nil
            self.error = "Failed to upgrade: \(error.localizedDescription)"
        }
    }

    func togglePin(_ package: BrewPackage) async {
        let action = package.pinned ? "Unpinning" : "Pinning"
        activeOperation = "\(action) \(package.name)..."

        do {
            if package.pinned {
                try await BrewService.shared.unpin(name: package.name)
            } else {
                try await BrewService.shared.pin(name: package.name)
            }
            await loadPackages()
            activeOperation = nil
            showSuccess("\(package.pinned ? "Unpinned" : "Pinned") \(package.name)")
        } catch {
            activeOperation = nil
            self.error = error.localizedDescription
        }
    }

    func exportBrewfile() async {
        activeOperation = "Exporting Brewfile..."

        do {
            let brewfile = try await BrewService.shared.dumpBrewfile()
            try await GitService.shared.writeBrewfile(brewfile, message: "Export current system state")
            activeOperation = nil
            showSuccess("Brewfile exported and committed")
        } catch {
            activeOperation = nil
            self.error = error.localizedDescription
        }
    }

    func requestUninstall(_ package: BrewPackage) {
        pendingUninstall = package
        showUninstallConfirm = true
    }

    func confirmUninstall(_ package: BrewPackage) async {
        pendingUninstall = nil
        showUninstallConfirm = false
        await uninstall(package)
    }

    func importBrewfile(from path: String) async {
        activeOperation = "Installing from Brewfile..."
        error = nil

        do {
            try await BrewService.shared.installFromBrewfile(at: path)
            activeOperation = "Refreshing package list..."
            await loadPackages()
            activeOperation = nil
            showSuccess("Installed packages from Brewfile")
            await snapshotBrewfile(message: "Import Brewfile from \(URL(fileURLWithPath: path).lastPathComponent)")
        } catch {
            activeOperation = nil
            self.error = "Failed to import Brewfile: \(error.localizedDescription)"
        }
    }

    func dismissError() {
        error = nil
    }

    // MARK: - Private

    private func showSuccess(_ message: String) {
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

    private func snapshotBrewfile(message: String) async {
        do {
            let brewfile = try await BrewService.shared.dumpBrewfile()
            try await GitService.shared.writeBrewfile(brewfile, message: message)
        } catch {
            print("Brewfile snapshot failed: \(error)")
        }
    }
}
