import SwiftUI

@main
struct DiskUsageApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: DiskScannerViewModel(
                    service: DiskUsageService()
                )
            )
        }
    }
}
