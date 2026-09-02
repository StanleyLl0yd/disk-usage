import Foundation
import Combine
import AppKit

enum TrashResult {
    case success
    case error(String)
}

struct DiskInfo {
    let totalCapacity: Int64
    let usedSpace: Int64
    let freeSpace: Int64

    var usedPercent: Double {
        guard totalCapacity > 0 else { return 0 }
        return Double(usedSpace) / Double(totalCapacity) * 100
    }

    static let empty = DiskInfo(totalCapacity: 0, usedSpace: 0, freeSpace: 0)
}

@MainActor
final class DiskScannerViewModel: ObservableObject {
    @Published private(set) var items: [FolderUsage] = []
    @Published private(set) var isScanning = false
    @Published private(set) var status: String
    @Published private(set) var restricted: [String] = []
    @Published private(set) var targetDescription: String
    @Published private(set) var totalSize: Int64 = 0
    @Published private(set) var progress = ScanProgress()
    @Published private(set) var diskInfo: DiskInfo = .empty

    private let settings: AppSettings
    private var scanTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var scanGeneration = 0

    init(settings: AppSettings = .shared) {
        self.settings = settings
        status = String(localized: "status.initial", defaultValue: "Choose a folder or start a scan.")
        targetDescription = String(localized: "target.none", defaultValue: "not selected")
        updateDiskInfo()
    }

    func updateDiskInfo() {
        do {
            let values = try URL(fileURLWithPath: "/").resourceValues(
                forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]
            )
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = Int64(values.volumeAvailableCapacity ?? 0)
            diskInfo = DiskInfo(totalCapacity: total, usedSpace: total - free, freeSpace: free)
        } catch {
            diskInfo = .empty
        }
    }

    func scanHome() {
        scan(FileManager.default.homeDirectoryForCurrentUser)
    }

    func scanRoot() {
        scan(
            URL(fileURLWithPath: "/"),
            description: String(localized: "target.root", defaultValue: "disk (/)")
        )
    }

    func scan(_ url: URL, description: String? = nil) {
        guard !isScanning else { return }

        cancelTasks()
        scanGeneration &+= 1
        let generation = scanGeneration
        let scanner = DiskScanner()
        let showHiddenFiles = settings.showHiddenFiles

        isScanning = true
        targetDescription = description ?? url.path
        items = []
        restricted = []
        totalSize = 0
        progress = ScanProgress()
        status = String(localized: "status.scanning", defaultValue: "Scanning…")

        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { break }
                self?.progress = scanner.progress
            }
        }

        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            let result = await scanner.scan(at: url, showHiddenFiles: showHiddenFiles)
            guard !Task.isCancelled else { return }
            let finalProgress = scanner.progress

            await MainActor.run {
                guard let self, self.scanGeneration == generation else { return }
                self.finishScan(result, progress: finalProgress)
            }
        }
    }

    func cancel() {
        scanGeneration &+= 1
        cancelTasks()
        isScanning = false
        progress = ScanProgress()
        status = String(localized: "status.cancelled", defaultValue: "Cancelled.")
    }

    private func finishScan(
        _ result: (root: FolderUsage, restricted: [String]),
        progress finalProgress: ScanProgress
    ) {
        progressTask?.cancel()
        progressTask = nil
        scanTask = nil
        progress = finalProgress
        items = result.root.children
        totalSize = result.root.size
        restricted = result.restricted
        isScanning = false

        status = items.isEmpty
            ? String(localized: "status.finished.empty", defaultValue: "No data found.")
            : String(
                format: String(localized: "status.finished", defaultValue: "Found: %@, %lld items."),
                formatBytes(totalSize),
                Int64(items.count)
            )

        progress = ScanProgress()
        updateDiskInfo()
    }

    private func cancelTasks() {
        scanTask?.cancel()
        progressTask?.cancel()
        scanTask = nil
        progressTask = nil
    }

    func showInFinder(_ item: FolderUsage) {
        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
    }

    func copyPath(_ item: FolderUsage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.path, forType: .string)
    }

    func moveToTrash(_ item: FolderUsage) -> TrashResult {
        let size = item.size

        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            items = items.compactMap { $0.removing(path: item.path) }
            totalSize -= size
            status = String(localized: "status.trashed", defaultValue: "Moved to Trash.")
            updateDiskInfo()
            return .success
        } catch {
            return .error(error.localizedDescription)
        }
    }
}
