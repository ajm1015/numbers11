import SwiftUI

struct PackageListView: View {
    @EnvironmentObject var vm: PackageListViewModel
    @Environment(\.theme) var theme

    var body: some View {
        HSplitView {
            // Left: package list
            VStack(spacing: 0) {
                toolbar
                Divider().overlay(theme.border)

                if vm.isLoading && vm.installedPackages.isEmpty {
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
            get: { vm.error != nil },
            set: { if !$0 { vm.dismissError() } }
        )) {
            Button("OK") { vm.dismissError() }
        } message: {
            Text(vm.error ?? "")
        }
        .confirmationDialog(
            "Uninstall \(vm.pendingUninstall?.name ?? "")?",
            isPresented: $vm.showUninstallConfirm,
            titleVisibility: .visible
        ) {
            Button("Uninstall", role: .destructive) {
                if let pkg = vm.pendingUninstall {
                    Task { await vm.confirmUninstall(pkg) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove \(vm.pendingUninstall?.name ?? "") from your system.")
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textSecondary)
                TextField("Filter packages...", text: $vm.filterText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.text)
                if !vm.filterText.isEmpty {
                    Button {
                        vm.filterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border, lineWidth: 1))

            Picker("Type", selection: $vm.filterType) {
                ForEach(PackageListViewModel.PackageTypeFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 400)

            Spacer()

            let counts = vm.packageCounts
            HStack(spacing: 16) {
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
            .font(.caption)

            if vm.outdatedPackages.count > 0 {
                Button("Upgrade All") {
                    Task { await vm.upgradeAll() }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .controlSize(.small)
                .disabled(vm.activeOperation != nil)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surface)
    }

    // MARK: - Package List

    private var packageList: some View {
        List(vm.filteredPackages, selection: $vm.selectedPackage) { package in
            PackageRow(package: package)
                .tag(package)
                .listRowBackground(
                    vm.selectedPackage == package
                        ? theme.surfaceHover.opacity(0.8)
                        : Color.clear
                )
                .contextMenu {
                    packageContextMenu(for: package)
                }
        }
        .listStyle(.inset(alternatesRowBackgrounds: false))
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .overlay {
            if vm.filteredPackages.isEmpty && !vm.filterText.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(theme.textSecondary)
                    Text("No results for \"\(vm.filterText)\"")
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .disabled(vm.activeOperation != nil)
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if let selected = vm.selectedPackage {
            PackageDetailView(package: selected)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 40))
                    .foregroundStyle(theme.textSecondary.opacity(0.5))
                Text("Select a package")
                    .font(.headline)
                    .foregroundStyle(theme.textSecondary)
                Text("Choose a package from the list to view details")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Status Bar

    @ViewBuilder
    private var statusBar: some View {
        if let operation = vm.activeOperation {
            Divider().overlay(theme.border)
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                    .tint(theme.accent)
                Text(operation)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(theme.surface)
        } else if let success = vm.successMessage {
            Divider().overlay(theme.border)
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.success)
                Text(success)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(theme.surface)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func packageContextMenu(for package: BrewPackage) -> some View {
        if package.outdated {
            Button("Upgrade") {
                Task { await vm.upgrade(package) }
            }
        }

        if package.type == .formula {
            Button(package.pinned ? "Unpin" : "Pin") {
                Task { await vm.togglePin(package) }
            }
        }

        Divider()

        Button("Uninstall", role: .destructive) {
            vm.requestUninstall(package)
        }
    }
}

// MARK: - Package Row

struct PackageRow: View {
    let package: BrewPackage
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: package.type == .formula ? "terminal" : "macwindow")
                .frame(width: 16)
                .foregroundStyle(package.type == .formula ? theme.formula : theme.cask)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(package.name)
                        .fontWeight(.medium)
                        .foregroundStyle(theme.text)

                    if package.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(theme.warning)
                    }
                }

                if let desc = package.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let version = package.installedVersion {
                    Text(version)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                }

                if package.outdated, let latest = package.latestVersion {
                    Text("\(latest) available")
                        .font(.caption2)
                        .foregroundStyle(theme.warning)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
