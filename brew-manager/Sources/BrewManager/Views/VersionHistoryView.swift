import SwiftUI

struct VersionHistoryView: View {
    @StateObject private var vm = VersionHistoryViewModel()
    @Environment(\.theme) var theme
    @Environment(\.uiScale) var uiScale
    @State private var pendingRestore: VersionEntry?

    var body: some View {
        HSplitView {
            commitList
                .frame(minWidth: 280)

            diffView
                .frame(minWidth: 280)
        }
        .background(theme.background)
        .task {
            await vm.loadHistory()
        }
        .confirmationDialog(
            "Restore Brewfile?",
            isPresented: .init(
                get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Restore", role: .destructive) {
                if let entry = pendingRestore {
                    Task { await vm.restoreVersion(entry) }
                }
                pendingRestore = nil
            }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
            Text("This will revert your Brewfile to commit \(pendingRestore?.shortHash ?? ""). Your current Brewfile will be replaced.")
        }
    }

    // MARK: - Commit List

    private var commitList: some View {
        Group {
            if vm.isLoading && vm.entries.isEmpty {
                VStack {
                    ProgressView("Loading history...")
                        .tint(theme.accent)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
            } else if vm.entries.isEmpty {
                VStack(spacing: 12 * uiScale) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40 * uiScale))
                        .foregroundStyle(theme.textSecondary.opacity(0.5))
                    Text("No History")
                        .font(.scaled(.headline, scale: uiScale))
                        .foregroundStyle(theme.textSecondary)
                    Text("Package changes will appear here once you start managing packages through BrewManager.")
                        .font(.scaled(.caption, scale: uiScale))
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20 * uiScale)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
            } else {
                List(vm.entries, selection: Binding(
                    get: { vm.selectedEntry },
                    set: { entry in
                        if let entry {
                            Task { await vm.loadDiff(for: entry) }
                        }
                    }
                )) { entry in
                    CommitRow(entry: entry)
                        .tag(entry.id)
                        .listRowBackground(
                            vm.selectedEntry?.id == entry.id
                                ? theme.surfaceHover.opacity(0.8)
                                : Color.clear
                        )
                        .contextMenu {
                            Button("Restore to this version") {
                                pendingRestore = entry
                            }
                        }
                }
                .listStyle(.inset(alternatesRowBackgrounds: false))
                .scrollContentBackground(.hidden)
                .background(theme.background)
            }
        }
    }

    // MARK: - Diff View

    private var diffView: some View {
        Group {
            if let diff = vm.diffContent {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12 * uiScale) {
                        if let entry = vm.selectedEntry {
                            DiffSummaryCard(entry: entry)
                        }
                        DisclosureGroup("Show raw diff") {
                            DiffContentView(diff: diff)
                        }
                        .foregroundStyle(theme.textSecondary)
                        .font(.scaled(.caption, scale: uiScale))
                    }
                    .padding(12 * uiScale)
                }
                .background(theme.surface)
            } else if vm.selectedEntry != nil {
                ProgressView()
                    .tint(theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.background)
            } else {
                VStack(spacing: 8 * uiScale) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40 * uiScale))
                        .foregroundStyle(theme.textSecondary.opacity(0.5))
                    Text("Select a commit")
                        .font(.scaled(.headline, scale: uiScale))
                        .foregroundStyle(theme.textSecondary)
                    Text("Choose a commit to view the Brewfile diff")
                        .font(.scaled(.caption, scale: uiScale))
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
            }
        }
    }
}

// MARK: - Diff Content View (syntax colored)

struct DiffContentView: View {
    let diff: String
    @Environment(\.theme) var theme
    @Environment(\.uiScale) var uiScale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(diff.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.scaled(.caption, scale: uiScale, design: .monospaced))
                    .foregroundStyle(colorForLine(line))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4 * uiScale)
                    .padding(.vertical, 1 * uiScale)
                    .background(backgroundForLine(line))
            }
        }
    }

    private func colorForLine(_ line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            return theme.success
        } else if line.hasPrefix("-") && !line.hasPrefix("---") {
            return theme.danger
        } else if line.hasPrefix("@@") {
            return theme.accent
        } else if line.hasPrefix("diff") || line.hasPrefix("index") {
            return theme.textSecondary
        }
        return theme.text
    }

    private func backgroundForLine(_ line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            return theme.success.opacity(0.1)
        } else if line.hasPrefix("-") && !line.hasPrefix("---") {
            return theme.danger.opacity(0.1)
        }
        return .clear
    }
}

