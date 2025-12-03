import Foundation

protocol DiskUsageServiceProtocol {
    func scanDisk(
        at rootUrl: URL,
        groupByRoot: Bool
    ) async -> (items: [FolderUsage], restrictedTopFolders: Set<String>)
}

final class DiskUsageService: DiskUsageServiceProtocol {
    func scanDisk(
        at rootUrl: URL,
        groupByRoot: Bool
    ) async -> (items: [FolderUsage], restrictedTopFolders: Set<String>) {
        // heavy CPU/IO — выполнится в фоне, так как вызывается не с MainActor
        let fm = FileManager.default
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey
        ]

        var sizes: [String: Int64] = [:]
        var restrictedTop: Set<String> = []

        let options: FileManager.DirectoryEnumerationOptions = [
            .skipsPackageDescendants
            // при желании: .skipsHiddenFiles
        ]

        let keySet = Set(keys)
        let baseComponents = rootUrl.pathComponents

        if let enumerator = fm.enumerator(
            at: rootUrl,
            includingPropertiesForKeys: keys,
            options: options,
            errorHandler: { url, error in
                let components = url.pathComponents
                let topKey: String

                if groupByRoot {
                    if components.count > 1 {
                        topKey = "/" + components[1]
                    } else {
                        topKey = "/"
                    }
                } else {
                    if components.count > baseComponents.count {
                        let childComponent = components[baseComponents.count]
                        topKey = rootUrl.appendingPathComponent(childComponent).path
                    } else {
                        topKey = rootUrl.path
                    }
                }

                restrictedTop.insert(topKey)
                NSLog("DiskUsageService: no access to \(url.path): \(error.localizedDescription)")
                return true
            }
        ) {
            for case let url as URL in enumerator {
                do {
                    let values = try url.resourceValues(forKeys: keySet)
                    guard values.isRegularFile == true else { continue }

                    let rawSize = values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0
                    let fileSize = Int64(rawSize)
                    guard fileSize > 0 else { continue }

                    let components = url.pathComponents
                    let topKey: String

                    if groupByRoot {
                        if components.count > 1 {
                            topKey = "/" + components[1]
                        } else {
                            topKey = "/"
                        }
                    } else {
                        if components.count > baseComponents.count {
                            let childComponent = components[baseComponents.count]
                            topKey = rootUrl.appendingPathComponent(childComponent).path
                        } else {
                            topKey = rootUrl.path
                        }
                    }

                    sizes[topKey, default: 0] += fileSize
                } catch {
                    continue
                }
            }
        }

        let items = sizes.map { key, size in
            FolderUsage(url: URL(fileURLWithPath: key), size: size)
        }

        return (items, restrictedTop)
    }
}
