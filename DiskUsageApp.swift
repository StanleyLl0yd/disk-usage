import SwiftUI

@main
struct DiskUsageApp: App {
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: DiskScannerViewModel(settings: settings))
                .environmentObject(settings)
        }

        Settings {
            SettingsView()
        }
    }
}
