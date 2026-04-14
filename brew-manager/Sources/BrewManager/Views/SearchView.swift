import SwiftUI

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()
    @EnvironmentObject var packageListVM: PackageListViewModel
    @Environment(\.theme) var theme
    @Environment(\.uiScale) var uiScale

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().overlay(theme.border)
            resultsList

            if let operation = packageListVM.activeOperation {
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
            } else if let success = packageListVM.successMessage {
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
            }
        }
        .background(theme.background)
        .onKeyPress(.escape) {
            if !vm.query.isEmpty {
                vm.clear()
                return .handled
            }
            return .ignored
        }
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
        HStack(spacing: 8 * uiScale) {
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
        .padding(10 * uiScale)
        .background(theme.surface)
    }

    // MARK: - Results

    private var resultsList: some View {
        Group {
            if vm.results.isEmpty && !vm.query.isEmpty && !vm.isSearching {
                VStack(spacing: 8 * uiScale) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 26 * uiScale))
                        .foregroundStyle(theme.textSecondary)
                    Text("No packages found matching \"\(vm.query)\"")
                        .font(.scaled(.body, scale: uiScale))
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
            } else if vm.results.isEmpty {
                VStack(spacing: 8 * uiScale) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 26 * uiScale))
                        .foregroundStyle(theme.textSecondary.opacity(0.5))
                    Text("Search Homebrew")
                        .font(.scaled(.headline, scale: uiScale))
                        .foregroundStyle(theme.textSecondary)
                    Text("Search for formulae and casks to install")
                        .font(.scaled(.caption, scale: uiScale))
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
    @Environment(\.uiScale) var uiScale

    var body: some View {
        HStack(spacing: 8 * uiScale) {
            Image(systemName: package.type == .formula ? "terminal" : "macwindow")
                .frame(width: 16 * uiScale)
                .foregroundStyle(package.type == .formula ? theme.formula : theme.cask)

            VStack(alignment: .leading, spacing: 2 * uiScale) {
                Text(package.name)
                    .font(.scaled(.body, scale: uiScale))
                    .fontWeight(.medium)
                    .foregroundStyle(theme.text)

                if let desc = package.description {
                    Text(desc)
                        .font(.scaled(.caption, scale: uiScale))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if let version = package.latestVersion {
                Text(version)
                    .font(.scaled(.caption, scale: uiScale))
                    .monospacedDigit()
                    .foregroundStyle(theme.textSecondary)
            }

            if isInstalled {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .font(.scaled(.caption, scale: uiScale))
                    .foregroundStyle(theme.success)
            } else {
                Button("Install") { onInstall() }
                    .buttonStyle(.bordered)
                    .tint(theme.accent)
                    .controlSize(.small)
                    .disabled(isOperating)
            }
        }
        .padding(.vertical, 2 * uiScale)
    }
}
