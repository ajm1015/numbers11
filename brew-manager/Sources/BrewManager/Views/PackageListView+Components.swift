import SwiftUI

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
