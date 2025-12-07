import Foundation

final class DiskScanner: @unchecked Sendable {
    private let lock = NSLock()
    private var _progress = ScanProgress()
    
    var progress: ScanProgress {
        lock.lock()
        defer { lock.unlock() }
        return _progress
    }
    
    private func updateProgress(files: Int64, bytes: Int64, folder: String) {
        lock.lock()
        _progress.filesScanned = files
        _progress.bytesFound = bytes
        _progress.currentFolder = folder
        lock.unlock()
    }
    
    private static let resourceKeys: Set<URLResourceKey> = [
        .isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey
    ]
    
    func scan(at rootUrl: URL) async -> (root: FolderUsage, restricted: [String]) {
        updateProgress(files: 0, bytes: 0, folder: "")
        
        let rootPath = rootUrl.standardizedFileURL.path
        let rootNode = Node(path: rootPath)
        var restricted = Set<String>()
        var counter = 0
        var totalFiles: Int64 = 0
        var totalBytes: Int64 = 0
        
        let enumerator = FileManager.default.enumerator(
            at: rootUrl,
            includingPropertiesForKeys: Array(Self.resourceKeys),
            options: .skipsPackageDescendants
        ) { url, _ in
            restricted.insert(Self.topLevelPath(url, under: rootUrl))
            return true
        }
        
        guard let enumerator else {
            return (FolderUsage(path: rootPath, size: 0), [])
        }
        
        while let item = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            
            autoreleasepool {
                guard let vals = try? item.resourceValues(forKeys: Self.resourceKeys),
                      vals.isRegularFile == true,
                      let size = vals.totalFileAllocatedSize ?? vals.fileAllocatedSize,
                      size > 0 else { return }
                
                let fileSize = Int64(size)
                let filePath = item.standardizedFileURL.path
                let folderPath = item.deletingLastPathComponent().standardizedFileURL.path
                let fileName = (filePath as NSString).lastPathComponent
                
                rootNode.addFile(path: filePath, name: fileName, folder: folderPath, size: fileSize, rootPath: rootPath)
                
                totalFiles += 1
                totalBytes += fileSize
                
                if totalFiles % 50 == 0 {
                    updateProgress(files: totalFiles, bytes: totalBytes, folder: folderPath)
                }
            }
            
            counter += 1
            if counter % 100 == 0 {
                await Task.yield()
            }
        }
        
        updateProgress(files: totalFiles, bytes: totalBytes, folder: "")
        return (rootNode.toFolderUsage(), restricted.sorted())
    }
    
    private static func topLevelPath(_ url: URL, under root: URL) -> String {
        let comps = url.pathComponents
        let baseCount = root.pathComponents.count
        
        if root.path == "/" {
            return comps.count > 1 ? "/" + comps[1] : "/"
        } else {
            return comps.count > baseCount ? root.appendingPathComponent(comps[baseCount]).path : root.path
        }
    }
}

// MARK: - Internal Node

private final class Node {
    let path: String
    let isFile: Bool
    var size: Int64 = 0
    var children: [String: Node] = [:]
    
    init(path: String, isFile: Bool = false) {
        self.path = path
        self.isFile = isFile
    }
    
    func addFile(path filePath: String, name: String, folder: String, size: Int64, rootPath: String) {
        let relative: Substring
        if rootPath == "/" {
            relative = folder.dropFirst()
        } else if folder.hasPrefix(rootPath) {
            relative = folder.dropFirst(rootPath.count).drop { $0 == "/" }
        } else { return }
        
        self.size += size
        var current = self
        
        for comp in relative.split(separator: "/") {
            let compName = String(comp)
            let child = current.children[compName] ?? {
                let c = Node(path: current.path == "/" ? "/\(compName)" : "\(current.path)/\(compName)")
                current.children[compName] = c
                return c
            }()
            child.size += size
            current = child
        }
        
        if let existing = current.children[name] {
            existing.size += size
        } else {
            let fileNode = Node(path: filePath, isFile: true)
            fileNode.size = size
            current.children[name] = fileNode
        }
    }
    
    func toFolderUsage() -> FolderUsage {
        let kids = children.values
            .sorted { $0.path < $1.path }
            .map { $0.toFolderUsage() }
        return FolderUsage(path: path, size: size, isFile: isFile, children: kids)
    }
}
