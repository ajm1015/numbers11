import SwiftUI

struct VersionHistoryView: View {
    @StateObject private var vm = VersionHistoryViewModel()
    @Environment(\.theme) var theme
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
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(theme.textSecondary.opacity(0.5))
                    Text("No History")
                        .font(.headline)
                        .foregroundStyle(theme.textSecondary)
                    Text("Package changes will appear here once you start managing packages through BrewManager.")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
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
                    DiffContentView(diff: diff)
                        .padding(12)
                }
                .background(theme.surface)
            } else if vm.selectedEntry != nil {
                ProgressView()
                    .tint(theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.background)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundStyle(theme.textSecondary.opacity(0.5))
                    Text("Select a commit")
                        .font(.headline)
                        .foregroundStyle(theme.textSecondary)
                    Text("Choose a commit to view the Brewfile diff")
                        .font(.caption)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(diff.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(colorForLine(line))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
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

// MARK: - Commit Row

struct CommitRow: View {
    let entry: VersionEntry
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.message)
                .fontWeight(.medium)
                .foregroundStyle(theme.text)
                .lineLimit(2)

            HStack(spacing: 8) {
                Text(entry.shortHash)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(theme.accent)

                Text(entry.date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)

                if !entry.addedPackages.isEmpty {
                    Label("+\(entry.addedPackages.count)", systemImage: "plus.circle")
                        .font(.caption2)
                        .foregroundStyle(theme.success)
                }

                if !entry.removedPackages.isEmpty {
                    Label("-\(entry.removedPackages.count)", systemImage: "minus.circle")
                        .font(.caption2)
                        .foregroundStyle(theme.danger)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
