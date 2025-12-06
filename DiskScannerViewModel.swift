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
    
    // УЛУЧШЕНИЕ 1: Прогресс сканирования
    @Published private(set) var filesScanned: Int = 0
    
    // УЛУЧШЕНИЕ 9: Опция параллельного сканирования (по умолчанию выключено)
    @Published var useParallelScanning: Bool = false

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

    // УЛУЧШЕНИЕ 2: Отмена сканирования
    func cancelScan() {
        currentTask?.cancel()
        isScanning = false
        filesScanned = 0
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
        filesScanned = 0

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

        currentTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            // УЛУЧШЕНИЕ 9: Выбор между параллельным и последовательным сканированием
            let result: (root: FolderUsage, restrictedTopFolders: Set<String>)
            
            let useParallel = await self.useParallelScanning
            
            if useParallel && url.path == "/" {
                // Параллельное сканирование только для корневой директории
                result = await DiskUsageService.scanTreeParallel(at: url) { count in
                    Task { @MainActor [weak self] in
                        self?.updateProgress(count)
                    }
                }
            } else {
                // Обычное сканирование
                result = await Task.detached {
                    DiskUsageService.scanTree(at: url) { count in
                        Task { @MainActor [weak self] in
                            self?.updateProgress(count)
                        }
                    }
                }.value
            }

            if Task.isCancelled { return }

            await MainActor.run { [weak self] in
                guard let self = self else { return }
                
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
    
    // УЛУЧШЕНИЕ: Отдельный метод для обновления прогресса
    @MainActor
    func updateProgress(_ count: Int) {
        self.filesScanned = count
    }
}
