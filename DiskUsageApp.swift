import SwiftUI

@main
struct DiskUsageApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var viewModel = DiskScannerViewModel(settings: .shared)

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .environmentObject(settings)
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
        }

        Settings {
            SettingsView()
        }
    }
}
