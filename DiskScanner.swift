import Foundation

actor DiskScanner {
    private var _progress = ScanProgress()
    
    var progress: ScanProgress {
        _progress
    }
    
    private static let resourceKeys: Set<URLResourceKey> = [
        .isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey
    ]
    
    func scan(at rootUrl: URL) async -> (root: FolderUsage, restricted: [String]) {
        _progress = ScanProgress()
        
        let rootPath = rootUrl.standardizedFileURL.path
        let rootNode = Node(path: rootPath)
        var restricted = Set<String>()
        var counter = 0
        
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
        
        for case let url as URL in enumerator {
            if Task.isCancelled { break }
            
            autoreleasepool {
                guard let vals = try? url.resourceValues(forKeys: Self.resourceKeys),
                      vals.isRegularFile == true,
                      let size = vals.totalFileAllocatedSize ?? vals.fileAllocatedSize,
                      size > 0 else { return }
                
                let fileSize = Int64(size)
                let filePath = url.standardizedFileURL.path
                let folderPath = url.deletingLastPathComponent().standardizedFileURL.path
                let fileName = (filePath as NSString).lastPathComponent
                
                rootNode.addFile(path: filePath, name: fileName, folder: folderPath, size: fileSize, rootPath: rootPath)
                
                _progress.filesScanned += 1
                _progress.bytesFound += fileSize
                _progress.currentFolder = folderPath
            }
            
            counter += 1
            if counter % 50 == 0 { await Task.yield() }
        }
        
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

private final class Node: @unchecked Sendable {
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
            let name = String(comp)
            let child = current.children[name] ?? {
                let c = Node(path: current.path == "/" ? "/\(name)" : "\(current.path)/\(name)")
                current.children[name] = c
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