// MARK: - Diff Summary Card

struct DiffSummaryCard: View {
    let entry: VersionEntry
    @Environment(\.theme) var theme
    @Environment(\.uiScale) var uiScale

    var body: some View {
        VStack(alignment: .leading, spacing: 10 * uiScale) {
            if entry.addedPackages.isEmpty && entry.removedPackages.isEmpty {
                Text("Initial Brewfile")
                    .font(.scaled(.callout, scale: uiScale))
                    .foregroundStyle(theme.textSecondary)
            } else {
                HStack(spacing: 8 * uiScale) {
                    if !entry.addedPackages.isEmpty {
                        Text("+\(entry.addedPackages.count)")
                            .font(.scaled(.caption, scale: uiScale))
                            .fontWeight(.semibold)
                            .foregroundStyle(theme.success)
                    }
                    if !entry.removedPackages.isEmpty {
                        Text("-\(entry.removedPackages.count)")
                            .font(.scaled(.caption, scale: uiScale))
                            .fontWeight(.semibold)
                            .foregroundStyle(theme.danger)
                    }
                }

                if !entry.addedPackages.isEmpty {
                    VStack(alignment: .leading, spacing: 4 * uiScale) {
                        Text("Added")
                            .font(.scaled(.caption2, scale: uiScale))
                            .foregroundStyle(theme.success)
                        FlowLayout(spacing: 6 * uiScale) {
                            ForEach(entry.addedPackages, id: \.self) { name in
                                Text(name)
                                    .font(.scaled(.caption, scale: uiScale))
                                    .foregroundStyle(theme.success)
                                    .padding(.horizontal, 8 * uiScale)
                                    .padding(.vertical, 3 * uiScale)
                                    .background(theme.success.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }

                if !entry.removedPackages.isEmpty {
                    VStack(alignment: .leading, spacing: 4 * uiScale) {
                        Text("Removed")
                            .font(.scaled(.caption2, scale: uiScale))
                            .foregroundStyle(theme.danger)
                        FlowLayout(spacing: 6 * uiScale) {
                            ForEach(entry.removedPackages, id: \.self) { name in
                                Text(name)
                                    .font(.scaled(.caption, scale: uiScale))
                                    .foregroundStyle(theme.danger)
                                    .padding(.horizontal, 8 * uiScale)
                                    .padding(.vertical, 3 * uiScale)
                                    .background(theme.danger.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
            }
        }
        .padding(12 * uiScale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
    }
}

// MARK: - Commit Row

struct CommitRow: View {
    let entry: VersionEntry
    @Environment(\.theme) var theme
    @Environment(\.uiScale) var uiScale

    var body: some View {
        VStack(alignment: .leading, spacing: 4 * uiScale) {
            Text(entry.message)
                .font(.scaled(.body, scale: uiScale))
                .fontWeight(.medium)
                .foregroundStyle(theme.text)
                .lineLimit(2)

            HStack(spacing: 8 * uiScale) {
                Text(entry.shortHash)
                    .font(.scaled(.caption, scale: uiScale, design: .monospaced))
                    .foregroundStyle(theme.accent)

                Text(entry.date, style: .relative)
                    .font(.scaled(.caption, scale: uiScale))
                    .foregroundStyle(theme.textSecondary)

                if !entry.addedPackages.isEmpty {
                    Label("+\(entry.addedPackages.count)", systemImage: "plus.circle")
                        .font(.scaled(.caption2, scale: uiScale))
                        .foregroundStyle(theme.success)
                }

                if !entry.removedPackages.isEmpty {
                    Label("-\(entry.removedPackages.count)", systemImage: "minus.circle")
                        .font(.scaled(.caption2, scale: uiScale))
                        .foregroundStyle(theme.danger)
                }
            }
        }
        .padding(.vertical, 4 * uiScale)
    }
}
