import Foundation

nonisolated struct FolderUsage: Identifiable, Hashable, Sendable {
    let path: String
    let size: Int64
    let isFile: Bool
    let children: [FolderUsage]

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var name: String { (path as NSString).lastPathComponent.isEmpty ? path : (path as NSString).lastPathComponent }
    var childrenOptional: [FolderUsage]? { children.isEmpty ? nil : children }

    init(path: String, size: Int64, isFile: Bool = false, children: [FolderUsage] = []) {
        self.path = path
        self.size = size
        self.isFile = isFile
        self.children = children
    }

    func sorted(by option: SortOption) -> FolderUsage {
        let sortedChildren = option.sorted(children.map { $0.sorted(by: option) })
        return FolderUsage(path: path, size: size, isFile: isFile, children: sortedChildren)
    }

    func removing(path targetPath: String) -> FolderUsage? {
        if path == targetPath { return nil }
        guard contains(targetPath) else { return self }

        guard let index = children.firstIndex(where: { child in
            child.path == targetPath || child.contains(targetPath)
        }) else {
            return self
        }

        let child = children[index]
        var updatedChildren = children

        if let updatedChild = child.removing(path: targetPath) {
            let removedSize = child.size - updatedChild.size
            guard removedSize > 0 else { return self }
            updatedChildren[index] = updatedChild
            return FolderUsage(
                path: path,
                size: size - removedSize,
                isFile: isFile,
                children: updatedChildren
            )
        }

        updatedChildren.remove(at: index)
        return FolderUsage(
            path: path,
            size: size - child.size,
            isFile: isFile,
            children: updatedChildren
        )
    }

    private func contains(_ targetPath: String) -> Bool {
        targetPath.hasPrefix(path == "/" ? "/" : path + "/")
    }
}
