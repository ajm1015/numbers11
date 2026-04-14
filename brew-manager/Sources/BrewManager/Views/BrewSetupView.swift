import SwiftUI

struct BrewSetupView: View {
    @Environment(\.theme) var theme
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.warning)

            Text("Homebrew Not Found")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(theme.text)

            Text("BrewManager requires Homebrew to manage packages.")
                .foregroundStyle(theme.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Searched paths:")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                ForEach(ProcessRunner.brewSearchPaths, id: \.self) { path in
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(theme.danger)
                            .font(.caption)
                        Text(path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(theme.text)
                    }
                }
            }
            .padding(12)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))

            Link(destination: URL(string: "https://brew.sh")!) {
                Label("Install Homebrew", systemImage: "globe")
                    .foregroundStyle(theme.accent)
            }

            Button("Retry") { onRetry() }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }
}
