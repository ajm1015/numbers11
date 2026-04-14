import Foundation
import SwiftUI

@MainActor
final class PackageListViewModel: ObservableObject {
    @Published var installedPackages: [BrewPackage] = []
    @Published var outdatedPackages: [OutdatedResult] = []
    @Published var selectedPackage: BrewPackage?
    @Published var selectedPackages: Set<BrewPackage> = []
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
    /// Bulk uninstall confirmation
    @Published var showBulkUninstallConfirm = false
    @Published var pendingBulkUninstall: [BrewPackage] = []

    // MARK: - Declarative Mode

    @AppStorage("declarativeMode") var declarativeMode = false
    @Published var pendingBrewfile: Brewfile?
    @Published var showApplyConfirm = false

    var pendingChangeCount: Int {
        guard let pending = pendingBrewfile else { return 0 }
        return pending.entries.count
    }

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

    @Published var isCachedData = false

    func loadPackages() async {
        isLoading = true
        error = nil

        // Phase 1: Show cached Brewfile entries instantly
        if installedPackages.isEmpty {
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

        // Phase 2: Load live data
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
            self.isCachedData = false
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        await loadPackages()
    }

    func install(name: String, type: PackageType) async {
        if declarativeMode {
            await declarativeInstall(name: name, type: type)
            return
        }
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
        if declarativeMode {
            await declarativeUninstall(package)
            return
        }
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

    // MARK: - Bulk Operations

    func requestBulkUninstall(_ packages: [BrewPackage]) {
        pendingBulkUninstall = packages.sorted { $0.name < $1.name }
        showBulkUninstallConfirm = true
    }

    func confirmBulkUninstall() async {
        let packages = pendingBulkUninstall
        pendingBulkUninstall = []
        showBulkUninstallConfirm = false
        await bulkUninstall(packages)
    }

    func bulkUninstall(_ packages: [BrewPackage]) async {
        error = nil
        for (index, pkg) in packages.enumerated() {
            activeOperation = "Uninstalling \(index + 1)/\(packages.count): \(pkg.name)..."
            do {
                try await BrewService.shared.uninstall(name: pkg.name, type: pkg.type)
            } catch {
                self.error = "Failed to uninstall \(pkg.name): \(error.localizedDescription)"
                activeOperation = nil
                return
            }
        }
        selectedPackages.removeAll()
        selectedPackage = nil
        activeOperation = "Refreshing package list..."
        await loadPackages()
        activeOperation = nil
        showSuccess("Uninstalled \(packages.count) packages")
        await snapshotBrewfile(message: "Bulk uninstall \(packages.count) packages")
    }

    func bulkUpgrade(_ packages: [BrewPackage]) async {
        error = nil
        for (index, pkg) in packages.enumerated() {
            activeOperation = "Upgrading \(index + 1)/\(packages.count): \(pkg.name)..."
            do {
                try await BrewService.shared.upgrade(name: pkg.name, type: pkg.type)
            } catch {
                self.error = "Failed to upgrade \(pkg.name): \(error.localizedDescription)"
                activeOperation = nil
                return
            }
        }
        activeOperation = "Refreshing package list..."
        await loadPackages()
        activeOperation = nil
        showSuccess("Upgraded \(packages.count) packages")
        await snapshotBrewfile(message: "Bulk upgrade \(packages.count) packages")
    }

    // MARK: - Declarative Mode Actions

    func enableDeclarativeMode() async {
        activeOperation = "Exporting current system state..."
        do {
            let brewfile = try await BrewService.shared.dumpBrewfile()
            try await GitService.shared.writeBrewfile(brewfile, message: "Export system state for declarative mode")
            pendingBrewfile = nil
            activeOperation = nil
            showSuccess("Declarative mode enabled")
        } catch {
            activeOperation = nil
            self.error = "Failed to export Brewfile: \(error.localizedDescription)"
            declarativeMode = false
        }
    }

    func declarativeInstall(name: String, type: PackageType) async {
        do {
            var brewfile = try await GitService.shared.readBrewfile()
            let entryType: BrewfileEntryType = type == .cask ? .cask : .brew
            let newEntry = BrewfileEntry(type: entryType, name: name, options: [])
            guard !brewfile.entries.contains(where: { $0.name == name && $0.type == entryType }) else { return }
            brewfile.entries.append(newEntry)
            pendingBrewfile = brewfile
            showSuccess("Added \(name) to pending changes")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func declarativeUninstall(_ package: BrewPackage) async {
        do {
            var brewfile = try await GitService.shared.readBrewfile()
            let entryType: BrewfileEntryType = package.type == .cask ? .cask : .brew
            brewfile.entries.removeAll { $0.name == package.name && $0.type == entryType }
            pendingBrewfile = brewfile
            showSuccess("Removed \(package.name) from pending changes")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func applyPendingChanges() async {
        guard let pending = pendingBrewfile else { return }
        activeOperation = "Applying Brewfile changes..."
        error = nil

        do {
            try await GitService.shared.writeBrewfile(pending, message: "Declarative mode: apply changes")
            let brewfilePath = await GitService.shared.brewfilePath
            try await BrewService.shared.applyBrewfile(at: brewfilePath)
            pendingBrewfile = nil
            activeOperation = "Refreshing package list..."
            await loadPackages()
            activeOperation = nil
            showSuccess("Brewfile applied successfully")
        } catch {
            activeOperation = nil
            self.error = "Failed to apply Brewfile: \(error.localizedDescription)"
        }
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
