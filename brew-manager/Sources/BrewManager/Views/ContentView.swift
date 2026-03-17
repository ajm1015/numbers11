import SwiftUI

struct ContentView: View {
    @EnvironmentObject var packageListVM: PackageListViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.theme) var theme
    @State private var selectedTab: SidebarTab = .installed
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    enum SidebarTab: String, CaseIterable {
        case installed = "Installed"
        case search = "Search"
        case history = "History"
        case settings = "Appearance"

        var icon: String {
            switch self {
            case .installed: return "shippingbox.fill"
            case .search: return "magnifyingglass"
            case .history: return "clock.arrow.circlepath"
            case .settings: return "paintpalette.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 600, minHeight: 400)
        .task {
            await packageListVM.loadPackages()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(SidebarTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .foregroundStyle(selectedTab == tab ? theme.accent : theme.textSecondary)
                    .badge(badgeCount(for: tab))
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Spacer()

            // Compact theme switcher at bottom of sidebar
            VStack(spacing: 6) {
                Divider()
                HStack(spacing: 4) {
                    ForEach(AppTheme.allCases) { t in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                themeManager.current = t
                            }
                        } label: {
                            Circle()
                                .fill(t.colors.accent)
                                .frame(width: 14, height: 14)
                                .overlay {
                                    if themeManager.current == t {
                                        Circle().stroke(theme.text, lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .help(t.rawValue)
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 12)
        }
        .background(theme.sidebar)
        .navigationTitle("BrewManager")
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await packageListVM.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(theme.accent)
                }
                .disabled(packageListVM.isLoading)
                .help("Refresh packages (Cmd+R)")
            }
        }
    }

    private func badgeCount(for tab: SidebarTab) -> Int {
        switch tab {
        case .installed: return packageListVM.installedPackages.count
        case .search: return 0
        case .history: return 0
        case .settings: return 0
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        Group {
            switch selectedTab {
            case .installed:
                PackageListView()
            case .search:
                SearchView()
            case .history:
                VersionHistoryView()
            case .settings:
                ThemeSettingsView()
            }
        }
        .background(theme.background)
    }
}

// MARK: - Theme Settings View

struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.theme) var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Appearance")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(theme.text)

                Text("Choose a theme for BrewManager")
                    .foregroundStyle(theme.textSecondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 16)], spacing: 16) {
                    ForEach(AppTheme.allCases) { t in
                        ThemeCard(
                            theme: t,
                            isSelected: themeManager.current == t,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    themeManager.current = t
                                }
                            }
                        )
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }
}

struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // Preview
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.colors.formula)
                            .frame(width: 40, height: 8)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.colors.textSecondary)
                            .frame(height: 8)
                        Spacer()
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.colors.accent)
                            .frame(width: 30, height: 8)
                    }
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.colors.cask)
                            .frame(width: 40, height: 8)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.colors.textSecondary)
                            .frame(height: 8)
                        Spacer()
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.colors.success)
                            .frame(width: 30, height: 8)
                    }
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.colors.formula)
                            .frame(width: 40, height: 8)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.colors.textSecondary)
                            .frame(height: 8)
                        Spacer()
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.colors.warning)
                            .frame(width: 30, height: 8)
                    }
                }
                .padding(12)
                .background(theme.colors.surface)

                // Label
                HStack {
                    Text(theme.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(theme.colors.text)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.colors.accent)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.colors.background)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? theme.colors.accent : theme.colors.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
