import SwiftUI
import AppKit

@main
struct BrewManagerApp: App {
    @StateObject private var packageListVM = PackageListViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @AppStorage("uiScale") private var uiScale: Double = 1.0
    @State private var brewAvailable = true

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if brewAvailable {
                    ContentView()
                } else {
                    BrewSetupView {
                        brewAvailable = ProcessRunner.isBrewAvailable
                    }
                }
            }
            .task {
                brewAvailable = ProcessRunner.isBrewAvailable
            }
            .environmentObject(packageListVM)
            .environmentObject(themeManager)
            .environment(\.theme, themeManager.colors)
            .background(themeManager.colors.background)
            .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1100, height: 750)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Packages") {
                Button("Refresh") {
                    Task { await packageListVM.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Export Brewfile...") {
                    Task { await packageListVM.exportBrewfile() }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Import Brewfile...") {
                    importBrewfile()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }

            CommandMenu("Theme") {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        themeManager.current = theme
                    } label: {
                        HStack {
                            Text(theme.rawValue)
                            if themeManager.current == theme {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            CommandGroup(after: .windowSize) {
                Button("Zoom In") {
                    uiScale = min(1.5, uiScale + 0.05)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    uiScale = max(0.75, uiScale - 0.05)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Zoom") {
                    uiScale = 1.0
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }

    private func importBrewfile() {
        let panel = NSOpenPanel()
        panel.title = "Import Brewfile"
        panel.allowedContentTypes = [.plainText, .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.nameFieldStringValue = "Brewfile"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await packageListVM.importBrewfile(from: url.path)
            }
        }
    }
}
