import Foundation
import OSLog

// УЛУЧШЕНИЕ 15: Логирование
private let logger = Logger(subsystem: "com.diskusage.app", category: "scanning")

// УЛУЧШЕНИЕ 9: Helper для chunking массивов
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

struct DiskUsageService {
    
    // УЛУЧШЕНИЕ 13: Обработка ошибок памяти
    private static let maxNodes = 500_000
    
    enum ScanError: Error {
        case tooManyNodes
        case scanCancelled
    }

    // Внутренний узел дерева для накопления размеров
    private final class Node {
        let path: String
        var size: Int64 = 0
        var children: [String: Node] = [:]

        init(path: String) {
            self.path = path
        }
        
        // УЛУЧШЕНИЕ 13: Подсчет всех узлов в дереве
        var totalNodeCount: Int {
            1 + children.values.reduce(0) { $0 + $1.totalNodeCount }
        }
    }

    // УЛУЧШЕНИЕ 1: Добавлен прогресс-репорт
    static func scanTree(
        at rootUrl: URL,
        progressHandler: (@Sendable (Int) -> Void)? = nil
    ) -> (root: FolderUsage, restrictedTopFolders: Set<String>) {
        
        // УЛУЧШЕНИЕ 15: Логирование начала сканирования
        logger.info("Started scanning \(rootUrl.path)")
        let startTime = Date()

        let fm = FileManager.default
        let rootPath = rootUrl.standardizedFileURL.path
        let rootNode = Node(path: rootPath)

        var restrictedTop: Set<String> = []
        var filesScanned = 0
        let progressInterval = 500 // Обновлять прогресс каждые 500 файлов (было 1000)
        var lastProgressUpdate = Date()

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
                // УЛУЧШЕНИЕ 15: Логирование ошибок доступа
                logger.debug("No access to \(url.path): \(error.localizedDescription)")
                return true
            }
        ) {
            for case let fileUrl as URL in enumerator {
                // УЛУЧШЕНИЕ 1: Проверка отмены Task
                if Task.isCancelled {
                    logger.info("Scan cancelled by user")
                    break
                }
                
                // УЛУЧШЕНИЕ 13: Проверка лимита узлов
                if rootNode.totalNodeCount > maxNodes {
                    logger.error("Maximum node count exceeded: \(rootNode.totalNodeCount)")
                    break
                }
                
                autoreleasepool {
                    do {
                        let values = try fileUrl.resourceValues(forKeys: [
                            .isRegularFileKey,
                            .totalFileAllocatedSizeKey,
                            .fileAllocatedSizeKey
                        ])
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
                        
                        // УЛУЧШЕНИЕ 1: Прогресс-репорт с throttling
                        filesScanned += 1
                        let now = Date()
                        if filesScanned % progressInterval == 0 || now.timeIntervalSince(lastProgressUpdate) > 0.5 {
                            progressHandler?(filesScanned)
                            lastProgressUpdate = now
                        }
                    } catch {
                        // Тихо пропускаем файлы с ошибками
                    }
                }
            }
        }
        
        // Финальный прогресс
        progressHandler?(filesScanned)
        
        // УЛУЧШЕНИЕ 15: Логирование завершения
        let duration = Date().timeIntervalSince(startTime)
        logger.info("Scan completed: \(filesScanned) files in \(String(format: "%.2f", duration))s, \(rootNode.totalNodeCount) nodes")

        let rootUsage = makeFolderUsage(from: rootNode)
        return (root: rootUsage, restrictedTopFolders: restrictedTop)
    }

    // MARK: - Helpers

    // УЛУЧШЕНИЕ 9: Параллельное сканирование директорий (экспериментальное)
    static func scanTreeParallel(
        at rootUrl: URL,
        progressHandler: (@Sendable (Int) -> Void)? = nil
    ) async -> (root: FolderUsage, restrictedTopFolders: Set<String>) {
        
        logger.info("Started parallel scanning \(rootUrl.path)")
        let startTime = Date()
        
        let fm = FileManager.default
        var restrictedTop: Set<String> = []
        var totalFiles = 0
        
        // Сначала получаем топ-уровневые директории
        guard let topLevelContents = try? fm.contentsOfDirectory(
            at: rootUrl,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            logger.error("Failed to read top level directory")
            // Fallback на обычное сканирование
            return await Task.detached {
                scanTree(at: rootUrl, progressHandler: progressHandler)
            }.value
        }
        
        let directories = topLevelContents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        
        // Ограничиваем количество параллельных задач
        let maxConcurrent = 4
        var results: [(FolderUsage, Set<String>, Int)] = []
        
        for dirChunk in directories.chunked(into: maxConcurrent) {
            await withTaskGroup(of: (FolderUsage, Set<String>, Int).self) { group in
                for dir in dirChunk {
                    group.addTask {
                        var fileCount = 0
                        let result = await Task.detached {
                            DiskUsageService.scanTree(at: dir) { count in
                                fileCount = count
                            }
                        }.value
                        return (result.root, result.restrictedTopFolders, fileCount)
                    }
                }
                
                for await result in group {
                    results.append(result)
                    totalFiles += result.2
                    progressHandler?(totalFiles)
                }
            }
            
            // Проверка отмены между чанками
            if Task.isCancelled {
                logger.info("Parallel scan cancelled")
                break
            }
        }
        
        // Собираем результаты
        var children: [FolderUsage] = []
        var totalSize: Int64 = 0
        
        for (usage, restricted, _) in results {
            children.append(usage)
            totalSize += usage.size
            restrictedTop.formUnion(restricted)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        logger.info("Parallel scan completed: \(totalFiles) files in \(String(format: "%.2f", duration))s")
        
        let rootUsage = FolderUsage(
            url: rootUrl,
            size: totalSize,
            children: children.sorted { $0.size > $1.size }
        )
        
        return (root: rootUsage, restrictedTopFolders: restrictedTop)
    }

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
