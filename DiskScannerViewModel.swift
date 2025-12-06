import Foundation
import Combine

@MainActor
final class DiskScannerViewModel: ObservableObject {

    @Published private(set) var items: [FolderUsage] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var status: String
    @Published private(set) var restrictedTopFolders: [String] = []
    @Published private(set) var currentTargetDescription: String
    @Published private(set) var totalSize: Int64 = 0

    private var currentTask: Task<Void, Never>?

    init() {
        self.status = String(
            localized: "status.initial",
            defaultValue: "Choose a folder or start a scan."
        )
        self.currentTargetDescription = String(
            localized: "target.none",
            defaultValue: "not selected"
        )
    }

    func cancelScan() {
        currentTask?.cancel()
        isScanning = false
        status = String(
            localized: "status.cancelled",
            defaultValue: "Scan cancelled."
        )
    }

    func scanRoot() {
        let description = String(
            localized: "target.root",
            defaultValue: "disk (/)"
        )

        scan(
            at: URL(fileURLWithPath: "/"),
            description: description,
            isSystemWideScan: true
        )
    }

    func scanHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser

        scan(
            at: home,
            description: home.path,
            isSystemWideScan: false
        )
    }

    func scanFolder(at folder: URL) {
        scan(
            at: folder,
            description: folder.path,
            isSystemWideScan: false
        )
    }

    private func scan(
        at rootUrl: URL,
        description: String,
        isSystemWideScan: Bool
    ) {
        guard !isScanning else { return }

        currentTask?.cancel()

        isScanning = true
        currentTargetDescription = description
        items = []
        restrictedTopFolders = []
        totalSize = 0

        status = isSystemWideScan
            ? String(
                localized: "status.scanning.system",
                defaultValue: "Scanning the entire disk… This may take a while."
              )
            : String(
                localized: "status.scanning.folder",
                defaultValue: "Scanning folder… This may take a while."
              )

        let url = rootUrl

        currentTask = Task.detached(priority: .userInitiated) {
            // Простое сканирование без прогресс-репортов
            let result = DiskUsageService.scanTree(at: url)

            if Task.isCancelled { return }

            await MainActor.run { [weak self] in
                guard let self else { return }

                self.items = result.root.children
                self.totalSize = result.root.size
                self.restrictedTopFolders = Array(result.restrictedTopFolders).sorted()
                self.isScanning = false

                if self.items.isEmpty {
                    self.status = String(
                        localized: "status.finished.empty",
                        defaultValue: "Scan finished. No data found or no access."
                    )
                } else if result.restrictedTopFolders.isEmpty {
                    let format = String(
                        localized: "status.finished.count",
                        defaultValue: "Scan finished. Items found: %lld."
                    )
                    self.status = String(format: format, Int64(self.items.count))
                } else {
                    let format = String(
                        localized: "status.finished.countWithRestricted",
                        defaultValue: "Scan finished. Items found: %lld. Some folders are not accessible."
                    )
                    self.status = String(format: format, Int64(self.items.count))
                }
            }
        }
    }
}
