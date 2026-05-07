import SwiftUI

struct PackageListView: View {
    @EnvironmentObject var viewModel: PackageListViewModel
    @Environment(\.theme) var theme
    @Environment(\.uiScale) var uiScale
    @FocusState private var filterFocused: Bool

    var body: some View {
        HSplitView {
            // Left: package list
            VStack(spacing: 0) {
                toolbar
                Divider().overlay(theme.border)

                if viewModel.isLoading && viewModel.installedPackages.isEmpty {
                    ProgressView("Loading packages...")
                        .tint(theme.accent)
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(theme.background)
                } else {
                    packageList
                }

                statusBar
            }
            .frame(minWidth: 350)
            .background(theme.background)

            // Right: detail pane
            detailPane
                .frame(minWidth: 280)
                .background(theme.background)
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.error ?? "")
        }
        .background {
            Button("") { filterFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        }
        .confirmationDialog(
            "Uninstall \(viewModel.pendingUninstall?.name ?? "")?",
            isPresented: $viewModel.showUninstallConfirm,
            titleVisibility: .visible
        ) {
            Button("Uninstall", role: .destructive) {
                if let pkg = viewModel.pendingUninstall {
                    Task { await viewModel.confirmUninstall(pkg) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove \(viewModel.pendingUninstall?.name ?? "") from your system.")
        }
        .confirmationDialog(
            "Apply Brewfile Changes?",
            isPresented: $viewModel.showApplyConfirm,
            titleVisibility: .visible
        ) {
            Button("Apply") {
                Task { await viewModel.applyPendingChanges() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will converge your system to match the Brewfile. Packages not in the Brewfile will be removed.")
        }
        .confirmationDialog(
            "Uninstall \(viewModel.pendingBulkUninstall.count) packages?",
            isPresented: $viewModel.showBulkUninstallConfirm,
            titleVisibility: .visible
        ) {
            Button("Uninstall All", role: .destructive) {
                Task { await viewModel.confirmBulkUninstall() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove: \(viewModel.pendingBulkUninstall.map(\.name).sorted().joined(separator: ", "))")
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12 * uiScale) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textSecondary)
                TextField("Filter packages...", text: $viewModel.filterText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.text)
                    .focused($filterFocused)
                if !viewModel.filterText.isEmpty {
                    Button {
                        viewModel.filterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6 * uiScale)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border, lineWidth: 1))

            Picker("Type", selection: $viewModel.filterType) {
                ForEach(PackageListViewModel.PackageTypeFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 400)

            Spacer()

            let counts = viewModel.packageCounts
            HStack(spacing: 16 * uiScale) {
                Label("\(counts.formulae)", systemImage: "terminal")
                    .foregroundStyle(theme.textSecondary)
                    .help("Formulae")
                Label("\(counts.casks)", systemImage: "macwindow")
                    .foregroundStyle(theme.textSecondary)
                    .help("Casks")
                if counts.outdated > 0 {
                    Label("\(counts.outdated)", systemImage: "arrow.up.circle")
                        .foregroundStyle(theme.warning)
                        .help("Outdated")
                }
            }
            .font(.scaled(.caption, scale: uiScale))

            if viewModel.outdatedPackages.count > 0 {
                Button("Upgrade All") {
                    Task { await viewModel.upgradeAll() }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .controlSize(.small)
                .disabled(viewModel.activeOperation != nil)
            }
        }
        .padding(.horizontal, 12 * uiScale)
        .padding(.vertical, 8 * uiScale)
        .background(theme.surface)
    }

    // MARK: - Package List

    private var packageList: some View {
        List(viewModel.filteredPackages, selection: $viewModel.selectedPackages) { package in
            PackageRow(package: package, isCached: viewModel.isCachedData)
                .tag(package)
                .listRowBackground(
                    viewModel.selectedPackages.contains(package)
                        ? theme.surfaceHover.opacity(0.8)
                        : Color.clear
                )
                .contextMenu {
                    packageContextMenu(for: package)
                }
        }
        .onChange(of: viewModel.selectedPackages) { oldValue, newValue in
            let added = newValue.subtracting(oldValue)
            viewModel.selectedPackage = added.first ?? newValue.first
        }
        .listStyle(.inset(alternatesRowBackgrounds: false))
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .overlay {
            if viewModel.filteredPackages.isEmpty && !viewModel.filterText.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(theme.textSecondary)
                    Text("No results for \"\(viewModel.filterText)\"")
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .disabled(viewModel.activeOperation != nil)
        .onKeyPress(.escape) {
            if !viewModel.filterText.isEmpty {
                viewModel.filterText = ""
                return .handled
            } else if viewModel.selectedPackage != nil {
                viewModel.selectedPackage = nil
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.delete) {
            if let pkg = viewModel.selectedPackage {
                viewModel.requestUninstall(pkg)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            if viewModel.selectedPackage != nil {
                // Package already shown in detail pane
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if viewModel.selectedPackages.count > 1 {
            BulkActionsView(packages: Array(viewModel.selectedPackages))
        } else if let selected = viewModel.selectedPackage {
            PackageDetailView(package: selected)
        } else {
            VStack(spacing: 12 * uiScale) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 40 * uiScale))
                    .foregroundStyle(theme.textSecondary.opacity(0.5))
                Text("Select a package")
                    .font(.scaled(.headline, scale: uiScale))
                    .foregroundStyle(theme.textSecondary)
                Text("Choose a package from the list to view details")
                    .font(.scaled(.caption, scale: uiScale))
                    .foregroundStyle(theme.textSecondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Status Bar

    @ViewBuilder
    private var statusBar: some View {
        if viewModel.declarativeMode && viewModel.pendingBrewfile != nil {
            Divider().overlay(theme.border)
            HStack(spacing: 8 * uiScale) {
                Image(systemName: "doc.badge.gearshape")
                    .foregroundStyle(theme.warning)
                Text("Pending changes")
                    .font(.scaled(.caption, scale: uiScale))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button("Apply Changes") {
                    viewModel.showApplyConfirm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .controlSize(.small)
                .disabled(viewModel.activeOperation != nil)
            }
            .padding(.horizontal, 12 * uiScale)
            .padding(.vertical, 6 * uiScale)
            .background(theme.surface)
        } else if let operation = viewModel.activeOperation {
            Divider().overlay(theme.border)
            HStack(spacing: 8 * uiScale) {
                ProgressView()
                    .controlSize(.small)
                    .tint(theme.accent)
                Text(operation)
                    .font(.scaled(.caption, scale: uiScale))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 12 * uiScale)
            .padding(.vertical, 6 * uiScale)
            .background(theme.surface)
        } else if let success = viewModel.successMessage {
            Divider().overlay(theme.border)
            HStack(spacing: 6 * uiScale) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.success)
                Text(success)
                    .font(.scaled(.caption, scale: uiScale))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 12 * uiScale)
            .padding(.vertical, 6 * uiScale)
            .background(theme.surface)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func packageContextMenu(for package: BrewPackage) -> some View {
        if package.outdated {
            Button("Upgrade") {
                Task { await viewModel.upgrade(package) }
            }
        }

        if package.type == .formula {
            Button(package.pinned ? "Unpin" : "Pin") {
                Task { await viewModel.togglePin(package) }
            }
        }

        Divider()

        Button("Uninstall", role: .destructive) {
            viewModel.requestUninstall(package)
        }
    }
}

// MARK: - Package Row

struct PackageRow: View {
    let package: BrewPackage
    var isCached = false
    @Environment(\.theme) var theme
    @Environment(\.uiScale) var uiScale

    var body: some View {
        HStack(spacing: 8 * uiScale) {
            Image(systemName: package.type == .formula ? "terminal" : "macwindow")
                .frame(width: 16 * uiScale)
                .foregroundStyle(package.type == .formula ? theme.formula : theme.cask)

            VStack(alignment: .leading, spacing: 2 * uiScale) {
                HStack(spacing: 6 * uiScale) {
                    Text(package.name)
                        .font(.scaled(.body, scale: uiScale))
                        .fontWeight(.medium)
                        .foregroundStyle(theme.text)

                    if package.pinned {
                        Image(systemName: "pin.fill")
                            .font(.scaled(.caption2, scale: uiScale))
                            .foregroundStyle(theme.warning)
                    }
                }

                if let desc = package.description {
                    Text(desc)
                        .font(.scaled(.caption, scale: uiScale))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2 * uiScale) {
                if let version = package.installedVersion {
                    Text(version)
                        .font(.scaled(.caption, scale: uiScale))
                        .monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                } else if isCached {
                    Text("cached")
                        .font(.scaled(.caption2, scale: uiScale))
                        .foregroundStyle(theme.textSecondary.opacity(0.6))
                        .padding(.horizontal, 4 * uiScale)
                        .padding(.vertical, 1 * uiScale)
                        .background(theme.surface)
                        .clipShape(Capsule())
                }

                if package.outdated, let latest = package.latestVersion {
                    Text("\(latest) available")
                        .font(.scaled(.caption2, scale: uiScale))
                        .foregroundStyle(theme.warning)
                }
            }
        }
        .padding(.vertical, 2 * uiScale)
    }
}

// MARK: - Bulk Actions View

struct BulkActionsView: View {
    let packages: [BrewPackage]
    @EnvironmentObject var viewModel: PackageListViewModel
    @Environment(\.theme) var theme
    @Environment(\.uiScale) var uiScale

    var body: some View {
        VStack(spacing: 20 * uiScale) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 40 * uiScale))
                .foregroundStyle(theme.accent)

            Text("\(packages.count) packages selected")
                .font(.scaled(.title2, scale: uiScale))
                .fontWeight(.bold)
                .foregroundStyle(theme.text)

            let outdated = packages.filter { $0.outdated }

            HStack(spacing: 12 * uiScale) {
                if !outdated.isEmpty {
                    Button {
                        Task { await viewModel.bulkUpgrade(outdated) }
                    } label: {
                        Label("Upgrade Selected (\(outdated.count))", systemImage: "arrow.up.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .disabled(viewModel.activeOperation != nil)
                }

                Button(role: .destructive) {
                    viewModel.requestBulkUninstall(packages)
                } label: {
                    Label("Uninstall Selected", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(theme.danger)
                .disabled(viewModel.activeOperation != nil)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }
}
