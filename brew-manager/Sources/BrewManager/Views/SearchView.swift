import SwiftUI

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()
    @EnvironmentObject var packageListVM: PackageListViewModel
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().overlay(theme.border)
            resultsList

            if let operation = packageListVM.activeOperation {
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
            } else if let success = packageListVM.successMessage {
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
            }
        }
        .background(theme.background)
        .alert("Error", isPresented: .init(
            get: { packageListVM.error != nil },
            set: { if !$0 { packageListVM.dismissError() } }
        )) {
            Button("OK") { packageListVM.dismissError() }
        } message: {
            Text(packageListVM.error ?? "")
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textSecondary)

            TextField("Search Homebrew packages...", text: $vm.query)
                .textFieldStyle(.plain)
                .foregroundStyle(theme.text)
                .onSubmit { vm.search() }
                .onChange(of: vm.query) { vm.search() }

            if vm.isSearching {
                ProgressView()
                    .controlSize(.small)
                    .tint(theme.accent)
            }

            if !vm.query.isEmpty {
                Button {
                    vm.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(theme.surface)
    }

    // MARK: - Results

    private var resultsList: some View {
        Group {
            if vm.results.isEmpty && !vm.query.isEmpty && !vm.isSearching {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(theme.textSecondary)
                    Text("No packages found matching \"\(vm.query)\"")
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
            } else if vm.results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "shippingbox")
                        .font(.largeTitle)
                        .foregroundStyle(theme.textSecondary.opacity(0.5))
                    Text("Search Homebrew")
                        .font(.headline)
                        .foregroundStyle(theme.textSecondary)
                    Text("Search for formulae and casks to install")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
            } else {
                List(vm.results) { package in
                    SearchResultRow(
                        package: package,
                        isInstalled: packageListVM.installedPackages.contains { $0.name == package.name && $0.type == package.type },
                        isOperating: packageListVM.activeOperation != nil,
                        onInstall: {
                            Task { await packageListVM.install(name: package.name, type: package.type) }
                        }
                    )
                    .listRowBackground(Color.clear)
                }
                .listStyle(.inset(alternatesRowBackgrounds: false))
                .scrollContentBackground(.hidden)
                .background(theme.background)
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let package: BrewPackage
    let isInstalled: Bool
    let isOperating: Bool
    let onInstall: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: package.type == .formula ? "terminal" : "macwindow")
                .frame(width: 16)
                .foregroundStyle(package.type == .formula ? theme.formula : theme.cask)

            VStack(alignment: .leading, spacing: 2) {
                Text(package.name)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.text)

                if let desc = package.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if let version = package.latestVersion {
                Text(version)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(theme.textSecondary)
            }

            if isInstalled {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(theme.success)
            } else {
                Button("Install") { onInstall() }
                    .buttonStyle(.bordered)
                    .tint(theme.accent)
                    .controlSize(.small)
                    .disabled(isOperating)
            }
        }
        .padding(.vertical, 2)
    }
}
