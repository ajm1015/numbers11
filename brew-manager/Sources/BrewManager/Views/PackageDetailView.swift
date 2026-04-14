import SwiftUI

struct PackageDetailView: View {
    let package: BrewPackage
    @EnvironmentObject var vm: PackageListViewModel
    @Environment(\.theme) var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Divider().overlay(theme.border)
                versionSection
                if !package.dependencies.isEmpty {
                    Divider().overlay(theme.border)
                    dependencySection
                }
                Divider().overlay(theme.border)
                actionSection
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: package.type == .formula ? "terminal" : "macwindow")
                    .font(.title)
                    .foregroundStyle(package.type == .formula ? theme.formula : theme.cask)

                VStack(alignment: .leading) {
                    Text(package.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(theme.text)

                    HStack(spacing: 8) {
                        Text(package.type.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(theme.border, lineWidth: 1))

                        if package.pinned {
                            Label("Pinned", systemImage: "pin.fill")
                                .font(.caption)
                                .foregroundStyle(theme.warning)
                        }

                        if package.outdated {
                            Label("Update available", systemImage: "arrow.up.circle")
                                .font(.caption)
                                .foregroundStyle(theme.warning)
                        }
                    }
                }
            }

            if let desc = package.description {
                Text(desc)
                    .foregroundStyle(theme.textSecondary)
            }

            if let homepage = package.homepage, let url = URL(string: homepage) {
                Link(destination: url) {
                    Label(homepage, systemImage: "globe")
                        .font(.caption)
                        .foregroundStyle(theme.accent)
                }
            }
        }
    }

    // MARK: - Version

    private var versionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Version")
                .font(.headline)
                .foregroundStyle(theme.text)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                if let installed = package.installedVersion {
                    GridRow {
                        Text("Installed")
                            .foregroundStyle(theme.textSecondary)
                        Text(installed)
                            .monospacedDigit()
                            .foregroundStyle(theme.text)
                    }
                }

                if let latest = package.latestVersion {
                    GridRow {
                        Text("Latest")
                            .foregroundStyle(theme.textSecondary)
                        Text(latest)
                            .monospacedDigit()
                            .foregroundStyle(package.outdated ? theme.warning : theme.text)
                    }
                }
            }
            .font(.callout)
        }
    }

    // MARK: - Dependencies

    private var dependencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dependencies (\(package.dependencies.count))")
                .font(.headline)
                .foregroundStyle(theme.text)

            FlowLayout(spacing: 6) {
                ForEach(package.dependencies, id: \.self) { dep in
                    Text(dep)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.border, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Actions

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Actions")
                .font(.headline)
                .foregroundStyle(theme.text)

            HStack(spacing: 8) {
                if package.outdated {
                    Button {
                        Task { await vm.upgrade(package) }
                    } label: {
                        Label("Upgrade", systemImage: "arrow.up.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .disabled(vm.activeOperation != nil)
                }

                if package.type == .formula {
                    Button {
                        Task { await vm.togglePin(package) }
                    } label: {
                        Label(
                            package.pinned ? "Unpin" : "Pin Version",
                            systemImage: package.pinned ? "pin.slash" : "pin"
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(theme.warning)
                    .disabled(vm.activeOperation != nil)
                }

                Button(role: .destructive) {
                    vm.requestUninstall(package)
                } label: {
                    Label("Uninstall", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(theme.danger)
                .disabled(vm.activeOperation != nil)
            }
        }
    }
}

