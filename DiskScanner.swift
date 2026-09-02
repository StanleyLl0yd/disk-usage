import Foundation

nonisolated final class DiskScanner: @unchecked Sendable {
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

    func scan(at rootURL: URL, showHiddenFiles: Bool) async -> (root: FolderUsage, restricted: [String]) {
        updateProgress(files: 0, bytes: 0, folder: "")

        let rootPath = rootURL.standardizedFileURL.path
        let rootNode = Node(path: rootPath)
        var restricted = Set<String>()
        var entriesSinceYield = 0
        var totalFiles: Int64 = 0
        var totalBytes: Int64 = 0
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !showHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }

        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(Self.resourceKeys),
            options: options
        ) { url, _ in
            restricted.insert(Self.topLevelPath(url, under: rootURL))
            return true
        }

        guard let enumerator else {
            return (FolderUsage(path: rootPath, size: 0), [rootPath])
        }

        while let item = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }

            autoreleasepool {
                guard let values = try? item.resourceValues(forKeys: Self.resourceKeys),
                      values.isRegularFile == true,
                      let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize,
                      size > 0 else { return }

                let fileSize = Int64(size)
                let filePath = item.standardizedFileURL.path
                let folderPath = item.deletingLastPathComponent().standardizedFileURL.path
                let fileName = (filePath as NSString).lastPathComponent

                rootNode.addFile(
                    path: filePath,
                    name: fileName,
                    folder: folderPath,
                    size: fileSize,
                    rootPath: rootPath
                )

                totalFiles += 1
                totalBytes += fileSize

                if totalFiles % 50 == 0 {
                    updateProgress(files: totalFiles, bytes: totalBytes, folder: folderPath)
                }
            }

            entriesSinceYield += 1
            if entriesSinceYield == 100 {
                entriesSinceYield = 0
                await Task.yield()
            }
        }

        updateProgress(files: totalFiles, bytes: totalBytes, folder: "")
        return (rootNode.toFolderUsage(), restricted.sorted())
    }

    private static func topLevelPath(_ url: URL, under root: URL) -> String {
        let components = url.pathComponents
        let baseCount = root.pathComponents.count

        if root.path == "/" {
            return components.count > 1 ? "/" + components[1] : "/"
        }
        return components.count > baseCount
            ? root.appendingPathComponent(components[baseCount]).path
            : root.path
    }
}

nonisolated private final class Node {
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
        } else {
            return
        }

        self.size += size
        var current = self

        for component in relative.split(separator: "/") {
            let name = String(component)
            let child = current.children[name] ?? {
                let child = Node(path: current.path == "/" ? "/\(name)" : "\(current.path)/\(name)")
                current.children[name] = child
                return child
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
        let childNames = children.keys.sorted()
        var result: [FolderUsage] = []
        result.reserveCapacity(childNames.count)

        for name in childNames {
            if let child = children.removeValue(forKey: name) {
                result.append(child.toFolderUsage())
            }
        }

        return FolderUsage(path: path, size: size, isFile: isFile, children: result)
    }
}
