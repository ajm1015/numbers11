import SwiftUI
import AppKit

@main
struct BrewManagerApp: App {
    @StateObject private var packageListVM = PackageListViewModel()
    @StateObject private var themeManager = ThemeManager.shared

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
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
                    adjustScale(by: 0.1)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    adjustScale(by: -0.1)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Zoom") {
                    resetScale()
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

    private func adjustScale(by delta: CGFloat) {
        guard let window = NSApp.keyWindow else { return }
        let currentFrame = window.frame
        let newWidth = max(600, currentFrame.width + (currentFrame.width * delta))
        let newHeight = max(400, currentFrame.height + (currentFrame.height * delta))
        let newFrame = NSRect(
            x: currentFrame.origin.x - (newWidth - currentFrame.width) / 2,
            y: currentFrame.origin.y - (newHeight - currentFrame.height) / 2,
            width: newWidth,
            height: newHeight
        )
        window.setFrame(newFrame, display: true, animate: true)
    }

    private func resetScale() {
        guard let window = NSApp.keyWindow else { return }
        let screen = window.screen ?? NSScreen.main!
        let newWidth: CGFloat = 1100
        let newHeight: CGFloat = 750
        let newFrame = NSRect(
            x: screen.visibleFrame.midX - newWidth / 2,
            y: screen.visibleFrame.midY - newHeight / 2,
            width: newWidth,
            height: newHeight
        )
        window.setFrame(newFrame, display: true, animate: true)
    }
}
