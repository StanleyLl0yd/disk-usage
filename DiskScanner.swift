import Foundation

nonisolated struct CompletedScanSummary: Equatable, Sendable {
    let allocatedBytes: Int64
    let filesScanned: Int64
    let foldersScanned: Int64
    let restrictedLocations: Int
    let elapsed: Duration
}

nonisolated struct DiskScanResult: Sendable {
    let root: FolderUsage
    let restricted: [String]
    let summary: CompletedScanSummary
}

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
        .isRegularFileKey, .isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey
    ]

    func scan(at rootURL: URL, showHiddenFiles: Bool) async -> DiskScanResult {
        updateProgress(files: 0, bytes: 0, folder: "")

        let clock = ContinuousClock()
        let startedAt = clock.now
        let rootPath = rootURL.standardizedFileURL.path
        let rootNode = Node(path: rootPath)
        var restricted = Set<String>()
        var entriesSinceYield = 0
        var totalFiles: Int64 = 0
        var totalFolders: Int64 = 0
        var totalBytes: Int64 = 0
        let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles ? [] : [.skipsHiddenFiles]

        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(Self.resourceKeys),
            options: options
        ) { url, _ in
            restricted.insert(Self.topLevelPath(url, under: rootURL))
            return true
        }

        guard let enumerator else {
            let restrictedPaths = [rootPath]
            return DiskScanResult(
                root: FolderUsage(path: rootPath, size: 0),
                restricted: restrictedPaths,
                summary: CompletedScanSummary(
                    allocatedBytes: 0,
                    filesScanned: 0,
                    foldersScanned: 0,
                    restrictedLocations: restrictedPaths.count,
                    elapsed: startedAt.duration(to: clock.now)
                )
            )
        }

        while let item = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }

            autoreleasepool {
                guard let values = try? item.resourceValues(forKeys: Self.resourceKeys) else { return }

                if values.isDirectory == true {
                    totalFolders += 1
                    return
                }

                guard values.isRegularFile == true else { return }

                totalFiles += 1
                let folderPath = item.deletingLastPathComponent().standardizedFileURL.path

                if let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize,
                   size > 0 {
                    let fileSize = Int64(size)
                    let filePath = item.standardizedFileURL.path
                    let fileName = (filePath as NSString).lastPathComponent

                    rootNode.addFile(
                        path: filePath,
                        name: fileName,
                        folder: folderPath,
                        size: fileSize,
                        rootPath: rootPath
                    )
                    totalBytes += fileSize
                }

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
        let restrictedPaths = restricted.sorted()
        return DiskScanResult(
            root: rootNode.toFolderUsage(),
            restricted: restrictedPaths,
            summary: CompletedScanSummary(
                allocatedBytes: totalBytes,
                filesScanned: totalFiles,
                foldersScanned: totalFolders,
                restrictedLocations: restrictedPaths.count,
                elapsed: startedAt.duration(to: clock.now)
            )
        )
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
