import Foundation
import Combine

enum SortOption: String, CaseIterable, Identifiable {
    case sizeDescending
    case sizeAscending
    case name

    var id: Self { self }

    var localizedTitle: String {
        switch self {
        case .sizeDescending:
            return String(localized: "sort.sizeDescending", defaultValue: "Size ↓")
        case .sizeAscending:
            return String(localized: "sort.sizeAscending", defaultValue: "Size ↑")
        case .name:
            return String(localized: "sort.name", defaultValue: "Name")
        }
    }
}

final class DiskScannerViewModel: ObservableObject {
    // MARK: - Published state

    @Published private(set) var items: [FolderUsage] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var status: String
    @Published private(set) var restrictedTopFolders: [String] = []
    @Published private(set) var currentTargetDescription: String
    @Published var sortOption: SortOption = .sizeDescending
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

    func sortedItems() -> [FolderUsage] {
        switch sortOption {
        case .sizeDescending:
            return items.sorted { $0.size > $1.size }
        case .sizeAscending:
            return items.sorted { $0.size < $1.size }
        case .name:
            return items.sorted {
                $0.url.path.localizedCaseInsensitiveCompare($1.url.path) == .orderedAscending
            }
        }
    }

    // MARK: - Private

    private func scan(
        at rootUrl: URL,
        description: String,
        groupByRoot: Bool,
        isSystemWideScan: Bool
    ) {
        guard !isScanning else { return }

        // отменяем предыдущий скан, если он ещё идёт
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

        currentTask = Task { [weak self] in
            guard let self else { return }

            // тяжёлая работа – в сервисе
            let result = await self.service.scanDisk(
                at: rootUrl,
                groupByRoot: groupByRoot
            )

            guard !Task.isCancelled else { return }

            await MainActor.run {
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
