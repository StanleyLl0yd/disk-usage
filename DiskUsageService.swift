import Foundation

struct DiskUsageService {

    // MARK: - Constants
    
    private static let batchSize = 500
    
    // Keys for resource values - create once, reuse
    private static let resourceKeys: Set<URLResourceKey> = [
        .isRegularFileKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey
    ]

    // MARK: - Tree Node
    
    private final class Node {
        let path: String
        var size: Int64 = 0
        var children: [String: Node]

        init(path: String, expectedChildren: Int = 4) {
            self.path = path
            // Pre-allocate dictionary capacity for typical folder structure
            self.children = Dictionary(minimumCapacity: expectedChildren)
        }
    }
    
    // MARK: - Batch Item
    
    private struct FileInfo {
        let folderPath: String
        let size: Int64
    }

    // MARK: - Public API

    static func scanTree(
        at rootUrl: URL
    ) -> (root: FolderUsage, restrictedTopFolders: Set<String>) {

        let fm = FileManager.default
        let rootPath = rootUrl.standardizedFileURL.path
        let rootNode = Node(path: rootPath, expectedChildren: 16)

        var restrictedTop: Set<String> = []
        
        // Batch for accumulating file info before processing
        var batch: [FileInfo] = []
        batch.reserveCapacity(batchSize)

        let options: FileManager.DirectoryEnumerationOptions = [
            .skipsPackageDescendants
        ]

        if let enumerator = fm.enumerator(
            at: rootUrl,
            includingPropertiesForKeys: Array(resourceKeys),
            options: options,
            errorHandler: { url, error in
                let top = topLevelPath(for: url, under: rootUrl)
                restrictedTop.insert(top)
                return true
            }
        ) {
            // Process files in batches to reduce autoreleasepool overhead
            autoreleasepool {
                for case let fileUrl as URL in enumerator {
                    if Task.isCancelled { break }
                    
                    guard let values = try? fileUrl.resourceValues(forKeys: resourceKeys),
                          values.isRegularFile == true else {
                        continue
                    }

                    let rawSize = values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0
                    let fileSize = Int64(rawSize)
                    guard fileSize > 0 else { continue }

                    let folderPath = fileUrl.deletingLastPathComponent().standardizedFileURL.path
                    batch.append(FileInfo(folderPath: folderPath, size: fileSize))
                    
                    // Process batch when full
                    if batch.count >= batchSize {
                        processBatch(batch, rootPath: rootPath, rootNode: rootNode)
                        batch.removeAll(keepingCapacity: true)
                    }
                }
            }
            
            // Process remaining items
            if !batch.isEmpty {
                processBatch(batch, rootPath: rootPath, rootNode: rootNode)
            }
        }

        let rootUsage = makeFolderUsage(from: rootNode)
        return (root: rootUsage, restrictedTopFolders: restrictedTop)
    }

    // MARK: - Batch Processing
    
    private static func processBatch(
        _ batch: [FileInfo],
        rootPath: String,
        rootNode: Node
    ) {
        for fileInfo in batch {
            addSize(
                fileInfo.size,
                folderPath: fileInfo.folderPath,
                rootPath: rootPath,
                rootNode: rootNode
            )
        }
    }

    // MARK: - Size Accumulation

    private static func addSize(
        _ size: Int64,
        folderPath: String,
        rootPath: String,
        rootNode: Node
    ) {
        // Calculate relative path from root
        let relative: String
        if rootPath == "/" {
            relative = String(folderPath.dropFirst(1))
        } else if folderPath.hasPrefix(rootPath) {
            let startIndex = folderPath.index(folderPath.startIndex, offsetBy: rootPath.count)
            var rel = String(folderPath[startIndex...])
            if rel.hasPrefix("/") { rel.removeFirst() }
            relative = rel
        } else {
            return
        }

        // Use Substring to avoid allocations during split
        let components = relative.split(separator: "/", omittingEmptySubsequences: true)
        
        // Add size to root
        rootNode.size += size
        
        guard !components.isEmpty else { return }
        
        var current = rootNode

        // Create or traverse nodes along the path, accumulating size
        for componentSub in components {
            let component = String(componentSub)
            
            let child: Node
            if let existing = current.children[component] {
                child = existing
            } else {
                let childPath: String
                if current.path == "/" {
                    childPath = "/" + component
                } else {
                    // Faster than NSString.appendingPathComponent for simple cases
                    childPath = current.path + "/" + component
                }
                child = Node(path: childPath)
                current.children[component] = child
            }
            
            child.size += size
            current = child
        }
    }

    // MARK: - Tree Conversion

    private static func makeFolderUsage(from node: Node) -> FolderUsage {
        // Sort and convert children
        let sortedChildren = node.children.values
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        
        let children: [FolderUsage]
        if sortedChildren.isEmpty {
            children = []
        } else {
            // Pre-allocate array capacity
            var result = [FolderUsage]()
            result.reserveCapacity(sortedChildren.count)
            for child in sortedChildren {
                result.append(makeFolderUsage(from: child))
            }
            children = result
        }

        return FolderUsage(
            url: URL(fileURLWithPath: node.path),
            size: node.size,
            children: children
        )
    }

    // MARK: - Helpers

    private static func topLevelPath(for url: URL, under root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let components = url.pathComponents
        let baseComponents = root.pathComponents

        if rootPath == "/" {
            if components.count > 1 {
                return "/" + components[1]
            } else {
                return "/"
            }
        } else {
            if components.count > baseComponents.count {
                let childComponent = components[baseComponents.count]
                return root.appendingPathComponent(childComponent).path
            } else {
                return root.path
            }
        }
    }
}
