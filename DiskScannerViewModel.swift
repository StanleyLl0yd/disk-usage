import Foundation
import Combine
import AppKit

/// Результат операции удаления
enum TrashResult {
    case success(freedSize: Int64)
    case error(String)
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
    
    private var scanTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private let scanner = DiskScanner()
    
    init() {
        status = String(localized: "status.initial", defaultValue: "Choose a folder or start a scan.")
        targetDescription = String(localized: "target.none", defaultValue: "not selected")
    }
    
    // MARK: - Scanning
    
    func scanHome() {
        scan(FileManager.default.homeDirectoryForCurrentUser)
    }
    
    func scanRoot() {
        scan(URL(fileURLWithPath: "/"), description: String(localized: "target.root", defaultValue: "disk (/)"))
    }
    
    func scan(_ url: URL, description: String? = nil) {
        guard !isScanning else { return }
        
        cancelTasks()
        isScanning = true
        targetDescription = description ?? url.path
        items = []
        restricted = []
        totalSize = 0
        progress = ScanProgress()
        status = String(localized: "status.scanning", defaultValue: "Scanning…")
        
        progressTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                progress = scanner.progress
            }
        }
        
        scanTask = Task {
            let result = await scanner.scan(at: url)
            guard !Task.isCancelled else { return }
            
            progressTask?.cancel()
            progress = scanner.progress
            
            items = result.root.children
            totalSize = result.root.size
            restricted = result.restricted
            isScanning = false
            
            status = items.isEmpty
                ? String(localized: "status.finished.empty", defaultValue: "No data found.")
                : String(format: String(localized: "status.finished", defaultValue: "Found: %@, %lld items."),
                        formatBytes(totalSize), Int64(items.count))
            progress = ScanProgress()
        }
    }
    
    func cancel() {
        cancelTasks()
        isScanning = false
        progress = ScanProgress()
        status = String(localized: "status.cancelled", defaultValue: "Cancelled.")
    }
    
    private func cancelTasks() {
        scanTask?.cancel()
        progressTask?.cancel()
    }
    
    // MARK: - File Operations
    
    /// Показать в Finder
    func showInFinder(_ item: FolderUsage) {
        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
    }
    
    /// Копировать путь в буфер обмена
    func copyPath(_ item: FolderUsage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.path, forType: .string)
    }
    
    /// Переместить в корзину
    func moveToTrash(_ item: FolderUsage) -> TrashResult {
        let url = item.url
        let size = item.size
        
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            
            // Обновляем дерево — удаляем элемент и пересчитываем размеры
            items = items.compactMap { $0.removing(path: item.path) }
            totalSize -= size
            
            // Обновляем статус
            let format = String(localized: "status.trashed", defaultValue: "Moved to Trash. Freed: %@")
            status = String(format: format, formatBytes(size))
            
            return .success(freedSize: size)
        } catch {
            return .error(error.localizedDescription)
        }
    }
}
