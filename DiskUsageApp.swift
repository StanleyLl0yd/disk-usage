import SwiftUI
import AppKit

enum FullDiskAccessSettings {
    static let urlString = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
    static let url = URL(string: urlString)

    static func open(using opener: (URL) -> Bool) -> Bool {
        guard let url else { return false }
        return opener(url)
    }

    @MainActor
    static func open() -> Bool {
        open(using: { NSWorkspace.shared.open($0) })
    }
}

@main
struct DiskUsageApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var viewModel = DiskScannerViewModel(settings: .shared)
    @State private var isDropTargeted = false
    @State private var showDropError = false
    @State private var dropErrorMessage = ""

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .environmentObject(settings)
                .overlay {
                    if isDropTargeted {
                        RoundedRectangle(cornerRadius: ZenDesign.Radius.medium, style: .continuous)
                            .stroke(ZenDesign.Colors.accent, lineWidth: 2)
                            .padding(ZenDesign.Spacing.compact)
                            .allowsHitTesting(false)
                    }
                }
                .dropDestination(for: URL.self) { urls, _ in
                    handleDroppedURLs(urls)
                } isTargeted: { targeted in
                    isDropTargeted = targeted
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        if viewModel.canRescan {
                            Button {
                                viewModel.rescan()
                            } label: {
                                Label(
                                    String(localized: "button.rescan", defaultValue: "Rescan"),
                                    systemImage: "arrow.clockwise"
                                )
                            }
                            .help(String(localized: "button.rescan", defaultValue: "Rescan"))
                        }
                    }
                }
                .alert(
                    String(localized: "alert.error.title", defaultValue: "Error"),
                    isPresented: $showDropError
                ) {
                    Button(String(localized: "alert.ok", defaultValue: "OK")) {
                        showDropError = false
                    }
                } message: {
                    Text(dropErrorMessage)
                }
        }

        Settings {
            SettingsView()
        }
    }

    private func handleDroppedURLs(_ urls: [URL]) -> Bool {
        switch viewModel.scanDroppedURLs(urls) {
        case .accepted:
            return true
        case .scanInProgress:
            dropErrorMessage = String(
                localized: "drop.error.busy",
                defaultValue: "Cancel or finish the current scan before dropping another folder."
            )
        case .requiresSingleFolder:
            dropErrorMessage = String(
                localized: "drop.error.singleFolder",
                defaultValue: "Drop one folder at a time."
            )
        case .unsupportedItem:
            dropErrorMessage = String(
                localized: "drop.error.directoryOnly",
                defaultValue: "Only folders can be scanned by drag and drop."
            )
        }
        showDropError = true
        return false
    }
}
