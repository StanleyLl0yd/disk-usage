import Foundation

nonisolated struct FolderUsage: Identifiable, Hashable {
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

        var newChildren: [FolderUsage] = []
        newChildren.reserveCapacity(children.count)
        var removedSize: Int64 = 0

        for child in children {
            if let updated = child.removing(path: targetPath) {
                removedSize += child.size - updated.size
                newChildren.append(updated)
            } else {
                removedSize += child.size
            }
        }

        guard removedSize > 0 else { return self }
        return FolderUsage(
            path: path,
            size: size - removedSize,
            isFile: isFile,
            children: newChildren
        )
    }
}
