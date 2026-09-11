import Foundation
import Combine
import AppKit

enum TrashResult {
    case success
    case error(String)
}

enum ScanLifecycle: Equatable {
    case initial
    case scanning
    case completed
    case cancelled
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
    @Published private(set) var lifecycle: ScanLifecycle = .initial
    @Published private(set) var status: String
    @Published private(set) var restricted: [String] = []
    @Published private(set) var targetDescription: String
    @Published private(set) var totalSize: Int64 = 0
    @Published private(set) var progress = ScanProgress()
    @Published private(set) var diskInfo: DiskInfo = .empty
    @Published private(set) var completedSummary: CompletedScanSummary?
    private(set) var snapshotRevision: UInt64 = 0

    var isScanning: Bool {
        lifecycle == .scanning
    }

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

        lifecycle = .scanning
        targetDescription = description ?? url.path
        restricted = []
        totalSize = 0
        progress = ScanProgress()
        completedSummary = nil
        status = String(localized: "status.scanning", defaultValue: "Scanning…")
        snapshotRevision &+= 1
        items = []

        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { break }
                self?.progress = scanner.progress
            }
        }

        let workerTask = Task.detached(priority: .userInitiated) { () -> (
            result: DiskScanResult,
            progress: ScanProgress
        )? in
            let result = await scanner.scan(at: url, showHiddenFiles: showHiddenFiles)
            guard !Task.isCancelled else { return nil }
            return (result: result, progress: scanner.progress)
        }

        scanTask = Task { [weak self] in
            let output = await withTaskCancellationHandler {
                await workerTask.value
            } onCancel: {
                workerTask.cancel()
            }

            guard !Task.isCancelled,
                  let output,
                  let self,
                  self.scanGeneration == generation else { return }
            self.finishScan(output.result, progress: output.progress)
        }
    }

    func cancel() {
        scanGeneration &+= 1
        cancelTasks()
        progress = ScanProgress()
        completedSummary = nil
        status = String(localized: "status.cancelled", defaultValue: "Cancelled.")
        lifecycle = .cancelled
    }

    private func finishScan(_ result: DiskScanResult, progress finalProgress: ScanProgress) {
        progressTask?.cancel()
        progressTask = nil
        scanTask = nil
        progress = finalProgress
        totalSize = result.root.size
        restricted = result.restricted
        completedSummary = result.summary
        snapshotRevision &+= 1
        items = result.root.children

        status = String(
            format: String(
                localized: "status.finished",
                defaultValue: "Scanned: %@ · Files: %@ · Folders: %@ · Restricted: %@ · Time: %@"
            ),
            formatBytes(result.summary.allocatedBytes),
            formatNumber(result.summary.filesScanned),
            formatNumber(result.summary.foldersScanned),
            formatNumber(Int64(result.summary.restrictedLocations)),
            formatElapsed(result.summary.elapsed)
        )

        progress = ScanProgress()
        updateDiskInfo()
        lifecycle = .completed
    }

    private func formatElapsed(_ duration: Duration) -> String {
        let totalSeconds = max(Int64(0), duration.components.seconds)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%lld:%02lld:%02lld", hours, minutes, seconds)
        }
        return String(format: "%lld:%02lld", minutes, seconds)
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
            let updatedItems = items.compactMap { $0.removing(path: item.path) }
            totalSize -= size
            completedSummary = nil
            status = String(localized: "status.trashed", defaultValue: "Moved to Trash.")
            snapshotRevision &+= 1
            items = updatedItems
            updateDiskInfo()
            return .success
        } catch {
            return .error(error.localizedDescription)
        }
    }
}
