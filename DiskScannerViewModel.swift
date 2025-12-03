import Foundation
import Combine

@MainActor
final class DiskScannerViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var items: [FolderUsage] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var status: String
    @Published private(set) var restrictedTopFolders: [String] = []
    @Published private(set) var currentTargetDescription: String
    @Published private(set) var totalSize: Int64 = 0

    // MARK: - Dependencies

    private let service: DiskUsageServiceProtocol
    private var currentTask: Task<Void, Never>?

    // MARK: - Init

    init(service: DiskUsageServiceProtocol) {
        self.service = service
        self.status = String(
            localized: "status.initial",
            defaultValue: "Choose a folder or start a scan."
        )
        self.currentTargetDescription = String(
            localized: "target.none",
            defaultValue: "not selected"
        )
    }

    // MARK: - Public API

    func scanRoot() {
        let description = String(
            localized: "target.root",
            defaultValue: "disk (/)"
        )

        scan(
            at: URL(fileURLWithPath: "/"),
            description: description,
            groupByRoot: true,
            isSystemWideScan: true
        )
    }

    func scanHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser

        scan(
            at: home,
            description: home.path,
            groupByRoot: false,
            isSystemWideScan: false
        )
    }

    func scanFolder(at folder: URL) {
        scan(
            at: folder,
            description: folder.path,
            groupByRoot: false,
            isSystemWideScan: false
        )
    }

    // MARK: - Private

    private func scan(
        at rootUrl: URL,
        description: String,
        groupByRoot: Bool,
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
        let group = groupByRoot
        let service = self.service

        currentTask = Task.detached { [weak self] in
            let result = await service.scanDisk(
                at: url,
                groupByRoot: group
            )

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self else { return }

                self.items = result.items
                self.totalSize = result.items.reduce(0) { $0 + $1.size }
                self.restrictedTopFolders = Array(result.restrictedTopFolders).sorted()
                self.isScanning = false

                if result.items.isEmpty {
                    self.status = String(
                        localized: "status.finished.empty",
                        defaultValue: "Scan finished. No data found or no access."
                    )
                } else if result.restrictedTopFolders.isEmpty {
                    let format = String(
                        localized: "status.finished.count",
                        defaultValue: "Scan finished. Items found: %lld."
                    )
                    self.status = String(format: format, Int64(result.items.count))
                } else {
                    let format = String(
                        localized: "status.finished.countWithRestricted",
                        defaultValue: "Scan finished. Items found: %lld. Some folders are not accessible."
                    )
                    self.status = String(format: format, Int64(result.items.count))
                }
            }
        }
    }
}
