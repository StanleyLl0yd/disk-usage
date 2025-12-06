import Foundation

struct DiskUsageService {

    // Внутренний узел дерева для накопления размеров
    private final class Node {
        let path: String
        var size: Int64 = 0
        var children: [String: Node] = [:]

        init(path: String) {
            self.path = path
        }
    }

    static func scanTree(
        at rootUrl: URL
    ) -> (root: FolderUsage, restrictedTopFolders: Set<String>) {

        let fm = FileManager.default
        let rootPath = rootUrl.standardizedFileURL.path
        let rootNode = Node(path: rootPath)

        var restrictedTop: Set<String> = []

        let options: FileManager.DirectoryEnumerationOptions = [
            .skipsPackageDescendants
        ]

        if let enumerator = fm.enumerator(
            at: rootUrl,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey
            ],
            options: options,
            errorHandler: { url, error in
                let top = topLevelPath(for: url, under: rootUrl)
                restrictedTop.insert(top)
                return true
            }
        ) {
            for case let fileUrl as URL in enumerator {
                // Проверка отмены Task
                if Task.isCancelled {
                    break
                }
                
                // КРИТИЧНО: autoreleasepool для освобождения памяти
                autoreleasepool {
                    guard let values = try? fileUrl.resourceValues(forKeys: [
                        .isRegularFileKey,
                        .totalFileAllocatedSizeKey,
                        .fileAllocatedSizeKey
                    ]) else { return }
                    
                    guard values.isRegularFile == true else { return }

                    let rawSize = values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0
                    let fileSize = Int64(rawSize)
                    guard fileSize > 0 else { return }

                    // Папка, в которой лежит файл
                    let folderUrl = fileUrl.deletingLastPathComponent()
                    addSize(
                        fileSize,
                        forFolder: folderUrl,
                        underRoot: rootUrl,
                        rootNode: rootNode
                    )
                }
            }
        }

        let rootUsage = makeFolderUsage(from: rootNode)
        return (root: rootUsage, restrictedTopFolders: restrictedTop)
    }

    // MARK: - Helpers

    private static func addSize(
        _ size: Int64,
        forFolder folderUrl: URL,
        underRoot rootUrl: URL,
        rootNode: Node
    ) {
        let rootPath = rootUrl.standardizedFileURL.path
        let folderPath = folderUrl.standardizedFileURL.path

        // относительный путь папки относительно корня
        let relative: String
        if rootPath == "/" {
            relative = String(folderPath.dropFirst(1))
        } else if folderPath.hasPrefix(rootPath) {
            let start = folderPath.index(folderPath.startIndex, offsetBy: rootPath.count)
            var rel = String(folderPath[start...])
            if rel.hasPrefix("/") { rel.removeFirst() }
            relative = rel
        } else {
            return
        }

        let components = relative.split(separator: "/", omittingEmptySubsequences: true)
        var nodesOnPath: [Node] = [rootNode]
        var current = rootNode

        // создаём / берём узлы по пути
        for componentSub in components {
            let component = String(componentSub)
            if let child = current.children[component] {
                current = child
            } else {
                let childPath: String
                if current.path == "/" {
                    childPath = "/" + component
                } else {
                    childPath = (current.path as NSString).appendingPathComponent(component)
                }
                let child = Node(path: childPath)
                current.children[component] = child
                current = child
            }
            nodesOnPath.append(current)
        }

        // размер файла добавляем ко всем узлам по пути
        for node in nodesOnPath {
            node.size += size
        }
    }

    private static func makeFolderUsage(from node: Node) -> FolderUsage {
        let children = node.children.values
            .sorted { $0.path < $1.path }
            .map { makeFolderUsage(from: $0) }

        return FolderUsage(
            url: URL(fileURLWithPath: node.path),
            size: node.size,
            children: children
        )
    }

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
